extension Symbol 
{
    enum Trait:Equatable
    {
        // members 
        case member(Index)
        case feature(Index)
        // implementations 
        case implementation(Index)
        // downstream
        case refinement(Index)
        case subclass(Index)
        case override(Index)
        // conformers
        case conformer(Conditional)
        // conformances
        case conformance(Conditional)
        
        var feature:Index? 
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
        var conditional:[Index: Set<Generic.Constraint<Index>>]
        /// if a protocol, concrete types that implement this protocol.
        /// 
        /// this shares backing storage with ``conformances``. concrete types 
        /// should access ``conformances`` instead. requirements and witnesses 
        /// must not access this property.
        var conformers:[Index: Set<Generic.Constraint<Index>>]
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
        var conformances:[Index: Set<Generic.Constraint<Index>>]
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
        
        init<Traits>(_ traits:Traits, as color:Color)
            where Traits:Sequence, Traits.Element == Trait
        {
            self.init()
            self.update(with: traits, as: color)
        }
        
        mutating 
        func update<Traits>(with traits:Traits, as color:Color) 
            where Traits:Sequence, Traits.Element == Trait
        {
            switch color 
            {
            case .associatedtype:
                for trait:Trait in traits 
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
                for trait:Trait in traits 
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
                        self.conformers[conformer.index] = conformer.conditions
                    default: 
                        fatalError("unreachable")
                    }
                }
            
            case .typealias, .global(_): 
                for _:Trait in traits 
                {
                    fatalError("unreachable")
                }
            
            case .concretetype(_):
                for trait:Trait in traits 
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
                        self.conformances[conformance.index] = conformance.conditions
                    default: 
                        fatalError("unreachable")
                    }
                }
            
            case .callable(_):
                for trait:Trait in traits 
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
    }
}
