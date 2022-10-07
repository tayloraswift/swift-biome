import SymbolGraphs
import SymbolSource

extension Symbol:BranchIntrinsic
{
    struct Divergence:Sendable 
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
extension Symbol.Divergence:BranchDivergence
{
    typealias Key = Atom<Symbol>

    struct Base
    {
        var metadata:OriginalHead<Symbol.Metadata?>?
        var declaration:OriginalHead<Declaration<Atom<Symbol>>>?
        var documentation:OriginalHead<DocumentationExtension<Atom<Symbol>>>?

        init()
        {
            self.metadata = nil 
            self.declaration = nil
            self.documentation = nil
        }
    }

    mutating
    func revert(to rollbacks:History.Rollbacks)
    {
        self.metadata.revert(to: rollbacks.metadata.symbols)
        self.declaration.revert(to: rollbacks.data.declarations)
        self.documentation.revert(to: rollbacks.data.cascadingDocumentation)
    }
}
extension Symbol.Divergence.Base:BranchIntrinsicBase
{
    mutating
    func revert(to rollbacks:History.Rollbacks)
    {
        self.metadata.revert(to: rollbacks.metadata.symbols)
        self.declaration.revert(to: rollbacks.data.declarations)
        self.documentation.revert(to: rollbacks.data.cascadingDocumentation)
    }
}