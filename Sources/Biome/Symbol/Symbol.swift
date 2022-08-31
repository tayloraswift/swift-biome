import SymbolGraphs

public
struct Symbol:BranchElement, Sendable, CustomStringConvertible  
{
    public 
    typealias Culture = Module.Index 
    public 
    typealias Offset = UInt32 
    
    struct Heads 
    {
        @History<DocumentationNode>.Branch.Optional
        var documentation:History<DocumentationNode>.Branch.Head?
        @History<Declaration<Index>>.Branch.Optional
        var declaration:History<Declaration<Index>>.Branch.Head?
        @History<Predicates>.Branch.Optional
        var facts:History<Predicates>.Branch.Head?
        
        init() 
        {
            self._documentation = .init()
            self._declaration = .init()
            self._facts = .init()
        }
    }
    
    struct Nest 
    {
        let namespace:Module.Index 
        let prefix:[String]
    }
    
    // these stored properties are constant with respect to symbol identity. 
    public
    let id:SymbolIdentifier
    //  TODO: see if small-array optimizations here are beneficial, since this could 
    //  often be a single-element array
    let path:Path
    let kind:Kind
    let route:Route.Key
    var shape:Shape<Index>?
    var heads:Heads
    var pollen:Set<Module.Pin>
    
    var community:Community 
    {
        self.kind.community 
    } 
    var name:String 
    {
        self.path.last
    }
    //  this is only the same as the perpetrator if this symbol is part of its 
    //  core symbol graph.
    var namespace:Module.Index 
    {
        self.route.namespace
    }
    var nest:Nest?
    {
        self.path.prefix.isEmpty ? 
            nil : .init(namespace: self.namespace, prefix: self.path.prefix)
    }
    var type:Index?
    {
        switch self.community 
        {
        case .associatedtype, .callable(_):
            return self.shape?.target 
        default: 
            return nil
        }
    }
    var orientation:Link.Orientation
    {
        self.community.orientation
    }
    public
    var description:String 
    {
        self.path.description
    }
    
    init(id:ID, path:Path, kind:Kind, route:Route.Key)
    {
        self.id = id 
        self.path = path
        self.kind = kind
        self.route = route
        self.shape = nil
        
        self.heads = .init()
        self.pollen = []
    }
}
