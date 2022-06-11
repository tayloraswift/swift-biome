import HTML

struct Article:Identifiable 
{
    /// A globally-unique index referencing an article. 
    /// 
    /// An article index encodes the module it belongs to, whichs makes it possible 
    /// to query module membership based on the index alone.
    struct Index:CulturalIndex, Hashable, Sendable
    {
        let module:Module.Index
        let bits:UInt32
        
        var offset:Int
        {
            .init(self.bits)
        }
        
        init(_ module:Module.Index, offset:Int)
        {
            self.init(module, bits: .init(offset))
        }
        fileprivate 
        init(_ module:Module.Index, bits:UInt32)
        {
            self.module = module
            self.bits = bits
        }
    }
    
    struct Heads 
    {
        @Keyframe<Article.Template<Link>>.Head
        var template:Keyframe<Article.Template<Link>>.Buffer.Index?
        
        init() 
        {
            self._template = .init()
        }
    }
    
    var id:Route 
    {
        self.route
    }
    let path:Path
    var name:String 
    {
        self.path.last
    }
    let route:Route
    var heads:Heads
    
    init(path:Path, route:Route)
    {
        self.path = path
        self.route = route
        self.heads = .init()
    }
    
    /* public
    struct Rendered<Anchor> where Anchor:Hashable
    {
        typealias Element = HTML.Element<Anchor> 
        

        
        public
        let title:String, 
            path:[String]
        public 
        let snippet:String
        let headline:Documentation.Element?
        var content:Content
        
        /* var stem:[[UInt8]]
        {
            //self.path.map { URI.encode(component: $0.utf8) }
            self.path.suffix(1).map { Documentation.URI.encode(component: $0.utf8) }
        }
        var leaf:[UInt8]
        {
            []
        } */
    } */
}
