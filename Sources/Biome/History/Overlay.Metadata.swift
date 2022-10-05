extension Overlay:BranchElement
{
    struct Metadata:Equatable, Sendable 
    {
        let traits:Branch.SymbolTraits

        init(traits:Branch.SymbolTraits)
        {
            self.traits = traits 
        }

        func contains(feature:Atom<Symbol>) -> Bool 
        {
            self.traits.features.contains(feature)
        }
    }

    struct Divergence:Voidable
    {
        var metadata:AlternateHead<Metadata?>?

        init() 
        {
            self.metadata = nil
        }

        var isEmpty:Bool
        {
            if case nil = self.metadata
            {
                return true
            }
            else 
            {
                return false
            }
        }
    }
}