extension Biome.Symbol 
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
        
        case `associatedtype`(TypeWitness)
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
            case .protocol(let abstract):
                return abstract.members
            case .associatedtype:
                return nil
            case .witness: 
                return nil 
            }
        }
        var overrideOf:Int? 
        {
            switch self 
            {
            case .associatedtype(let witness): 
                return witness.overrideOf
            case .witness(let witness, callable: _): 
                return witness.overrideOf
            default: 
                return nil
            }
        }
        var requirementOf:Int? 
        {
            switch self 
            {
            case .associatedtype(let witness): 
                return witness.requirementOf
            case .witness(let witness, callable: _): 
                return witness.requirementOf
            default: 
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
            case .associatedtype:
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
        struct TypeWitness:Sendable 
        {
            var requirementOf:Int, 
                overrideOf:Int?
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
                    throw Biome.LinkingError.island(associatedtype: index)
                }
                self = .associatedtype(.init(
                    requirementOf: interface, 
                    overrideOf: references.overrideOf))
                
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
                    throw Biome.LinkingError.members(references.members, in: kind, index) 
                }
                guard references.upstream.isEmpty
                else 
                {
                    throw Biome.LinkingError.conformances(references.upstream, in: kind, index) 
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
                    throw Biome.LinkingError.conformers(references.downstream, in: kind, index) 
                }
                guard references.requirements.isEmpty
                else
                {
                    throw Biome.LinkingError.requirements(references.requirements, in: kind, index) 
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
                    throw Biome.LinkingError.subclasses(references.subclasses, in: kind, index) 
                }
                if let superclass:Int = references.superclass
                {
                    throw Biome.LinkingError.superclass(superclass, in: kind, index) 
                }
            }
            // callables and associatedtypes can be requirements 
            // callables and associatedtypes can be overrides
            // callables and associatedtypes can have overrides
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
                    throw Biome.LinkingError.requirementOf(interface, kind, index) 
                }
                // overrides are reciprocal 
                if let overridden:Int = references.overrideOf
                {
                    throw Biome.LinkingError.overrideOf(overridden, kind, index) 
                }
            }
            // callables can be default implementations
            // callables can have default implementations
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
                    throw Biome.LinkingError.defaultImplementationOf(references.defaultImplementationOf, kind, index) 
                }
            }
        }
    }
}
