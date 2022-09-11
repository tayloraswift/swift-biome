extension Symbol:BranchElement
{
    struct Metadata:Equatable, Sendable
    {
        let roles:Roles<Branch.Position<Symbol>>?
        let primary:Traits<Branch.Position<Symbol>>
        let accepted:[Branch.Position<Module>: Traits<Branch.Position<Symbol>>] 

        init(roles:Roles<Branch.Position<Symbol>>?,
            primary:Traits<Branch.Position<Symbol>>,
            accepted:[Branch.Position<Module>: Traits<Branch.Position<Symbol>>])
        {
            self.roles = roles
            self.primary = primary
            self.accepted = accepted
        }
        init(facts:__shared Symbol.Facts<Tree.Position<Symbol>>)
        {
            self.init(
                roles: facts.roles?.map(\.contemporary), 
                primary: facts.primary.map(\.contemporary), 
                accepted: facts.accepted.mapValues { $0.map(\.contemporary) })
        }

        func contains(feature composite:Branch.Composite) -> Bool 
        {
            if  composite.culture == composite.diacritic.host.culture 
            {
                return self.primary.features
                    .contains(composite.base)
            }
            else 
            {
                return self.accepted[composite.culture]?.features
                    .contains(composite.base) ?? false
            }
        }
    }

    public
    struct Divergence:Voidable, Sendable 
    {
        var metadata:_History<Metadata?>.Divergent?

        init() 
        {
            self.metadata = nil
        }
    }

    struct ForeignMetadata:Equatable, Sendable 
    {
        let traits:Traits<Branch.Position<Symbol>>

        init(traits:Traits<Branch.Position<Symbol>>)
        {
            self.traits = traits 
        }
        init(traits:__shared Symbol.Traits<Tree.Position<Symbol>>)
        {
            self.init(traits: traits.map(\.contemporary))
        }

        func contains(feature:Branch.Position<Symbol>) -> Bool 
        {
            self.traits.features.contains(feature)
        }
    }
    
    struct ForeignDivergence:Voidable
    {
        var metadata:_History<ForeignMetadata?>.Divergent?

        init() 
        {
            self.metadata = nil
        }
    }
}
