import SymbolSource
import Notebook
import URI

public 
struct Module:Sendable
{
    public 
    typealias Culture = Packages.Index 
    public 
    typealias Offset = UInt16

    public 
    let id:ModuleIdentifier
    let culture:Atom<Self>

    var symbols:[(range:Range<Symbol.Offset>, namespace:Atom<Module>)]
    var articles:[Range<Article.Offset>]
    
    var metadata:History<Metadata?>.Head?

    var topLevelArticles:History<Set<Atom<Article>>>.Head?
    var topLevelSymbols:History<Set<Atom<Symbol>>>.Head?
    var documentation:History<DocumentationExtension<Never>>.Head?

    /// Indicates if this module should be served directly from the site root. 
    var isFunction:Bool

    
    init(id:ID, culture:Atom<Self>)
    {
        self.id = id 
        self.culture = culture

        self.symbols = []
        self.articles = []

        self.metadata = nil
        self.topLevelArticles = nil 
        self.topLevelSymbols = nil 
        self.documentation = nil

        self.isFunction = false
    }
    
    var path:Path 
    {
        .init(last: self.id.string)
    }
    var nationality:Packages.Index 
    {
        self.culture.nationality
    }
}