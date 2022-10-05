import Sediment
import SymbolGraphs

extension History
{
    enum MetadataLoadingError:Error 
    {
        case article
        case module
        case symbol
        case foreign
    }
    enum DataLoadingError:Error 
    {
        case topLevelArticles
        case topLevelSymbols
        case declaration
    }
}
struct History
{
    struct Metadata
    {
        var modules:Sediment<Version.Revision, Module.Metadata?>
        var articles:Sediment<Version.Revision, Article.Metadata?>
        var symbols:Sediment<Version.Revision, Symbol.Metadata?>
        var overlays:Sediment<Version.Revision, Overlay.Metadata?>

        init()
        {
            self.modules = .init()
            self.articles = .init()
            self.symbols = .init()
            self.overlays = .init()
        }
    }
    struct Data
    {
        var topLevelArticles:Sediment<Version.Revision, Set<Atom<Article>>>
        var topLevelSymbols:Sediment<Version.Revision, Set<Atom<Symbol>>>
        var declarations:Sediment<Version.Revision, Declaration<Atom<Symbol>>>

        var standaloneDocumentation:Sediment<Version.Revision, DocumentationExtension<Never>>
        var cascadingDocumentation:Sediment<Version.Revision, DocumentationExtension<Atom<Symbol>>>
        init()
        {
            self.topLevelArticles = .init()
            self.topLevelSymbols = .init()
            self.declarations = .init()

            self.standaloneDocumentation = .init()
            self.cascadingDocumentation = .init()
        }
    }

    var metadata:Metadata
    var data:Data

    init()
    {
        self.metadata = .init()
        self.data = .init()
    }
}