import Notebook

public 
struct Module:Identifiable, Sendable
{
    /// A globally-unique index referencing a module. 
    struct Index:CulturalIndex, Hashable, Sendable 
    {
        let package:Package.Index 
        let bits:UInt16
        
        var offset:Int 
        {
            .init(self.bits)
        }
        init(_ package:Package.Index, offset:Int)
        {
            self.package = package 
            self.bits = .init(offset)
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
        @Keyframe<Article.Template<Ecosystem.Link>>.Head
        var template:Keyframe<Article.Template<Ecosystem.Link>>.Buffer.Index?
        
        init() 
        {
            self._dependencies = .init()
            self._toplevel = .init()
            self._template = .init()
        }
    }
    
    public 
    let id:ID
    let index:Index 
    
    var matrix:[Symbol.ColonialRange]
    var toplevel:[Symbol.Index]
    
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
        self.matrix = []
        self.toplevel = []
        
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
