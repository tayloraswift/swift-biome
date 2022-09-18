extension Symbol:BranchElement
{
    struct Metadata:Equatable, Sendable
    {
        let roles:Branch.SymbolRoles?
        var primary:Branch.SymbolTraits
        var accepted:[Branch.Position<Module>: Branch.SymbolTraits] 

        init(roles:Branch.SymbolRoles?,
            primary:Branch.SymbolTraits,
            accepted:[Branch.Position<Module>: Branch.SymbolTraits] = [:])
        {
            self.roles = roles
            self.primary = primary
            self.accepted = accepted
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
        var metadata:History<Metadata?>.Divergent?
        var declaration:History<Declaration<Branch.Position<Symbol>>>.Divergent?
        var documentation:History<DocumentationExtension<Branch.Position<Symbol>>>.Divergent?

        init() 
        {
            self.metadata = nil
            self.declaration = nil
            self.documentation = nil
        }
    }

    struct ForeignMetadata:Equatable, Sendable 
    {
        let traits:Branch.SymbolTraits

        init(traits:Branch.SymbolTraits)
        {
            self.traits = traits 
        }

        func contains(feature:Branch.Position<Symbol>) -> Bool 
        {
            self.traits.features.contains(feature)
        }
    }
    
    struct ForeignDivergence:Voidable
    {
        var metadata:History<ForeignMetadata?>.Divergent?

        init() 
        {
            self.metadata = nil
        }
    }
}
