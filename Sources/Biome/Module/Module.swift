import SymbolGraphs
import Notebook
import URI

public 
struct Module:BranchElement, Sendable
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
    
    public 
    struct Heads:Sendable 
    {
        var symbols:[Colony]
        var articles:[Range<Article.Offset>]
        
        @History<Set<Index>>.Branch.Optional 
        var dependencies:History<Set<Index>>.Branch.Head?
        @History<Set<Symbol.Index>>.Branch.Optional 
        var toplevel:History<Set<Symbol.Index>>.Branch.Head?
        @History<Set<Article.Index>>.Branch.Optional 
        var guides:History<Set<Article.Index>>.Branch.Head?
        @History<DocumentationNode>.Branch.Optional 
        var documentation:History<DocumentationNode>.Branch.Head?
        
        init() 
        {
            self.symbols = []
            self.articles = []
            
            self._dependencies = .init()
            self._toplevel = .init()
            self._guides = .init()
            self._documentation = .init()
        }
    }
    
    typealias Redirect = (uri:URI, version:Version)
    
    public 
    let id:ModuleIdentifier
    let index:Index 

    var symbols:[Colony]
    var articles:[Range<Article.Offset>]
    var metadata:Branch.Head<Metadata>?
    
    var heads:Heads
    var redirect:(module:Redirect?, articles:Redirect?)
    
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
    
    init(id:ID, index:Index)
    {
        self.id = id 
        self.index = index
        self.heads = .init()
        self.redirect = (nil, nil)

        self.symbols = []
        self.articles = []
        self.metadata = nil
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

extension Module 
{
    public 
    struct Divergence:Voidable, Sendable 
    {
        var symbols:[Colony]
        var articles:[Range<Article.Offset>]

        var metadata:Branch.Divergence<Metadata>?

        var isEmpty:Bool 
        {
            if  self.symbols.isEmpty,
                self.articles.isEmpty,
                case nil = self.metadata
            {
                return true 
            }
            else 
            {
                return false
            }
        }

        init() 
        {
            self.symbols = []
            self.articles = []
            self.metadata = nil
        }
    }
}