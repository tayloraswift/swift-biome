import SymbolSource
import Notebook
import URI

public 
struct Module:IntrinsicElement, Sendable
{
    public 
    typealias Culture = Packages.Index 
    public 
    typealias Offset = UInt16

    public 
    let id:ModuleIdentifier
    let culture:Atom<Self>

    // var symbols:[(range:Range<Symbol.Offset>, namespace:Atom<Module>)]
    // var articles:[Range<Article.Offset>]
    
    var metadata:OriginalHead<Metadata?>?

    var topLevelArticles:OriginalHead<Set<Atom<Article>>>?
    var topLevelSymbols:OriginalHead<Set<Atom<Symbol>>>?
    var documentation:OriginalHead<DocumentationExtension<Never>>?

    /// Indicates if this module should be served directly from the site root. 
    var isFunction:Bool

    
    init(id:ModuleIdentifier, culture:Atom<Self>)
    {
        self.id = id 
        self.culture = culture

        // self.symbols = []
        // self.articles = []

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