import SymbolGraphs
import Notebook
import URI

public 
struct Module:Sendable
{
    public 
    typealias Culture = Packages.Index 
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
    
    public 
    let id:ModuleIdentifier
    let culture:Atom<Self>


    @available(*, deprecated, renamed: "culture")
    var index:Atom<Self> 
    {
        self.culture
    }

    var symbols:[(range:Range<Symbol.Offset>, namespace:Atom<Module>)]
    var articles:[Range<Article.Offset>]
    
    var metadata:History<Metadata?>.Head?

    var topLevelArticles:History<Set<Atom<Article>>>.Head?
    var topLevelSymbols:History<Set<Atom<Symbol>>>.Head?
    var documentation:History<DocumentationExtension<Never>>.Head?

    /// Indicates if this module should be served directly from the site root. 
    var isFunction:Bool
    
    typealias Redirect = (uri:URI, version:Version)
    var redirect:(module:Redirect?, articles:Redirect?)

    
    init(id:ID, culture:Atom<Self>)
    {
        self.id = id 
        self.culture = culture
        self.redirect = (nil, nil)

        self.symbols = []
        self.articles = []

        self.metadata = nil
        self.topLevelArticles = nil 
        self.topLevelSymbols = nil 
        self.documentation = nil

        self.isFunction = false
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
    var nationality:Packages.Index 
    {
        self.culture.nationality
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