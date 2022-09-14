extension Module:BranchElement
{
    struct Metadata:Equatable, Sendable 
    {
        let dependencies:Set<Branch.Position<Module>>

        init(dependencies:Set<Branch.Position<Module>>)
        {
            self.dependencies = dependencies
        }
        init(namespaces:__shared Namespaces)
        {
            self.init(dependencies: namespaces.dependencies())
        }
    }

    public 
    struct Divergence:Voidable, Sendable 
    {
        var symbols:[(range:Range<Symbol.Offset>, namespace:Branch.Position<Module>)]
        var articles:[Range<Article.Offset>]

        var metadata:_History<Metadata?>.Divergent?

        var topLevelArticles:_History<Set<Branch.Position<Article>>>.Divergent?
        var topLevelSymbols:_History<Set<Branch.Position<Symbol>>>.Divergent?
        var documentation:_History<DocumentationExtension<Never>>.Divergent?
        
        init()
        {
            self.symbols = []
            self.articles = []

            self.metadata = nil
            
            self.topLevelArticles = nil
            self.topLevelSymbols = nil
            self.documentation = nil
        }
    }
}