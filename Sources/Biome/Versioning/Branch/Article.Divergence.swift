extension Article:BranchIntrinsic
{
    struct Divergence:BranchDivergence, Sendable
    {
        typealias Key = Atom<Article>

        struct Base:BranchIntrinsicBase
        {
            var metadata:OriginalHead<Metadata?>?
            var documentation:OriginalHead<DocumentationExtension<Never>>?

            init()
            {
                self.metadata = nil 
                self.documentation = nil
            }
        }
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