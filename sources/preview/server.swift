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
    let host:String
    private 
    let backend:Backend 

    init(backend:Backend, host:String) 
    {
        self.responding = false
        self.keep       = false
        self.host       = host
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
                self.respond(with: response, through: context)
                {
                    // check for an ETag 
                    request.headers["if-none-match"].first.flatMap(Resource.Version.init(etag:))
                }
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
    func headers(canonical:String?) -> HTTPHeaders 
    {
        if let canonical:String = canonical 
        {
            return ["host": self.host, "link": "<https://\(self.host)\(canonical)>; rel=\"canonical\""]
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
        headers.add(name: "location", value: "https://\(self.host)\(path)")
        return headers
    }
    private 
    func response(canonical:String?, containing resource:Resource, cached:Bool = false, 
        allocator:ByteBufferAllocator) 
        -> (headers:HTTPHeaders, body:ByteBuffer?) 
    {
        var headers:HTTPHeaders = self.headers(canonical: canonical)
        let buffer:ByteBuffer?, 
            version:Resource.Version?,
            content:(length:String, type:String)
        switch resource
        {
        case .text  (let string, type: let type, version: let current):
            content.length  = "\(string.utf8.count)"
            content.type    = "\(type.description); charset=utf-8"
            version         = current
            buffer          = cached ? nil : allocator.buffer(string: string)
        case .binary(let bytes,  type: let type, version: let current):
            content.length  = "\(bytes.count)"
            content.type    = type.description // includes charset if applicable
            version         = current
            buffer          = cached ? nil : allocator.buffer(bytes: bytes)
        }
        headers.add(name: "content-length", value: content.length)
        headers.add(name: "content-type",   value: content.type)
        if let version:Resource.Version = version 
        {
            headers.add(name: "etag",       value: version.etag)
        }
        return (headers, buffer)
    }
    private 
    func respond(with response:StaticResponse, through context:ChannelHandlerContext, 
        unless version:() throws -> Resource.Version?) rethrows
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
            let cached:Bool = resource.matches(version: try version())
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
