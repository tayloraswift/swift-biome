public
struct Symbol:Sendable, Identifiable, CustomStringConvertible  
{
    /// A globally-unique index referencing a symbol. 
    /// 
    /// A symbol index encodes the module it belongs to, which makes it possible 
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
    // this is like ``Symbol.IndexRange``, except the ``module`` field refers to 
    // a namespace, not the module that actually contains the symbol
    struct ColonialRange:Hashable, Sendable
    {
        let namespace:Module.Index 
        let bits:Range<UInt32>
        
        var offsets:Range<Int> 
        {
            .init(self.bits.lowerBound) ..< .init(self.bits.upperBound)
        }
        
        init(namespace:Module.Index, offsets:Range<Int>)
        {
            self.init(namespace: namespace, bits: .init(offsets.lowerBound) ..< .init(offsets.upperBound))
        }
        private 
        init(namespace:Module.Index, bits:Range<UInt32>)
        {
            self.namespace = namespace
            self.bits = bits
        }
    }
    
    struct Heads 
    {
        @Keyframe<Declaration>.Head
        var declaration:Keyframe<Declaration>.Buffer.Index?
        @Keyframe<Article.Template<Ecosystem.Link>>.Head
        var template:Keyframe<Article.Template<Ecosystem.Link>>.Buffer.Index?
        @Keyframe<Predicates>.Head
        var facts:Keyframe<Predicates>.Buffer.Index?
        
        init() 
        {
            self._declaration = .init()
            self._template = .init()
            self._facts = .init()
        }
    }
    
    struct Nest 
    {
        let namespace:Module.Index 
        let prefix:[String]
    }
    
    // these stored properties are constant with respect to symbol identity. 
    public
    let id:ID
    //  TODO: see if small-array optimizations here are beneficial, since this could 
    //  often be a single-element array
    let path:Path
    let kind:Kind
    let route:Route
    var shape:Shape<Index>?
    var heads:Heads
    var pollen:Set<Module.Pin>
    
    var color:Color 
    {
        self.kind.color
    }
    var name:String 
    {
        self.path.last
    }
    //  this is only the same as the perpetrator if this symbol is part of its 
    //  core symbol graph.
    var namespace:Module.Index 
    {
        self.route.namespace
    }
    var nest:Nest?
    {
        self.path.prefix.isEmpty ? 
            nil : .init(namespace: self.namespace, prefix: self.path.prefix)
    }
    var type:Index?
    {
        switch self.color 
        {
        case .associatedtype, .callable(_):
            return self.shape?.target 
        default: 
            return nil
        }
    }
    var orientation:Link.Orientation
    {
        self.color.orientation
    }
    public
    var description:String 
    {
        self.path.description
    }
    
    init(id:ID, path:Path, kind:Kind, route:Route)
    {
        self.id = id 
        self.path = path
        self.kind = kind
        self.route = route
        self.shape = nil
        
        self.heads = .init()
        self.pollen = []
    }
}
