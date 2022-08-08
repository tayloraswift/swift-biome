import struct SymbolGraphs.Path
import HTML

@usableFromInline 
struct Article:Identifiable 
{
    /// A globally-unique index referencing an article. 
    /// 
    /// An article index encodes the module it belongs to, whichs makes it possible 
    /// to query module membership based on the index alone.
    @frozen public 
    struct Index:CulturalIndex, Sendable
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
        @History<Article.Excerpt>.Branch.Optional 
        var excerpt:History<Article.Excerpt>.Branch.Head?
        @History<Article.Template<Ecosystem.Link>>.Branch.Optional 
        var template:History<Article.Template<Ecosystem.Link>>.Branch.Head?
        
        init() 
        {
            self._excerpt = .init()
            self._template = .init()
        }
    }
    
    @usableFromInline 
    struct ID:Hashable, Sendable 
    {
        let key:Route.Key 
        
        init(_ key:Route.Key)
        {
            self.key = key
        }
    }
    
    @usableFromInline 
    let id:ID 
    let path:Path
    var name:String 
    {
        self.path.last
    }
    var heads:Heads

    var route:Route.Key
    {
        self.id.key
    }
    
    init(id:ID, path:Path)
    {
        self.id = id
        self.path = path
        self.heads = .init()
    }
}
