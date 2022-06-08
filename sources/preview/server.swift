import NIO
import NIOHTTP1
import Resource

final
class Endpoint<Backend>:ChannelInboundHandler, RemovableChannelHandler 
    where   Backend:ServiceBackend, Backend.Request == String, 
            Backend.Continuation == EventLoopPromise<StaticResponse>
{
    typealias InboundIn     = HTTPServerRequestPart
    typealias OutboundOut   = HTTPServerResponsePart
    
    private 
    var responding:Bool, 
        keep:Bool
    private 
    let host:String, 
        port:Int
    private 
    let backend:Backend 

    init(backend:Backend, host:String, port:Int) 
    {
        self.responding = false
        self.keep       = false
        self.host       = host
        self.port       = port
        self.backend    = backend 
    }
    func channelRead(context:ChannelHandlerContext, data:NIOAny) 
    {
        guard case .head(let request) = self.unwrapInboundIn(data)  
        else 
        {
            return 
        }
        self.keep = request.isKeepAlive
        switch request.method
        {
        case .GET:
            switch self.backend.request(request.uri)
            {
            case .immediate(let response):
                let etag:Resource.Tag? = request.headers["if-none-match"].first.flatMap(Resource.Tag.init(etag:))
                self.respond(with: response, through: context, ifNoneMatch: etag)
            case .enqueue(to: _): 
                fatalError("unreachable")
            }
        default: 
            self.respond(with: self.response(canonical: nil, containing: .utf8(encoded: []), 
                    allocator: context.channel.allocator),
                status: .methodNotAllowed, 
                through: context)
        }
    }

    func channelReadComplete(context:ChannelHandlerContext) 
    {
        context.flush()
    }
    
    func userInboundEventTriggered(context:ChannelHandlerContext, event:Any) 
    {
        guard case .inputClosed? = event as? ChannelEvent
        else 
        {
            context.fireUserInboundEventTriggered(event)
            return 
        }
        self.keep = false 
        guard self.responding 
        else 
        {
            context.close(promise: nil)
            return 
        }
    }
    
    private 
    func url(_ uri:String) -> String 
    {
        self.port == 80 ? 
            "http://\(self.host)\(uri)" : 
            "http://\(self.host):\(self.port)\(uri)"
    }
    
    private 
    func headers(canonical:String?) -> HTTPHeaders 
    {
        if let canonical:String = canonical 
        {
            return ["host": self.host, "link": "<\(self.url(canonical))>; rel=\"canonical\""]
        }
        else 
        {
            return ["host": self.host]
        }
    }
    private 
    func headers(canonical:String?, location path:String) -> HTTPHeaders 
    {
        var headers:HTTPHeaders = self.headers(canonical: canonical)
        headers.add(name: "location", value: self.url(path))
        return headers
    }
    private 
    func response(canonical:String?, containing resource:Resource, cached:Bool = false, 
        allocator:ByteBufferAllocator) 
        -> (headers:HTTPHeaders, body:ByteBuffer?) 
    {
        var headers:HTTPHeaders = self.headers(canonical: canonical)
        let content:(length:String, type:String), 
            buffer:ByteBuffer?
        switch resource.payload
        {
        case .text  (let string, type: let type):
            content.length  = "\(string.utf8.count)"
            content.type    = "\(type.description); charset=utf-8"
            buffer          = cached ? nil : allocator.buffer(string: string)
        case .binary(let bytes,  type: let type):
            content.length  = "\(bytes.count)"
            content.type    = type.description // includes charset if applicable
            buffer          = cached ? nil : allocator.buffer(bytes: bytes)
        }
        headers.add(name: "content-length", value: content.length)
        headers.add(name: "content-type",   value: content.type)
        if let etag:String = resource.tag?.etag 
        {
            headers.add(name: "etag",       value: etag)
        }
        return (headers, buffer)
    }
    private 
    func respond(with response:StaticResponse, 
        through context:ChannelHandlerContext, 
        ifNoneMatch tag:Resource.Tag?)
    {
        switch response
        {
        case .none(let display):
            self.respond(with: self.response(canonical: nil, 
                    containing: display, 
                    allocator: context.channel.allocator), 
                status: .notFound, 
                through: context)
        
        case .maybe(canonical: let canonical, at: let uri):
            self.respond(with: (self.headers(canonical: canonical, location: uri), nil), 
                status: .temporaryRedirect,
                through: context)
        case .found(canonical: let canonical, at: let uri):
            self.respond(with: (self.headers(canonical: canonical, location: uri), nil), 
                status: .permanentRedirect,
                through: context)
        
        case .matched(canonical: let canonical, let resource):
            let cached:Bool = resource.tag =~= tag 
            self.respond(with: self.response(canonical: canonical, 
                    containing: resource, 
                    cached:     cached, 
                    allocator:  context.channel.allocator), 
                status:  cached ? .notModified : .ok, 
                through: context)
        }
    }
    private 
    func respond(with response:(headers:HTTPHeaders, body:ByteBuffer?), 
        status:HTTPResponseStatus, 
        through context:ChannelHandlerContext)
    {
        self.responding = true 
        
        let head:HTTPResponseHead       = .init(version: .http1_1, status: status, headers: response.headers)
        let sent:EventLoopPromise<Void> = context.eventLoop.makePromise(of: Void.self)
            sent.futureResult.whenComplete 
        {
            (_:Result<Void, Error>) in 
            self.responding = false 
            guard self.keep 
            else 
            {
                context.channel.close(promise: nil)
                return 
            }
        }
        context.write        (self.wrapOutboundOut(HTTPServerResponsePart.head(head)), promise: nil)
        if let buffer:ByteBuffer    = response.body 
        {
            let body:IOData         = .byteBuffer(buffer)
            context.write    (self.wrapOutboundOut(HTTPServerResponsePart.body(body)), promise: nil)
        }
        context.writeAndFlush(self.wrapOutboundOut(HTTPServerResponsePart.end (nil )), promise: sent)
    }
}
