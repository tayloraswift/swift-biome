extension Mongo
{
    @frozen public 
    struct Host:Hashable, Sendable
    {
        /// The hostname, like [`"localhost"`](), [`"example.com"`](), 
        /// or [`"127.0.0.1"`]().
        public 
        var name:String

        /// The port. The default MongoDB port is 27017.
        public 
        var port:Int

        /// Initializes a new `Host` instance
        ///
        /// - parameter hostname: The hostname
        /// - parameter port: The port
        @inlinable public 
        init(_ name:String, _ port:Int) 
        {
            self.name = name
            self.port = port
        }
    }
}
extension Mongo.Host
{        
    static
    func srv(_ name:String) -> Self
    {
        .init(name, 27017)
    }

    public 
    init(parsing string:some StringProtocol, srv: Bool) throws
    {
        let port:Int?
        let name:String
        if  let colon:String.Index = string.firstIndex(of: ":")
        {
            if srv 
            {
                throw MongoInvalidUriError.init(reason: .srvCannotSpecifyPort)
            }

            name = .init(string.prefix(upTo: colon))
            port = .init(string.suffix(from: string.index(after: colon)))
        }
        else
        {
            name = .init(string)
            port = nil
        }
        self.init(name, port ?? 27017)
    }
}