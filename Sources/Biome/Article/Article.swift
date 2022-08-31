import struct SymbolGraphs.Path
import HTML

@usableFromInline 
struct Article:BranchElement, Sendable
{
    @usableFromInline 
    typealias Culture = Module.Index 
    @usableFromInline 
    typealias Offset = UInt32 

    struct Heads 
    {
        @History<Excerpt>.Branch.Optional 
        var excerpt:History<Excerpt>.Branch.Head?
        @History<DocumentationNode>.Branch.Optional 
        var documentation:History<DocumentationNode>.Branch.Head?
        
        init() 
        {
            self._excerpt = .init()
            self._documentation = .init()
        }
    }
    
    @usableFromInline 
    struct ID:Hashable, Sendable 
    {
        let key:Route.Key 
        
        init(_ key:Route.Key)
        {
            self.key = key
        }
    }
    
    @usableFromInline 
    let id:ID 
    let path:Path
    var name:String 
    {
        self.path.last
    }
    var heads:Heads

    var route:Route.Key
    {
        self.id.key
    }
    
    init(id:ID, path:Path)
    {
        self.id = id
        self.path = path
        self.heads = .init()
    }
}
