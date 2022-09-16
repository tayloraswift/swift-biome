import SymbolGraphs

public
struct Symbol:Sendable, CustomStringConvertible  
{
    public 
    typealias Culture = Module.Index 
    public 
    typealias Offset = UInt32
    
    // these stored properties are constant with respect to symbol identity. 
    public
    let id:SymbolIdentifier
    //  TODO: see if small-array optimizations here are beneficial, since this could 
    //  often be a single-element array
    let path:Path
    let kind:Kind
    let route:Route.Key
    var shape:Shape<Tree.Position<Self>>?

    var metadata:_History<Metadata?>.Head?
    var declaration:_History<Declaration<Branch.Position<Symbol>>>.Head?
    var documentation:_History<DocumentationExtension<Branch.Position<Symbol>>>.Head?

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
    var type:Index?
    {
        switch self.community 
        {
        case .associatedtype, .callable(_):
            return self.shape?.target.contemporary 
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
        
        self.metadata = nil 
        self.declaration = nil
        self.documentation = nil
        
        self.pollen = []
    }
}
