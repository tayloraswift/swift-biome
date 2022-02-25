extension Biome 
{
    enum AvailabilityDomainError:Error 
    {
        case duplicate(Symbol.Availability)
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
        enum Callable:Sendable 
        {
            case `subscript`(instance:Bool, parameters:Void, returns:Void)
            case `func`(instance:Bool?, parameters:Void, returns:Void)
            case `var`(instance:Bool?)
            
            case `operator`(parameters:Void, returns:Void)
            case `case`(parameters:Void)
            case initializer(parameters:Void)
            case deinitializer
        }
        enum Relationships:Sendable 
        {
            case `typealias`
            
            case `enum`(Concrete)
            case `struct`(Concrete)
            case `class`(Concrete, subclasses:[Int], superclass:Int?)
            case `actor`(Concrete)
            case `protocol`(Abstract)
            case `associatedtype`(of:Int)
            
            case witness(Witness, callable:Callable)
            
            var members:[Int]? 
            {
                switch self 
                {
                case .typealias: 
                    return nil
                case    .enum(let concrete),
                        .struct(let concrete),
                        .class(let concrete, subclasses: _, superclass: _),
                        .actor(let concrete):
                    return concrete.members.isEmpty ? nil : concrete.members
                case .protocol:
                    return nil
                case .associatedtype:
                    return nil
                case .witness: 
                    return nil 
                }
            }
            
            mutating 
            func sort(by ascending:(Int, Int) -> Bool) 
            {
                switch self 
                {
                case .typealias: 
                    break 
                case .enum(var concrete):
                    concrete.sort(by: ascending)
                    self = .enum(concrete)
                case .struct(var concrete):
                    concrete.sort(by: ascending)
                    self = .struct(concrete)
                case .class(var concrete, subclasses: var subclasses, superclass: let superclass):
                    concrete.sort(by: ascending)
                    subclasses.sort(by: ascending)
                    self = .class(concrete, subclasses: subclasses, superclass: superclass)
                case .actor(var concrete):
                    concrete.sort(by: ascending)
                    self = .actor(concrete)
                case .protocol(var abstract):
                    abstract.sort(by: ascending)
                    self = .protocol(abstract)
                case .associatedtype(of: _):
                    break
                case .witness(var witness, callable: let callable): 
                    witness.sort(by: ascending)
                    self = .witness(witness, callable: callable)
                }
            }
            
            struct Abstract:Sendable 
            {
                private(set)
                var requirements:[Int],
                    members:[Int], 
                    
                    upstream:[Int], // protocols this type conforms to
                    downstream:[Int], // protocols that refine this type (empty if not a protocol)
                    conformers:[(index:Int, conditions:[Language.Constraint])]
                
                mutating 
                func sort(by ascending:(Int, Int) -> Bool) 
                {
                    self.requirements.sort(by: ascending)
                    self.members.sort(by: ascending)
                    self.upstream.sort(by: ascending)
                    self.downstream.sort(by: ascending)
                    self.conformers.sort
                    {
                        ascending($0.index, $1.index)
                    }
                }
            }
            struct Concrete:Sendable 
            {
                private(set)
                var members:[Int], 
                    upstream:[(index:Int, conditions:[Language.Constraint])]
                
                mutating 
                func sort(by ascending:(Int, Int) -> Bool) 
                {
                    self.members.sort(by: ascending)
                    self.upstream.sort
                    {
                        ascending($0.index, $1.index)
                    }
                }
            }
            struct Witness:Sendable 
            {
                var defaultImplementationOf:[Int],
                    defaultImplementations:[Int]
                var overrideOf:Int?,
                    _overrides:[Int]
                var requirementOf:Int? // points to a protocol 
                
                mutating 
                func sort(by ascending:(Int, Int) -> Bool) 
                {
                    self.defaultImplementationOf.sort(by: ascending)
                    self.defaultImplementations.sort(by: ascending)
                    self._overrides.sort(by: ascending)
                }
            }
            
            init(index:Int, references:Biome.Edge.References, colors:[Kind]) throws
            {
                let kind:Kind = colors[index]
                var witness:Witness 
                {
                    .init(
                        defaultImplementationOf: references.defaultImplementationOf, 
                        defaultImplementations: references.defaultImplementations, 
                        overrideOf: references.overrideOf,
                        _overrides: references._overrides, 
                        requirementOf: references.requirementOf)
                }
                var concrete:Concrete 
                {
                    .init(members: references.members, upstream: references.upstream)
                }
                var abstract:Abstract 
                {
                    var downstream:[Int] = [], 
                        conformers:[(index:Int, conditions:[Language.Constraint])] = []
                    for (index, conditions):(Int, [Language.Constraint]) in references.downstream 
                    {
                        if case .protocol = colors[index]
                        {
                            downstream.append(index)
                        }
                        else 
                        {
                            conformers.append((index, conditions))
                        }
                    }
                    let upstream:[Int] = references.upstream.map 
                    {
                        if !$0.conditions.isEmpty 
                        {
                            print("warning: conditions '\($0.conditions)' on protocol-to-protocol refinement")
                        }
                        return $0.index
                    }
                    return .init(requirements: references.requirements, members: references.members, 
                        upstream: upstream, downstream: downstream, conformers: conformers)
                }
                switch kind 
                {
                case .typealias:
                    self = .typealias
                case .enum:
                    self = .enum(concrete)
                case .struct:
                    self = .struct(concrete)
                case .class:
                    self = .class(concrete, subclasses: references.subclasses, superclass: references.superclass)
                case .actor:
                    self = .actor(concrete)
                case .protocol:
                    self = .protocol(abstract)
                case .associatedtype:
                    guard let interface:Int = references.requirementOf 
                    else 
                    {
                        throw LinkingError.island(associatedtype: index)
                    }
                    self = .associatedtype(of: interface)
                    
                case .instanceSubscript:
                    self = .witness(witness, callable: .subscript(instance: true, parameters: (), returns: ()))
                case .typeSubscript:
                    self = .witness(witness, callable: .subscript(instance: false, parameters: (), returns: ()))
                case .instanceMethod:
                    self = .witness(witness, callable: .func(instance: true, parameters: (), returns: ()))
                case .typeMethod:
                    self = .witness(witness, callable: .func(instance: false, parameters: (), returns: ()))
                case .func:
                    self = .witness(witness, callable: .func(instance: nil, parameters: (), returns: ()))
                case .instanceProperty:
                    self = .witness(witness, callable: .var(instance: true))
                case .typeProperty:
                    self = .witness(witness, callable: .var(instance: false))
                case .var:
                    self = .witness(witness, callable: .var(instance: nil))
                case .operator:
                    self = .witness(witness, callable: .operator(parameters: (), returns: ()))
                case .case:
                    self = .witness(witness, callable: .case(parameters: ()))
                case .initializer:
                    self = .witness(witness, callable: .initializer(parameters: ()))
                case .deinitializer:
                    self = .witness(witness, callable: .deinitializer)
                }
                
                // abstract and concrete types can have members 
                // abstract and concrete types can conform to things 
                switch kind 
                {
                case    .enum, .struct, .class, .actor, .protocol:
                    break 
                default:
                    guard references.members.isEmpty 
                    else 
                    {
                        throw LinkingError.members(references.members, in: kind, index) 
                    }
                    guard references.upstream.isEmpty
                    else 
                    {
                        throw LinkingError.conformances(references.upstream, in: kind, index) 
                    }
                }
                // protocols can have conformers
                // protocols can have requirements 
                switch kind 
                {
                case    .protocol:
                    break 
                default:
                    guard references.downstream.isEmpty
                    else
                    {
                        throw LinkingError.conformers(references.downstream, in: kind, index) 
                    }
                    guard references.requirements.isEmpty
                    else
                    {
                        throw LinkingError.requirements(references.requirements, in: kind, index) 
                    }
                }
                // classes can subclass things
                // classes can be subclasses
                switch kind 
                {
                case    .class:
                    break 
                default:
                    guard references.subclasses.isEmpty
                    else
                    {
                        throw LinkingError.subclasses(references.subclasses, in: kind, index) 
                    }
                    if let superclass:Int = references.superclass
                    {
                        throw LinkingError.superclass(superclass, in: kind, index) 
                    }
                }
                // callables and associatedtypes can be requirements 
                switch kind 
                {
                case    .initializer, .typeSubscript, .instanceSubscript, 
                        .typeProperty, .instanceProperty, 
                        .typeMethod, .instanceMethod, .operator, 
                        .associatedtype:
                    break 
                default:
                    if let interface:Int = references.requirementOf
                    {
                        throw LinkingError.requirementOf(interface, kind, index) 
                    }
                }
                // callables can be default implementations
                // callables can have default implementations
                // callables can be overrides
                // callables can have overrides
                switch kind 
                {
                case    .initializer, .typeSubscript, .instanceSubscript, 
                        .typeProperty, .instanceProperty, 
                        .typeMethod, .instanceMethod, .operator:
                    break 
                default:
                    // default implementations are reciprocal, so we don’t need 
                    // to check `references.defaultImplementations.isEmpty` because the other 
                    // node will check it for us.
                    guard references.defaultImplementationOf.isEmpty 
                    else 
                    {
                        throw LinkingError.defaultImplementationOf(references.defaultImplementationOf, kind, index) 
                    }
                    // overrides are reciprocal 
                    if let overridden:Int = references.overrideOf
                    {
                        throw LinkingError.overrideOf(overridden, kind, index) 
                    }
                }
            }
        }
        
        public 
        let id:ID
        let graph:Graph 
        let path:Path
        let title:String 
        let qualified:[Language.Lexeme]
        let signature:[Language.Lexeme]
        let declaration:[Language.Lexeme]
        
        let extends:(module:Module.ID, where:[Language.Constraint])?
        let generic:(parameters:[Generic], constraints:[Language.Constraint])?
        let availability:[Domain: Availability]
        
        var comment:(text:String, processed:Biome.Comment)
        
        let breadcrumbs:(last:String, parent:Int?)
        let relationships:Relationships
            
        var topics:
        (
            requirements:[(heading:Biome.Topic, indices:[Int])],
            members:[(heading:Biome.Topic, indices:[Int])]
        )
        
        init(path:Path, breadcrumbs:Breadcrumbs, parent:Int?, relationships:Relationships, descriptor:SymbolDescriptor) 
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
            self.id             = descriptor.id
            self.graph          = breadcrumbs.graph 
            self.path           = path
            self.title          = descriptor.title 
            self.breadcrumbs    = (breadcrumbs.last, parent)
            self.qualified      = breadcrumbs.lexemes 
            if let keyword:String = keyword 
            {
                self.signature  = [.code(keyword, class: .keyword(.other)), .spaces(1)] + self.qualified
            }
            else 
            {
                self.signature  = descriptor.signature
            }
            self.declaration    = descriptor.declaration
            self.relationships  = relationships
            self.extends        = descriptor.extends
            self.generic        = descriptor.generic
            self.availability   = try .init(descriptor.availability)
            {
                throw AvailabilityDomainError.duplicate($1)
            }
            self.comment        = (descriptor.comment, .init())
            
            self.topics         = ([], [])
        }
        
        var module:Module.ID 
        {
            self.graph.module 
        }
        var namespace:Module.ID 
        {
            self.graph.namespace
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
    struct Path:Hashable, Sendable
    {
        let group:String
        var disambiguation:ID?
        
        var canonical:String 
        {
            if let id:ID = self.disambiguation 
            {
                return "\(self.group)?overload=\(id.string)"
            }
            else 
            {
                return self.group
            }
        }
        init(group:String, disambiguation:ID? = nil)
        {
            self.group          = group
            self.disambiguation = disambiguation
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
