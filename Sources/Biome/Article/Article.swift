import HTML

@usableFromInline 
struct Article:Identifiable 
{
    /// A globally-unique index referencing an article. 
    /// 
    /// An article index encodes the module it belongs to, whichs makes it possible 
    /// to query module membership based on the index alone.
    @frozen public 
    struct Index:CulturalIndex, Hashable, Sendable
    {
        public 
        let module:Module.Index
        public 
        let bits:UInt32
        
        @inlinable public 
        var culture:Module.Index
        {
            self.module
        }
        @inlinable public 
        init(_ module:Module.Index, bits:UInt32)
        {
            self.module = module
            self.bits = bits
        }
    }
    
    struct Heads 
    {
        @Keyframe<Article.Excerpt>.Head
        var excerpt:Keyframe<Article.Excerpt>.Buffer.Index?
        @Keyframe<Article.Template<Ecosystem.Link>>.Head
        var template:Keyframe<Article.Template<Ecosystem.Link>>.Buffer.Index?
        
        init() 
        {
            self._excerpt = .init()
            self._template = .init()
        }
    }
    
    @usableFromInline 
    struct ID:Hashable, Sendable 
    {
        let route:Route 
        
        init(_ route:Route)
        {
            self.route = route
        }
    }
    
    @usableFromInline 
    var id:ID 
    {
        .init(self.route)
    }
    let path:Path
    var name:String 
    {
        self.path.last
    }
    let route:Route
    var heads:Heads
    
    init(id:ID, path:Path)
    {
        self.path = path
        self.route = id.route
        self.heads = .init()
    }
}
