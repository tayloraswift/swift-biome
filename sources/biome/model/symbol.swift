extension Biome 
{
    public 
    enum SymbolIdentifierError:Error 
    {
        case duplicate(symbol:Symbol.ID, in:String)
        case undefined(symbol:Symbol.ID)
    }
    public 
    enum SymbolExtensionError:Error 
    {
        case mismatch(decoded:Module.ID, expected:Module.ID, in:Symbol.ID)
    }
    enum SymbolAvailabilityError:Error 
    {
        case duplicate(domain:Symbol.Domain, in:Symbol.ID)
    }
    enum LinkingError:Error 
    {
        case constraints(on:Int, is:Edge.Kind, of:Int)
        case duplicate(Int, have:Int, is:Edge.Kind, of:Int)
        
        
        case members([Int], in:Symbol.Kind, Int) 
        case conformers([(index:Int, conditions:[Language.Constraint])], in:Symbol.Kind, Int) 
        case conformances([(index:Int, conditions:[Language.Constraint])], in:Symbol.Kind, Int) 
        case requirements([Int], in:Symbol.Kind, Int) 
        case subclasses([Int], in:Symbol.Kind, Int) 
        case superclass(Int, in:Symbol.Kind, Int) 
        
        case defaultImplementationOf([Int], Symbol.Kind, Int) 
        case requirementOf(Int, Symbol.Kind, Int) 
        case overrideOf(Int, Symbol.Kind, Int) 
        
        case island(associatedtype:Int)
        case orphaned(symbol:Int)
        case junction(symbol:Int)
    }
    public 
    struct Symbol:Sendable, Identifiable  
    {        
        public 
        let id:ID
        let module:Int 
        let bystander:Int? 
        var namespace:Int 
        {
            self.bystander ?? self.module
        }
        let path:Path
        let title:String 
        let qualified:[Language.Lexeme]
        let signature:[Language.Lexeme]
        let declaration:[Language.Lexeme]
        
        let generics:[Generic], 
            genericConstraints:[Language.Constraint], 
            extensionConstraints:[Language.Constraint]
        let availability:
        (
            unconditional:UnconditionalAvailability?, 
            swift:SwiftAvailability?
        )
        let platforms:[Domain: Availability]
        
        let breadcrumbs:(last:String, parent:Int?)
        let relationships:Relationships
            
        var topics:
        (
            requirements:[(heading:Biome.Topic, indices:[Int])],
            members:[(heading:Biome.Topic, indices:[Int])],
            removed:[(heading:Biome.Topic, indices:[Int])]
        )
        
        init(modules:Storage<Module>, 
            path:Path, 
            breadcrumbs:Breadcrumbs, 
            parent:Int?, 
            relationships:Relationships, 
            vertex:Vertex) 
            throws 
        {
            // if this is a (nested) type, print its fully-qualified signature
            let keyword:String?
            switch relationships 
            {
            case .typealias:    keyword = "typealias"
            case .enum:         keyword = "enum"
            case .struct:       keyword = "struct"
            case .class:        keyword = "class"
            case .actor:        keyword = "actor"
            case .protocol:     keyword = "protocol"
            default:            keyword = nil 
            }
            self.id             = vertex.id
            self.module         = breadcrumbs.module 
            self.bystander      = breadcrumbs.bystander
            self.path           = path
            self.title          = vertex.title 
            self.breadcrumbs    = (breadcrumbs.last, parent)
            self.qualified      = breadcrumbs.lexemes
            if let keyword:String = keyword 
            {
                self.signature  = [.code(keyword, class: .keyword(.other)), .spaces(1)] + self.qualified
            }
            else 
            {
                self.signature  = vertex.signature
            }
            self.declaration    = vertex.declaration
            self.relationships  = relationships
            
            if let extended:Module.ID   = vertex.extends?.module
            {
                guard let extended:Int  = modules.index(of: extended)
                else 
                {
                    throw ModuleIdentifierError.undefined(module: extended)
                }
                if  extended != self.module
                {
                    switch self.bystander
                    {
                    case nil, extended?: 
                        break 
                    case let bystander?:
                        throw SymbolExtensionError.mismatch(decoded: modules[extended].id, expected: modules[bystander].id, in: self.id)
                    }
                }
            }
            self.generics               = vertex.generic?.parameters ?? []
            self.genericConstraints     = vertex.generic?.constraints ?? []
            self.extensionConstraints   = vertex.extends?.where ?? []
            
            var platforms:[Domain: Availability] = [:]
            var availability:(unconditional:UnconditionalAvailability?, swift:SwiftAvailability?) = (nil, nil)
            for (domain, value):(Domain, Availability) in vertex.availability 
            {
                switch domain 
                {
                case .wildcard:
                    guard case nil = availability.unconditional 
                    else 
                    {
                        throw SymbolAvailabilityError.duplicate(domain: domain, in: self.id)
                    }
                    let deprecated:Bool 
                    if case .some(nil) = value.deprecated 
                    {
                        deprecated = true 
                    }
                    else 
                    {
                        deprecated = false 
                    }
                    availability.unconditional = .init(unavailable: value.unavailable, 
                        deprecated: deprecated, 
                        renamed: value.renamed, 
                        message: value.message)
                case .swift:
                    guard case nil = availability.swift 
                    else 
                    {
                        throw SymbolAvailabilityError.duplicate(domain: domain, in: self.id)
                    }
                    availability.swift = .init(
                        deprecated: value.deprecated ?? nil, 
                        obsoleted: value.obsoleted,
                        renamed: value.renamed, 
                        message: value.message)
                default:
                    guard case nil = platforms.updateValue(value, forKey: domain)
                    else 
                    {
                        throw SymbolAvailabilityError.duplicate(domain: domain, in: self.id)
                    }
                }
            }
            self.availability   = availability
            self.platforms      = platforms
            self.topics         = ([], [], [])
        }
        
        var kind:Kind 
        {
            switch self.relationships 
            {
            case .typealias:        return .typealias
            case .enum:             return .enum
            case .struct:           return .struct
            case .class:            return .class
            case .actor:            return .actor
            case .protocol:         return .protocol
            case .associatedtype:   return .associatedtype
            case .witness(_, callable: let  callable):
                switch callable 
                {
                case .subscript (instance: true,    parameters: _, returns: _): return .instanceSubscript
                case .subscript (instance: false,   parameters: _, returns: _): return .typeSubscript
                case .func      (instance: true?,   parameters: _, returns: _): return .instanceMethod
                case .func      (instance: false?,  parameters: _, returns: _): return .typeMethod
                case .func      (instance: nil,     parameters: _, returns: _): return .func
                case .var(instance: true?):         return .instanceProperty
                case .var(instance: false?):        return .typeProperty
                case .var(instance: nil):           return .var
                case .operator:                     return .operator
                case .case:                         return .case
                case .initializer:                  return .initializer
                case .deinitializer:                return .deinitializer
                }
            }
        }
    }
}
extension Biome.Symbol 
{
    public 
    struct ID:Hashable, Sendable 
    {
        let string:String 
        init(_ string:String)
        {
            self.string = string 
        }
    }
    public 
    enum Kind:String, Sendable, Hashable
    {
        case `case`             = "swift.enum.case"
        case `associatedtype`   = "swift.associatedtype"
        case `typealias`        = "swift.typealias"
        
        case initializer        = "swift.init"
        case deinitializer      = "swift.deinit"
        case typeSubscript      = "swift.type.subscript"
        case instanceSubscript  = "swift.subscript"
        case typeProperty       = "swift.type.property"
        case instanceProperty   = "swift.property"
        case typeMethod         = "swift.type.method"
        case instanceMethod     = "swift.method"
        
        case `var`              = "swift.var"
        case `func`             = "swift.func"
        case `operator`         = "swift.func.op"
        case `enum`             = "swift.enum"
        case `struct`           = "swift.struct"
        case `class`            = "swift.class"
        case  actor             = "swift.actor"
        case `protocol`         = "swift.protocol"
        
        public 
        var topic:Biome.Topic.Automatic
        {
            switch self 
            {
            case .case:                 return .case
            case .associatedtype:       return .associatedtype
            case .typealias:            return .typealias
            case .initializer:          return .initializer
            case .deinitializer:        return .deinitializer
            case .typeSubscript:        return .typeSubscript
            case .instanceSubscript:    return .instanceSubscript
            case .typeProperty:         return .typeProperty
            case .instanceProperty:     return .instanceProperty
            case .typeMethod:           return .typeMethod
            case .instanceMethod:       return .instanceMethod
            case .var:                  return .global
            case .func:                 return .function
            case .operator:             return .operator
            case .enum:                 return .enum
            case .struct:               return .struct
            case .class:                return .class
            case .actor:                return .actor
            case .protocol:             return .protocol
            }
        }
        
        public 
        var title:String 
        {
            switch self 
            {
            case .case:                 return "Enumeration Case"
            case .associatedtype:       return "Associated Type"
            case .typealias:            return "Typealias"
            case .initializer:          return "Initializer"
            case .deinitializer:        return "Deinitializer"
            case .typeSubscript:        return "Type Subscript"
            case .instanceSubscript:    return "Instance Subscript"
            case .typeProperty:         return "Type Property"
            case .instanceProperty:     return "Instance Property"
            case .typeMethod:           return "Type Method"
            case .instanceMethod:       return "Instance Method"
            case .var:                  return "Global Variable"
            case .func:                 return "Function"
            case .operator:             return "Operator"
            case .enum:                 return "Enumeration"
            case .struct:               return "Structure"
            case .class:                return "Class"
            case .actor:                return "Actor"
            case .protocol:             return "Protocol"
            }
        }
    }
    public 
    enum Access:Sendable
    {
        case `private` 
        case `fileprivate`
        case `internal`
        case `public`
        case `open`
    }
    // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/AvailabilityMixin.cpp
    public 
    enum Domain:String, Sendable, Hashable  
    {
        case wildcard   = "*"
        case swift      = "Swift"
        case swiftpm    = "SwiftPM"
        
        case iOS 
        case macOS
        case macCatalyst
        case tvOS
        case watchOS
        case windows    = "Windows"
        case openBSD    = "OpenBSD"
        
        case iOSApplicationExtension
        case macOSApplicationExtension
        case macCatalystApplicationExtension
        case tvOSApplicationExtension
        case watchOSApplicationExtension
        
        static 
        var platforms:[Self]
        {
            [
                Self.iOS ,
                Self.macOS,
                Self.macCatalyst,
                Self.tvOS,
                Self.watchOS,
                Self.windows,
                Self.openBSD,
            ]
        }
    }
    public 
    struct UnconditionalAvailability:Sendable
    {
        var unavailable:Bool 
        var deprecated:Bool 
        var renamed:String?
        var message:String?
    }
    public 
    struct SwiftAvailability:Sendable
    {
        // unconditionals not allowed 
        var deprecated:Biome.Version?
        var introduced:Biome.Version?
        var obsoleted:Biome.Version?
        var renamed:String?
        var message:String?
    }
    public 
    struct Availability:Sendable
    {
        var unavailable:Bool 
        // .some(nil) represents unconditional deprecation
        var deprecated:Biome.Version??
        var introduced:Biome.Version?
        var obsoleted:Biome.Version?
        var renamed:String?
        var message:String?
    }
    public 
    struct Parameter:Sendable
    {
        var label:String 
        var name:String?
        var fragment:[Language.Lexeme]
    }
    public 
    struct Generic:Sendable
    {
        var name:String 
        var index:Int 
        var depth:Int 
    }
}
