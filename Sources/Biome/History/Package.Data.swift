extension Package 
{
    enum DataLoadingError:Error 
    {
        case topLevelArticles
        case topLevelSymbols
        case declaration
    }
    
    // struct Data 
    // {
    //     var topLevelArticles:History<Set<Atom<Article>>>
    //     var topLevelSymbols:History<Set<Atom<Symbol>>>
    //     private(set)
    //     var declarations:History<Declaration<Atom<Symbol>>>

    //     var standaloneDocumentation:History<DocumentationExtension<Never>>
    //     var symbolDocumentation:History<DocumentationExtension<Atom<Symbol>>>

    //     init() 
    //     {
    //         self.topLevelArticles = .init()
    //         self.topLevelSymbols = .init()
    //         self.declarations = .init()

    //         self.standaloneDocumentation = .init()
    //         self.symbolDocumentation = .init()
    //     }
    // }
}