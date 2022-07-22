import SymbolGraphs

extension Symbol.Trait:Equatable where Target:Equatable {}
extension Symbol.Trait:Sendable where Target:Sendable {}
extension Symbol 
{
    enum Trait<Target>
    {
        // members 
        case member(Target)
        case feature(Target)
        // implementations 
        case implementation(Target)
        // downstream
        case refinement(Target)
        case subclass(Target)
        case override(Target)
        // conformers
        case conformer(Generic.Conditional<Target>)
        // conformances
        case conformance(Generic.Conditional<Target>)
        
        var feature:Target? 
        {
            if case .feature(let feature) = self 
            {
                return feature
            }
            else 
            {
                return nil
            }
        }
        
        func map<T>(_ transform:(Target) throws -> T) rethrows -> Trait<T>
        {
            switch self 
            {
            case .member(let target): 
                return .member(try transform(target))
            case .feature(let target): 
                return .feature(try transform(target))
            case .implementation(let target): 
                return .implementation(try transform(target))
            case .refinement(let target): 
                return .refinement(try transform(target))
            case .subclass(let target): 
                return .subclass(try transform(target))
            case .override(let target): 
                return .override(try transform(target))
            case .conformer(let target): 
                return .conformer(try target.map(transform))
            case .conformance(let target): 
                return .conformance(try target.map(transform))
            }
        }
    }
    struct Traits:Equatable, Sendable 
    {
        /// if a concrete type, the members of this type, not including members 
        /// inherited through protocol conformances. 
        /// if a protocol, the members in extensions of this protocol. 
        /// 
        /// requirements and witnesses must not access this property.
        var members:Set<Index>
        
        private 
        var unconditional:Set<Index>
        /// if a concrete type, members of this type inherited through 
        /// protocol conformances.
        /// 
        /// this shares backing storage with ``implementations``. requirements 
        /// should access ``implementations`` instead. protocols and witnesses 
        /// must not access this property.
        /// 
        /// > note: for concrete types, the module that an inherited member 
        /// originates from is not necessarily the perpetrator of the conformance 
        /// that trafficked it into its scope.
        var features:Set<Index>
        {
            _read 
            {
                yield self.unconditional
            }
            _modify
            {
                yield &self.unconditional
            }
        }
        
        /// if a requirement, the default implementations available for this 
        /// requirement. 
        /// 
        /// this shares backing storage with ``features``. types and witnesses 
        /// must not access this property.
        var implementations:Set<Index>
        {
            _read 
            {
                yield self.unconditional
            }
            _modify
            {
                yield &self.unconditional
            }
        }
        
        /// if a protocol, protocols that inherit from this protocol.
        /// if a class, classes that subclass this class.
        /// if a requirement, any requirements of protocols that refine its
        /// interface that also restate this requirement.
        /// if a witness, any subclass members that override this witness, if 
        /// it is a class member.
        var downstream:Set<Index>
        
        private 
        var conditional:[Index: [Generic.Constraint<Index>]]
        /// if a protocol, concrete types that implement this protocol.
        /// 
        /// this shares backing storage with ``conformances``. concrete types 
        /// should access ``conformances`` instead. requirements and witnesses 
        /// must not access this property.
        var conformers:[Index: [Generic.Constraint<Index>]]
        {
            _read 
            {
                yield self.conditional
            }
            _modify
            {
                yield &self.conditional
            }
        }
        /// if a concrete type, protocols this type conforms to.
        /// 
        /// this shares backing storage with ``conformers``. protocols 
        /// should access ``conformers`` instead. requirements and witnesses 
        /// must not access this property.
        var conformances:[Index: [Generic.Constraint<Index>]]
        {
            _read 
            {
                yield self.conditional
            }
            _modify
            {
                yield &self.conditional
            }
        }
        
        init() 
        {
            self.members = []
            self.downstream = []
            self.unconditional = []
            self.conditional = [:]
        }
        
        init<Traits>(_ traits:Traits, as community:Community)
            where Traits:Sequence, Traits.Element == Trait<Index>
        {
            self.init()
            self.update(with: traits, as: community)
        }
        
        mutating 
        func update<Traits>(with traits:Traits, as community:Community) 
            where Traits:Sequence, Traits.Element == Trait<Index>
        {
            switch community 
            {
            case .associatedtype:
                for trait:Trait<Index> in traits 
                {
                    switch trait 
                    {
                    //  [0] (uninhabited)
                    //  [1] (uninhabited)
                    //  [2] restatements (``downstream``)
                    case .override(let downstream):
                        self.downstream.insert(downstream)
                    //  [3] default implementations (``implementations``)
                    case .implementation(let implementation): 
                        self.implementations.insert(implementation)
                    default:
                        fatalError("unreachable")
                    }
                }
            
            case .protocol:
                for trait:Trait<Index> in traits 
                {
                    switch trait 
                    {
                    //  [0] extension members (``members``)
                    case .member(let member):
                        self.members.insert(member)
                    //  [1] (uninhabited; requirements are stored in ``Roles``)
                    //  [2] inheriting protocols (``downstream``)
                    case .refinement(let downstream):
                        self.downstream.insert(downstream)
                    //  [3] conforming types (``conformers``)
                    case .conformer(let conformer):
                        self.conformers[conformer.target] = conformer.conditions
                    default: 
                        fatalError("unreachable")
                    }
                }
            
            case .typealias, .global(_): 
                for _:Trait<Index> in traits 
                {
                    fatalError("unreachable")
                }
            
            case .concretetype(_):
                for trait:Trait<Index> in traits 
                {
                    switch trait 
                    {
                    //  [0] members (``members``)
                    case .member(let member):
                        self.members.insert(member)
                    //  [1] features (``features``)
                    case .feature(let feature):
                        self.features.insert(feature)
                    //  [2] subclasses (``downstream``)
                    case .subclass(let downstream):
                        self.downstream.insert(downstream)
                    //  [3] protocol conformances (``conformances``)
                    case .conformance(let conformance):
                        self.conformances[conformance.target] = conformance.conditions
                    default: 
                        fatalError("unreachable")
                    }
                }
            
            case .callable(_):
                for trait:Trait<Index> in traits 
                {
                    switch trait 
                    {
                    //  [0] (uninhabited)
                    //  [1] (uninhabited)
                    //  [2] overriding callables or restatements (``downstream``)
                    case .override(let downstream):
                        self.downstream.insert(downstream)
                    //  [3] default implementations (``implementations``)
                    case .implementation(let implementation):
                        self.implementations.insert(implementation)
                    default: 
                        fatalError("unreachable")
                    }
                }
            }
        }
        
        mutating 
        func subtract(_ other:Self) 
        {
            self.members.subtract(other.members)
            self.downstream.subtract(other.downstream)
            self.unconditional.subtract(other.unconditional)
            for (symbol, conditions):(Index, [Generic.Constraint<Index>]) in 
                other.conditional
            {
                if  let counterpart:Dictionary<Index, [Generic.Constraint<Index>]>.Index = 
                    self.conditional.index(forKey: symbol), 
                    self.conditional.values[counterpart] == conditions 
                {
                    self.conditional.remove(at: counterpart)
                }
            }
        }
        func subtracting(_ other:Self) -> Self
        {
            var traits:Self = self 
            traits.subtract(other)
            return traits
        }
    }
}
