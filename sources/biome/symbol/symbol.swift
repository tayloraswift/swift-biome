import Notebook

struct Symbol:Sendable, Identifiable  
{
    /// A globally-unique index referencing a symbol. 
    /// 
    /// A symbol index encodes the module it belongs to, whichs makes it possible 
    /// to query module membership based on the index alone.
    struct Index:Hashable, Sendable
    {
        let module:Module.Index
        let bits:UInt32
        
        var offset:Int
        {
            .init(self.bits)
        }
        init(package:Int, module:Int, offset:Int)
        {
            self.init(Package.Index.init(offset: package), module: module, offset: offset)
        }
        init(_ package:Package.Index, module:Int, offset:Int)
        {
            self.init(Module.Index.init(package, offset: module), offset: offset)
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
    struct IndexRange:RandomAccessCollection, Hashable, Sendable
    {
        let module:Module.Index 
        let bits:Range<UInt32>
        
        var offsets:Range<Int> 
        {
            .init(self.bits.lowerBound) ..< .init(self.bits.upperBound)
        }
        var lowerBound:Symbol.Index 
        {
            .init(self.module, bits: self.bits.lowerBound)
        }
        var upperBound:Symbol.Index 
        {
            .init(self.module, bits: self.bits.upperBound)
        }
        
        var startIndex:UInt32
        {
            self.bits.startIndex
        }
        var endIndex:UInt32
        {
            self.bits.endIndex
        }
        subscript(index:UInt32) -> Symbol.Index 
        {
            .init(self.module, bits: self.bits[index])
        }
        
        init(_ module:Module.Index, offsets:Range<Int>)
        {
            self.init(module, bits: .init(offsets.lowerBound) ..< .init(offsets.upperBound))
        }
        init(_ module:Module.Index, bits:Range<UInt32>)
        {
            self.module = module
            self.bits = bits
        }
    }
    // this is like ``Symbol.IndexRange``, except the ``module`` field refers to 
    // a namespace, not the module that actually contains the symbol
    struct ColonialRange
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
    
    struct CollisionError:Error
    {
        let id:ID
        let module:Module.ID 
        
        init(_ id:ID, from module:Module.ID)
        {
            self.id = id 
            self.module = module 
        }
    }
    
    enum AccessLevel:String, Sendable
    {
        case `private` 
        case `fileprivate`
        case `internal`
        case `public`
        case `open`
    }

    enum Legality:Hashable, Sendable 
    {
        // we must store the comment, otherwise packages that depend on the package 
        // this symbol belongs to will not be able to reliably de-duplicate documentation
        static 
        let undocumented:Self = .documented("")
        
        case documented(String)
        case sponsored(by:Index)
    }
    
    let id:ID
    let name:String 
    //  TODO: see if small-array optimizations here are beneficial, since this could 
    //  often be a single-element array
    /// The enclosing scope this symbol is defined in. If the symbol is a protocol 
    /// extension member, this contains the name of the protocol.
    let scope:[String]
    //  this is only the same as the perpetrator if this symbol is part of its 
    //  core symbol graph.
    let namespace:Module.Index 
    private 
    let component:(full:Key.Component, stem:Key.Component, leaf:Key.Component)
    
    let legality:Legality
    let signature:Notebook<Fragment.Color, Never>
    let declaration:Notebook<Fragment.Color, Index>
    let generics:[Generic], 
        genericConstraints:[Generic.Constraint<Index>], 
        extensionConstraints:[Generic.Constraint<Index>]
    let availability:Availability
    private(set)
    var relationships:Relationships
    
    var color:Color 
    {
        self.relationships.color
    }
    var orientation:Orientation
    {
        self.relationships.color.orientation
    }
    
    var key:Key 
    {
        .init(self.namespace, stem: self.component.stem, leaf:    self.component.leaf, orientation:    self.orientation)
    }
    func key(feature:Self) -> Key 
    {
        .init(self.namespace, stem: self.component.full, leaf: feature.component.leaf, orientation: feature.orientation)
    }
    
    init(_ node:Package.Node, namespace:Module.Index, scope:Scope, paths:inout PathTable) throws 
    {
        self.legality       = node.legality
        
        self.id             =       node.vertex.id
        self.name           =       node.vertex.path[node.vertex.path.endIndex - 1]
        self.scope          = .init(node.vertex.path.dropLast())
        
        self.namespace      = namespace
        self.component.full = paths.register(stem: node.vertex.path)
        self.component.stem = paths.register(stem: self.scope)
        self.component.leaf = paths.register(leaf: self.name)
        
        self.availability   = node.vertex.availability 
        self.generics       = node.vertex.generics
        self.signature      = node.vertex.signature
        self.declaration    = try node.vertex.declaration.map(scope.index(of:))
        self.genericConstraints = try node.vertex.genericConstraints.map
        {
            try $0.map(scope.index(of:))
        }
        self.extensionConstraints = try node.vertex.extensionConstraints.map
        {
            try $0.map(scope.index(of:))
        }
        self.relationships  = try .init(validating: node.relationships, color: node.vertex.color)
    }
    
    mutating 
    func update(traits:[Trait], from package:Package.Index)  
    {
        self.relationships.update(traits: traits, from: package)
    }
}
