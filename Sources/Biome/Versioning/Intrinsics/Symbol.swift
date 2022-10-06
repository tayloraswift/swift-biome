import SymbolGraphs
import SymbolSource

public 
struct Symbol:Intrinsic, Identifiable, Sendable
{
    public 
    typealias Culture = Atom<Module>
    public 
    typealias Offset = UInt32

    public
    let id:SymbolIdentifier
    //  TODO: see if small-array optimizations here are beneficial, since this could 
    //  often be a single-element array
    let path:Path
    let kind:Kind
    let route:Route
    var scope:Scope?

    init(id:SymbolIdentifier, path:Path, kind:Kind, route:Route)
    {
        self.id = id 
        self.path = path
        self.kind = kind
        self.route = route
        self.scope = nil
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
    var display:Symbol.Display 
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