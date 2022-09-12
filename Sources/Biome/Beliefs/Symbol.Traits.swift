import SymbolGraphs

extension Symbol.Traits:Sendable where Position:Sendable 
{
}
extension Symbol 
{
    struct Traits<Position>:Equatable where Position:Hashable
    {
        /// if a concrete type, the members of this type, not including members 
        /// inherited through protocol conformances. 
        /// if a protocol, the members in extensions of this protocol. 
        /// 
        /// requirements and witnesses must not access this property.
        var members:Set<Position>
        
        private 
        var unconditional:Set<Position>
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
        var features:Set<Position>
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
        var implementations:Set<Position>
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
        var downstream:Set<Position>
        
        private 
        var conditional:[Position: [Generic.Constraint<Position>]]
        /// if a protocol, concrete types that implement this protocol.
        /// 
        /// this shares backing storage with ``conformances``. concrete types 
        /// should access ``conformances`` instead. requirements and witnesses 
        /// must not access this property.
        var conformers:[Position: [Generic.Constraint<Position>]]
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
        var conformances:[Position: [Generic.Constraint<Position>]]
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
        
        init(_ traits:some Sequence<Trait<Position>>, as community:Community)
        {
            self.init()
            self.update(with: traits, as: community)
        }
        
        mutating 
        func update(with traits:some Sequence<Trait<Position>>, as community:Community) 
        {
            switch community 
            {
            case .associatedtype:
                for trait:Trait<Position> in traits 
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
                for trait:Trait<Position> in traits 
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
                for _:Trait<Position> in traits 
                {
                    fatalError("unreachable")
                }
            
            case .concretetype(_):
                for trait:Trait<Position> in traits 
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
                for trait:Trait<Position> in traits 
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
            for (symbol, conditions):(Position, [Generic.Constraint<Position>]) in 
                other.conditional
            {
                if  let counterpart:Dictionary<Position, [Generic.Constraint<Position>]>.Index = 
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

        func map<T>(_ transform:(Position) throws -> T) rethrows -> Traits<T>
            where T:Hashable
        {
            fatalError("unimplemented")
        }
    }
}