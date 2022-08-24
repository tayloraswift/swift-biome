import SymbolGraphs
import Notebook
import URI

public 
struct Module:Identifiable, Sendable
{
    /// A globally-unique index referencing a module. 
    @frozen public
    struct Index:CulturalIndex, Sendable 
    {
        public 
        let package:Package.Index 
        public 
        let bits:UInt16
        
        @inlinable public 
        var culture:Package.Index
        {
            self.package
        }
        @inlinable public 
        init(_ package:Package.Index, bits:UInt16)
        {
            self.package = package
            self.bits = bits
        } 
    }
    
    enum Culture:Hashable, Sendable 
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
    
    struct Heads 
    {
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
    
    var symbols:[Symbol.ColonialRange]
    var articles:[Range<Article.Index>]
    
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
        self.symbols = []
        self.articles = []
        
        self.heads = .init()
        self.redirect = (nil, nil)
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
