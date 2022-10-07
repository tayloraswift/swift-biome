extension Article:BranchIntrinsic
{
    struct Divergence:Sendable
    {
        var metadata:AlternateHead<Metadata?>?
        var documentation:AlternateHead<DocumentationExtension<Never>>?

        init()
        {
            self.metadata = nil 
            self.documentation = nil
        }

        var isEmpty:Bool
        {
            if  case nil = self.metadata, 
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
extension Article.Divergence:BranchDivergence
{
    typealias Key = Atom<Article>

    struct Base
    {
        var metadata:OriginalHead<Article.Metadata?>?
        var documentation:OriginalHead<DocumentationExtension<Never>>?

        init()
        {
            self.metadata = nil 
            self.documentation = nil
        }
    }

    mutating
    func revert(to rollbacks:History.Rollbacks)
    {
        self.metadata.revert(to: rollbacks.metadata.articles)
        self.documentation.revert(to: rollbacks.data.standaloneDocumentation)
    }
}
extension Article.Divergence.Base:BranchIntrinsicBase
{
    mutating
    func revert(to rollbacks:History.Rollbacks)
    {
        self.metadata.revert(to: rollbacks.metadata.articles)
        self.documentation.revert(to: rollbacks.data.standaloneDocumentation)
    }
}