import SymbolGraphs
import SymbolSource

extension Symbol:BranchElement
{
    struct Metadata:Equatable, Sendable
    {
        let roles:Branch.SymbolRoles?
        var primary:Branch.SymbolTraits
        var accepted:[Atom<Module>: Branch.SymbolTraits] 

        init(roles:Branch.SymbolRoles?,
            primary:Branch.SymbolTraits,
            accepted:[Atom<Module>: Branch.SymbolTraits] = [:])
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
        var metadata:AlternateHead<Metadata?>?
        var declaration:AlternateHead<Declaration<Atom<Symbol>>>?
        var documentation:AlternateHead<DocumentationExtension<Atom<Symbol>>>?

        init() 
        {
            self.metadata = nil
            self.declaration = nil
            self.documentation = nil
        }

        var isEmpty:Bool
        {
            if  case nil = self.metadata, 
                case nil = self.declaration,
                case nil = self.documentation
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
