import SymbolGraphs

public
struct Symbol:Sendable  
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
    let route:Route
    var shape:Shape<Atom<Self>.Position>?

    var metadata:History<Metadata?>.Head?
    var declaration:History<Declaration<Atom<Symbol>>>.Head?
    var documentation:History<DocumentationExtension<Atom<Symbol>>>.Head?

    var pollen:Set<Module.Pin>
    
    init(id:ID, path:Path, kind:Kind, route:Route)
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
    var namespace:Atom<Module>
    {
        self.route.namespace
    }
    var residency:Packages.Index 
    {
        self.route.namespace.nationality
    }
    @available(*, deprecated)
    var type:Index?
    {
        switch self.community 
        {
        case .associatedtype, .callable(_):
            return self.shape?.target.atom 
        default: 
            return nil
        }
    }
    var orientation:Link.Orientation
    {
        self.community.orientation
    }
}
extension Symbol 
{
    struct Display 
    {
        let path:Path
        let community:Community

        var name:String 
        {
            self.path.last
        }
    }
    
    var display:Display 
    {
        .init(path: self.path, community: self.community)
    }
}
extension Symbol:CustomStringConvertible 
{
    public
    var description:String 
    {
        self.path.description
    }
}