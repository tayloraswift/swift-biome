extension Symbol:BranchElement
{
    struct Metadata:Equatable, Sendable
    {
        let roles:Branch.SymbolRoles?
        var primary:Branch.SymbolTraits
        var accepted:[Position<Module>: Branch.SymbolTraits] 

        init(roles:Branch.SymbolRoles?,
            primary:Branch.SymbolTraits,
            accepted:[Position<Module>: Branch.SymbolTraits] = [:])
        {
            self.roles = roles
            self.primary = primary
            self.accepted = accepted
        }

        func contains(feature:Compound) -> Bool 
        {
            feature.culture == feature.host.culture ?
                self.primary.features.contains(feature.base) :
                self.accepted[feature.culture]?.features.contains(feature.base) ?? false
        }
    }

    public
    struct Divergence:Voidable, Sendable 
    {
        var metadata:History<Metadata?>.Divergent?
        var declaration:History<Declaration<Position<Symbol>>>.Divergent?
        var documentation:History<DocumentationExtension<Position<Symbol>>>.Divergent?

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

        func contains(feature:Position<Symbol>) -> Bool 
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
