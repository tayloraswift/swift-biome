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
        let route:Route.Key
        
        init(_ route:Route.Key)
        {
            self.route = route
        }
        init(_ culture:Branch.Position<Module>, _ stem:Route.Stem, _ leaf:Route.Stem)
        {
            self.init(.init(culture, stem, .init(leaf, orientation: .straight)))
        }
    }
    
    @usableFromInline 
    let id:ID 
    
    var heads:Heads

    var path:Path
    var name:String 
    {
        self.path.last
    }
    var route:Route.Key 
    {
        self.id.route
    }
    
    init(id:ID, path:Path)
    {
        self.id = id
        self.path = path
        self.heads = .init()
    }
}
