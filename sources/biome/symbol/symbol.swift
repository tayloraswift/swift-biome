import Highlight

struct Symbol:Sendable, Identifiable  
{
    /// A globally-unique index referencing a symbol. 
    /// 
    /// A symbol index encodes the module it belongs to, whichs makes it possible 
    /// to query module membership based on the index alone.
    struct Index 
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
    struct IndexRange 
    {
        let module:Module.Index 
        let bits:Range<UInt32>
        
        var offsets:Range<Int> 
        {
            .init(self.bits.lowerBound) ..< .init(self.bits.upperBound)
        }
        var lowerBound:Index 
        {
            .init(self.module, bits: self.bits.lowerBound)
        }
        var upperBound:Index 
        {
            .init(self.module, bits: self.bits.upperBound)
        }
        
        static 
        func ..< (lhs:Index, rhs:Int) -> Self 
        {
            lhs ..< UInt32.init(rhs)
        }
        static 
        func ..< (lhs:Int, rhs:Index) -> Self 
        {
            UInt32.init(lhs) ..< rhs
        }
        static 
        func ..< (lhs:Index, rhs:UInt32) -> Self 
        {
            self.init(lhs.module, bits: lhs.bits ..< rhs)
        }
        static 
        func ..< (lhs:UInt32, rhs:Index) -> Self 
        {
            self.init(rhs.module, bits: lhs ..< rhs.bits)
        }
        private 
        init(_ module:Module.Index, bits:Range<UInt32>)
        {
            self.module = module
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

    /* enum LinkingError:Error 
    {
        case members([Int], in:Kind, Int) 
        case crimes([Int], in:Kind, Int) 
        case conformers([(index:Int, conditions:[SwiftConstraint<Int>])], in:Kind, Int) 
        case conformances([(index:Int, conditions:[SwiftConstraint<Int>])], in:Kind, Int) 
        case requirements([Int], in:Kind, Int) 
        case subclasses([Int], in:Kind, Int) 
        case superclass(Int, in:Kind, Int) 
        
        case defaultImplementationOf([Int], Kind, Int) 
        case requirementOf(Int, Kind, Int) 
        case overrideOf(Int, Kind, Int) 
        
        case island(associatedtype:Int)
        case orphaned(symbol:Int)
        //case junction(symbol:Int)
    } */
    enum AccessLevel:String, Sendable
    {
        case `private` 
        case `fileprivate`
        case `internal`
        case `public`
        case `open`
    }

    /* public 
    struct Parameter:Sendable
    {
        var label:String 
        var name:String?
        // var fragment:[SwiftLanguage.Lexeme<ID>]
    } */

    enum Legality:Sendable 
    {
        // we must store the comment, otherwise packages that depend on the package 
        // this symbol belongs to will not be able to reliably de-duplicate documentation
        case documented(comment:String)
        case undocumented(impersonating:Index)
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
    let legality:Legality
    let signature:Notebook<Fragment.Color, Never>
    let declaration:Notebook<Fragment.Color, Index>
    let generics:[Generic], 
        genericConstraints:[Generic.Constraint<Index>], 
        extensionConstraints:[Generic.Constraint<Index>]
    let availability:Availability
    var relationships:Relationships
    
    var color:Color 
    {
        self.relationships.color
    }
    
    init(_ node:Node, namespace:Module.Index, scope:Module.Scope) throws 
    {
        self.bystander      = namespace
        self.legality       = node.legality
        
        self.id             =       node.vertex.id
        self.name           =       node.vertex.path[vertex.path.endIndex - 1]
        self.scope          = .init(node.vertex.path.dropLast())
        
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
        self.relationships  = try .init(validating: node.relationships)
    }

    @available(*, deprecated, renamed: "name")
    var title:String 
    {
        self.name
    }
}
