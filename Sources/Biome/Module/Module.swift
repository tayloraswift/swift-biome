import Notebook

public 
struct Module:Identifiable, Sendable
{
    /// A globally-unique index referencing a module. 
    @frozen public
    struct Index:CulturalIndex, Hashable, Sendable 
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
        @Keyframe<Set<Index>>.Head
        var dependencies:Keyframe<Set<Index>>.Buffer.Index?
        @Keyframe<Set<Symbol.Index>>.Head
        var toplevel:Keyframe<Set<Symbol.Index>>.Buffer.Index?
        @Keyframe<Set<Article.Index>>.Head
        var guides:Keyframe<Set<Article.Index>>.Buffer.Index?
        @Keyframe<Article.Template<Ecosystem.Link>>.Head
        var template:Keyframe<Article.Template<Ecosystem.Link>>.Buffer.Index?
        
        init() 
        {
            self._dependencies = .init()
            self._toplevel = .init()
            self._guides = .init()
            self._template = .init()
        }
    }
    
    public 
    let id:ID
    let index:Index 
    
    var symbols:[Symbol.ColonialRange]
    var articles:[Range<Article.Index>]
    
    var heads:Heads
    
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
