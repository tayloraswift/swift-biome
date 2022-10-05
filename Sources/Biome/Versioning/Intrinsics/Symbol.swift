import SymbolGraphs
import SymbolSource

public
struct Symbol:IntrinsicElement, Sendable  
{
    public 
    typealias Culture = Atom<Module>
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
    var scope:Scope?

    var metadata:OriginalHead<Metadata?>?
    var declaration:OriginalHead<Declaration<Atom<Symbol>>>?
    var documentation:OriginalHead<DocumentationExtension<Atom<Symbol>>>?

    init(id:SymbolIdentifier, path:Path, kind:Kind, route:Route)
    {
        self.id = id 
        self.path = path
        self.kind = kind
        self.route = route
        self.scope = nil
        
        self.metadata = nil 
        self.declaration = nil
        self.documentation = nil
    }

    var shape:Shape
    {
        self.kind.shape 
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
    var orientation:_SymbolLink.Orientation
    {
        self.shape.orientation
    }
}
extension Symbol 
{
    struct Display 
    {
        let path:Path
        let shape:Shape

        var name:String 
        {
            self.path.last
        }
    }
    
    var display:Display 
    {
        .init(path: self.path, shape: self.shape)
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