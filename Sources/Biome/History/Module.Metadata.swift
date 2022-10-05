import SymbolSource 

extension Module:BranchElement
{
    struct Metadata:Equatable, Sendable 
    {
        let dependencies:Set<Atom<Module>>

        init(dependencies:Set<Atom<Module>>)
        {
            self.dependencies = dependencies
        }
    }

    public 
    struct Divergence:Voidable, Sendable 
    {
        // important! do not add fields without also updating the `isEmpty` definition!
        var symbols:[(range:Range<Symbol.Offset>, namespace:Atom<Module>)]
        var articles:[Range<Article.Offset>]

        var metadata:AlternateHead<Metadata?>?

        var topLevelArticles:AlternateHead<Set<Atom<Article>>>?
        var topLevelSymbols:AlternateHead<Set<Atom<Symbol>>>?
        var documentation:AlternateHead<DocumentationExtension<Never>>?
        
        init()
        {
            self.symbols = []
            self.articles = []

            self.metadata = nil
            
            self.topLevelArticles = nil
            self.topLevelSymbols = nil
            self.documentation = nil
        }

        var isEmpty:Bool
        {
            if  case nil = self.metadata, 
                case nil = self.topLevelArticles,
                case nil = self.topLevelSymbols,
                case nil = self.documentation,
                self.symbols.isEmpty,
                self.articles.isEmpty
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