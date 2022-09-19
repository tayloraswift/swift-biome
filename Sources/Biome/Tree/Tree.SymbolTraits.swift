extension Tree.SymbolTraits.Unconditional 
{
    fileprivate mutating 
    func insert(_ element:PluralPosition<Symbol>) 
    {
        self.updateValue(element.branch, forKey: element.contemporary)
    }
}
extension Tree 
{
    struct SymbolTraits 
    {
        typealias Unconditional = 
        [
            Position<Symbol>: Version.Branch
        ]
        typealias Conditional = 
        [
            Position<Symbol>: (Version.Branch, [Generic.Constraint<PluralPosition<Symbol>>])
        ]

        var members:Unconditional
        var downstream:Unconditional
        private 
        var unconditional:Unconditional
        private 
        var conditional:Conditional
        
        init(members:Unconditional = [:],
            downstream:Unconditional = [:],
            unconditional:Unconditional = [:],
            conditional:Conditional = [:]) 
        {
            self.members = members
            self.downstream = downstream
            self.unconditional = unconditional
            self.conditional = conditional
        }
        
        init(_ traits:some Sequence<Symbol.Trait<PluralPosition<Symbol>>>, as community:Community)
        {
            self.init()
            self.update(with: traits, as: community)
        }
    }
}
extension Tree.SymbolTraits 
{
    var features:Unconditional
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
    var implementations:Unconditional
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
    var conformers:Conditional
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
    var conformances:Conditional
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

    mutating 
    func update(with traits:some Sequence<Symbol.Trait<PluralPosition<Symbol>>>, 
        as community:Community) 
    {
        switch community 
        {
        case .associatedtype:
            for trait:Symbol.Trait<PluralPosition<Symbol>> in traits 
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
            for trait:Symbol.Trait<PluralPosition<Symbol>> in traits 
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
                    self.conformers[conformer.target.contemporary] = 
                        (conformer.target.branch, conformer.conditions)
                default: 
                    fatalError("unreachable")
                }
            }
        
        case .typealias, .global(_): 
            for _:Symbol.Trait<PluralPosition<Symbol>> in traits 
            {
                fatalError("unreachable")
            }
        
        case .concretetype(_):
            for trait:Symbol.Trait<PluralPosition<Symbol>> in traits 
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
                    self.conformances[conformance.target.contemporary] = 
                        (conformance.target.branch, conformance.conditions)
                default: 
                    fatalError("unreachable")
                }
            }
        
        case .callable(_):
            for trait:Symbol.Trait<PluralPosition<Symbol>> in traits 
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
extension Tree.SymbolTraits 
{
    func idealized() -> Branch.SymbolTraits
    {
        .init(members: .init(self.members.keys), 
            downstream: .init(self.downstream.keys), 
            unconditional: .init(self.unconditional.keys), 
            conditional: self.conditional.mapValues 
            { 
                $0.1.map { $0.map(\.contemporary) } 
            })
    }
    func subtracting(_ other:Branch.SymbolTraits) -> Self
    {
        .init(
            members: self.members.filter 
            {
                !other.members.contains($0.key)
            },
            downstream: self.downstream.filter 
            {
                !other.downstream.contains($0.key)
            },
            unconditional: self.unconditional.filter 
            {
                !other.unconditional.contains($0.key)
            },
            conditional: self.conditional.filter 
            {
                if  let counterpart:[Generic.Constraint<Position<Symbol>>] = 
                        other.conditional[$0.key]
                {
                    return counterpart.elementsEqual($0.value.1.lazy.map 
                    { 
                        $0.map(\.contemporary) 
                    }) 
                }
                else 
                {
                    return true 
                }
            })
    }
}