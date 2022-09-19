import SymbolGraphs
import Notebook
import URI

public 
struct Module:Sendable
{
    public 
    typealias Culture = Package.Index 
    public 
    typealias Offset = UInt16

    enum _Culture:Hashable, Sendable 
    {
        case primary 
        case accepted(Index)
        case international(Index)
    }
    
    struct Pin:Hashable, Sendable 
    {
        var culture:Index 
        var version:Version
    }
    
    typealias Redirect = (uri:URI, version:Version)
    
    public 
    let id:ModuleIdentifier
    let index:Index 

    var symbols:[(range:Range<Symbol.Offset>, namespace:Position<Module>)]
    var articles:[Range<Article.Offset>]
    
    var metadata:History<Metadata?>.Head?

    var topLevelArticles:History<Set<Position<Article>>>.Head?
    var topLevelSymbols:History<Set<Position<Symbol>>>.Head?
    var documentation:History<DocumentationExtension<Never>>.Head?
    
    var redirect:(module:Redirect?, articles:Redirect?)

    
    init(id:ID, index:Index)
    {
        self.id = id 
        self.index = index
        self.redirect = (nil, nil)

        self.symbols = []
        self.articles = []

        self.metadata = nil
        self.topLevelArticles = nil 
        self.topLevelSymbols = nil 
        self.documentation = nil
    }
    
    /// this module’s exact identifier string, e.g. '_Concurrency'
    var name:String 
    {
        self.id.string 
    }
    /// this module’s identifier string with leading underscores removed, e.g. 'Concurrency'
    var title:Substring 
    {
        self.id.title
    }
    var path:Path 
    {
        .init(last: self.id.string)
    }
    var nationality:Package.Index 
    {
        self.index.nationality
    }
    var fragments:[Notebook<Highlight, Never>.Fragment] 
    {
        [
            .init("import",     color: .keywordText),
            .init(" ",          color: .text),
            .init(self.name,    color: .identifier),
        ]
    }
}