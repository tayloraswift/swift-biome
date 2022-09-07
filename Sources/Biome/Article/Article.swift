import struct SymbolGraphs.Path
import HTML

@usableFromInline 
struct Article:BranchElement, Sendable
{
    @usableFromInline 
    typealias Culture = Module.Index 
    @usableFromInline 
    typealias Offset = UInt32 
    @usableFromInline 
    struct Divergence:Voidable, Sendable
    {
    }

    @usableFromInline 
    struct Heads:Sendable
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
        let namespace:Module.ID 
        let path:Path 
        
        init(_ namespace:Module.ID, _ path:Path)
        {
            self.namespace = namespace 
            self.path = path
        }
    }
    
    @usableFromInline 
    let id:ID 
    let route:Route.Key
    var heads:Heads

    var path:Path
    {
        self.id.path
    }
    var name:String 
    {
        self.path.last
    }
    
    init(id:ID, route:Route.Key)
    {
        self.id = id
        self.route = route
        self.heads = .init()
    }
}
