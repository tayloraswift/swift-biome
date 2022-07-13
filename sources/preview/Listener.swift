import NIO
import NIOHTTP1
import Resources

protocol ExpressibleByPartialHTTPRequest 
{
    init?(source:SocketAddress?, head:HTTPRequestHead)
    init?(source:SocketAddress?, head:HTTPRequestHead, body:[ByteBuffer], end:HTTPHeaders?)
}
extension ExpressibleByPartialHTTPRequest 
{
    typealias Enqueued = (request:Self, promise:EventLoopPromise<StaticResponse>)
    
    init?(source _:SocketAddress?, head _:HTTPRequestHead)
    {
        return nil 
    }
    init?(source:SocketAddress?, head:HTTPRequestHead, body _:[ByteBuffer], end _:HTTPHeaders?)
    {
        return nil 
    }
}

extension HTTPHeaders 
{
    var hash:SHA256? 
    {
        self["if-none-match"].first.flatMap(SHA256.init(etag:))
    }
}

extension Listener 
{
    static 
    func send(to queue:AsyncStream<Request.Enqueued>.Continuation, 
        domain:String, 
        host:String, 
        port:Int,
        group:MultiThreadedEventLoopGroup) 
        async throws -> any Channel
    {
        let bootstrap:ServerBootstrap = .init(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer 
        { 
            (channel:any Channel) -> EventLoopFuture<Void> in
            
            let endpoint:Self = .init(queue: queue, source: channel.remoteAddress, 
                scheme: "http",
                host: domain)
            return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true)
                .flatMap 
            {
                channel.pipeline.addHandler(endpoint)
            }
        }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead,          value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
        
        return try await bootstrap.bind(host: host, port: port).get()
    }
}

final
class Listener<Request>:ChannelInboundHandler, RemovableChannelHandler
    where Request:ExpressibleByPartialHTTPRequest & Sendable
{
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private 
    var request:(head:HTTPRequestHead, stream:[ByteBuffer])?,
        responding:Bool, 
        receiving:Bool
    private 
    let queue:AsyncStream<Request.Enqueued>.Continuation 
    private 
    let source:SocketAddress?,
        scheme:String, 
        host:String

    init(queue:AsyncStream<Request.Enqueued>.Continuation, 
        source:SocketAddress?, 
        scheme:String,
        host:String) 
    {
        self.request    = nil 
        self.responding = false 
        self.receiving  = false
        self.queue      = queue 
        self.source     = source
        self.scheme     = scheme
        self.host       = host
    }
    func channelRead(context:ChannelHandlerContext, data:NIOAny) 
    {
        switch self.unwrapInboundIn(data) 
        {
        case .head(let head):
            self.receiving = head.isKeepAlive
            if  let request:Request = .init(source: self.source, head: head)
            {
                self.queue.yield((request, self.makePromise(hash: head.headers.hash, 
                    context: context)))
                self.request = nil
            }
            else 
            {
                self.request = (head, [])
            }
            
        case .body(let buffer):
            if case (let head, var body)? = self.request 
            {
                self.request = nil 
                body.append(buffer)
                self.request = (head, body)
            }
        
        case .end(let end):
            guard case let (head, body)? = self.request 
            else 
            {
                // already responded
                break 
            }
            self.request = nil
            if  let request:Request = .init(source: self.source, 
                    head: head, 
                    body: body, 
                    end: end)
            {
                self.queue.yield((request, self.makePromise(hash: head.headers.hash,
                    context: context)))
            } 
            else 
            {
                let headers:HTTPHeaders = self.createHeaders()
                let response:HTTPResponseHead = .init(version: .http1_1, 
                    status: .badRequest, 
                    headers: headers)
                self.respond(head: response, context: context)
            }
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
        self.receiving = false 
        guard self.responding 
        else 
        {
            context.close(promise: nil)
            return 
        }
    }
}
extension Listener
{
    private 
    func makePromise(hash:SHA256?, context:ChannelHandlerContext) 
        -> EventLoopPromise<StaticResponse>
    {
        let promise:EventLoopPromise<StaticResponse> = 
            context.eventLoop.makePromise(of: StaticResponse.self)
            promise.futureResult.whenComplete 
        {
            switch $0 
            {
            case .failure(let error): 
                self.respond(with: .error(.init("\(error)")), context: context)
            
            case .success(let response):
                self.respond(with: response, ifNoneMatch: hash, context: context) 
            }
        }
        return promise
    }
    
    private 
    func url(_ uri:String) -> String 
    {
        "\(self.scheme)://\(self.host)\(uri)"
    }
    private 
    func createHeaders(canonical:String? = nil) -> HTTPHeaders 
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
    func createResponseHead(
        location uri:String, 
        canonical:String?, 
        status:HTTPResponseStatus) 
        -> HTTPResponseHead 
    {
        var headers:HTTPHeaders = self.createHeaders(canonical: canonical)
            headers.add(name: "location", value: self.url(uri))
        return .init(version: .http1_1, status: status, headers: headers)
    }
    private 
    func createResponse(containing resource:Resource, 
        allocator:ByteBufferAllocator,
        canonical:String? = nil, 
        status:HTTPResponseStatus)
        -> (head:HTTPResponseHead, body:IOData?) 
    {
        var headers:HTTPHeaders = self.createHeaders(canonical: canonical)
        let content:(length:Int, type:MIME), 
            buffer:ByteBuffer?
        switch resource.payload
        {
        case .text(let string, type: let type):
            content.length = string.utf8.count
            content.type = .utf8(encoded: type)
            buffer = status == .notModified ? nil : allocator.buffer(string: string)
        case .bytes(let bytes,  type: let type):
            content.length = bytes.count
            content.type = type
            buffer = status == .notModified ? nil : allocator.buffer(bytes: bytes)
        }
        headers.add(name: "content-length", value: content.length.description)
        headers.add(name: "content-type",   value: content.type.description)
        if let hash:SHA256 = resource.hash
        {
            headers.add(name: "etag",       value: hash.etag)
        }
        let head:HTTPResponseHead = .init(version: .http1_1, status: status, 
            headers: headers)
        return (head, buffer.map(IOData.byteBuffer(_:)))
    }
    private 
    func respond(with response:StaticResponse, 
        ifNoneMatch hash:SHA256? = nil,
        context:ChannelHandlerContext) 
    {
        let head:HTTPResponseHead, 
            body:IOData?
        switch response
        {
        case .none(let resource):
            (head, body) = self.createResponse(containing: resource, 
                allocator: context.channel.allocator,
                status: .notFound)
        
        case .error(let resource):
            (head, body) = self.createResponse(containing: resource, 
                allocator: context.channel.allocator,
                status: .internalServerError)
        
        case .multiple(let resource):
            (head, body) = self.createResponse(containing: resource, 
                allocator: context.channel.allocator,
                status: .multipleChoices)
        
        case .maybe(at: let uri, canonical: let canonical):
            head = self.createResponseHead(location: uri, 
                canonical: canonical,
                status: .temporaryRedirect)
            body = nil 
        
        case .found(at: let uri, canonical: let canonical):
            head = self.createResponseHead(location: uri, 
                canonical: canonical, 
                status: .permanentRedirect)
            body = nil
        
        case .matched(let resource, canonical: let canonical):
            let status:HTTPResponseStatus = 
                resource.hash =~= hash ? .notModified : .ok
            (head, body) = self.createResponse(containing: resource, 
                allocator: context.channel.allocator,
                canonical: canonical, 
                status: status)
        }
        self.respond(head: head, body: body, context: context)
    }
    private 
    func respond(head:HTTPResponseHead, body:IOData? = nil, 
        context:ChannelHandlerContext)
    {
        self.responding = true 
        
        let sent:EventLoopPromise<Void> = context.eventLoop.makePromise(of: Void.self)
            sent.futureResult.whenComplete 
        {
            (_:Result<Void, Error>) in 
            self.responding = false 
            if !self.receiving 
            {
                context.channel.close(promise: nil)
            }
        }
        context.write(self.wrapOutboundOut(HTTPServerResponsePart.head(head)), 
            promise: nil)
        if let body:IOData 
        {
            context.write(self.wrapOutboundOut(HTTPServerResponsePart.body(body)), 
                promise: nil)
        }
        context.writeAndFlush(self.wrapOutboundOut(HTTPServerResponsePart.end(nil)), 
            promise: sent)
    }
}
