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
            self.module = module
            self.bits = .init(offset)
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
    struct Generic:Hashable, Sendable
    {
        var name:String 
        var index:Int 
        var depth:Int 
    }
    enum Legality:Sendable 
    {
        // we must store the comment, otherwise packages that depend on the package 
        // this symbol belongs to will not be able to reliably de-duplicate documentation
        case documented(comment:String)
        case undocumented(sponsor:Index)
    }
    
    let id:ID
    let name:String 
    //  TODO: see if small-array optimizations here are beneficial, since this could 
    //  often be a single-element array
    /// The enclosing scope this symbol is defined in. If the symbol is a protocol 
    /// extension member, this contains the name of the protocol.
    let scope:[String]
    let bystander:Module.Index? 
    let legality:Legality
    let signature:Notebook<SwiftHighlight, Never>
    let declaration:Notebook<SwiftHighlight, Index>
    let generics:[Generic], 
        genericConstraints:[SwiftConstraint<Index>], 
        extensionConstraints:[SwiftConstraint<Index>]
    let availability:Availability
    var relationships:Relationships
    
    var color:Color 
    {
        self.relationships.color
    }
    
    init(_ vertex:Vertex, bystander:Module.Index, legality:Legality, modules:Module.Scope) throws 
    {
        self.bystander      = bystander
        self.legality       = legality
        
        self.id             =       vertex.id
        self.name           =       vertex.path[vertex.path.endIndex - 1]
        self.scope          = .init(vertex.path.dropLast())
        
        self.availability   = vertex.availability 
        self.generics       = vertex.generics
        self.signature      = vertex.signature
        self.declaration    = try vertex.declaration.mapLinks(modules.index(of:))
        self.genericConstraints = try vertex.genericConstraints.map
        {
            try $0.map(modules.index(of:))
        }
        self.extensionConstraints = try vertex.extensionConstraints.map
        {
            try $0.map(modules.index(of:))
        }
        self.relationships  = try .init(validating: vertex.relationships)
        
        // FIXME: we should validate extendedModule consistency in the caller, 
        // not this initializer...
        /* if let extended:Module.ID   = vertex.extendedModule
        {
            guard let extended:Int  = modules.index(of: extended)
            else 
            {
                throw _ModuleError.undefined(id: extended)
            }
            if  extended != self.module
            {
                switch self.bystander
                {
                case nil, extended?: 
                    break 
                case let bystander?:
                    throw _ModuleError.mismatchedExtension(
                        id: modules[extended].id, expected: modules[bystander].id, 
                        in: self.id)
                }
            }
        } */
    }

    @available(*, deprecated, renamed: "name")
    var title:String 
    {
        self.name
    }
}
