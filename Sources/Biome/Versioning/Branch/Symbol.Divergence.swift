import SymbolGraphs
import SymbolSource

extension Symbol:BranchIntrinsic
{
    struct Divergence:BranchDivergence, Sendable 
    {
        typealias Key = Atom<Symbol>
        
        struct Base:BranchIntrinsicBase
        {
            var metadata:OriginalHead<Metadata?>?
            var declaration:OriginalHead<Declaration<Atom<Symbol>>>?
            var documentation:OriginalHead<DocumentationExtension<Atom<Symbol>>>?

            init()
            {
                self.metadata = nil 
                self.declaration = nil
                self.documentation = nil
            }
        }

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