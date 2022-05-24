struct Symbol:Sendable, Identifiable, CustomStringConvertible  
{
    /// A globally-unique index referencing a symbol. 
    /// 
    /// A symbol index encodes the module it belongs to, whichs makes it possible 
    /// to query module membership based on the index alone.
    struct Index:CulturalIndex, Hashable, Sendable
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
    struct IndexPair:Hashable, Sendable
    {
        private 
        let prefix:Index, 
            suffix:Index
        
        static 
        func natural(_ index:Index) -> Self 
        {
            .init(prefix: index, suffix: index)
        }
        static 
        func synthesized(_ victim:Index, _ feature:Index) -> Self 
        {
            .init(prefix: victim, suffix: feature)
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
    
    enum Legality:Hashable, Sendable 
    {
        // we must store the comment, otherwise packages that depend on the package 
        // this symbol belongs to will not be able to reliably de-duplicate documentation
        static 
        let undocumented:Self = .documented("")
        
        case documented(String)
        case sponsored(by:Symbol.Index)
    }
    
    struct Heads 
    {
        @Keyframe<Declaration>.Head
        var declaration:Keyframe<Declaration>.Buffer.Index?
        @Keyframe<Relationships>.Head
        var relationships:Keyframe<Relationships>.Buffer.Index?
        
        init() 
        {
            self._declaration = .init()
            self._relationships = .init()
        }
    }
    
    // these stored properties are constant with respect to symbol identity. 
    let id:ID
    let key:Key
    let name:String 
    //  TODO: see if small-array optimizations here are beneficial, since this could 
    //  often be a single-element array
    /// The enclosing scope this symbol is defined in. If the symbol is a protocol 
    /// extension member, this contains the name of the protocol.
    let nest:[String]
    let color:Color
    
    var heads:Heads
    var _opinions:[Package.Index: Traits]
    // var history:[(range:Range<Package.Version>, declaration:Int)]
    
    //  this is only the same as the perpetrator if this symbol is part of its 
    //  core symbol graph.
    var namespace:Module.Index 
    {
        self.key.namespace
    }
    var orientation:Orientation
    {
        self.color.orientation
    }
    var description:String 
    {
        self.nest.isEmpty ? self.name : "\(self.nest.joined(separator: ".")).\(self.name)"
    }
    
    init(id:ID, key:Key, nest:[String], name:String, color:Color)
    {
        self.id = id 
        self.key = key 
        self.name = name 
        self.nest = nest 
        self.color = color 
        
        self.heads = .init()
        self._opinions = [:]
    }
    
    mutating 
    func update(traits:[Trait], from package:Package.Index)  
    {
        self._opinions[package, default: .init()].update(with: traits, as: self.color)
    }
}
