import SymbolSource

public
struct Article:Intrinsic, Sendable
{
    public
    typealias Culture = Atom<Module>
    public
    typealias Offset = UInt32 

    public
    struct ID:Hashable, Sendable 
    {
        let route:Route
        
        init(_ route:Route)
        {
            self.route = route
        }
        init(_ culture:Atom<Module>, _ stem:Route.Stem, _ leaf:Route.Stem)
        {
            self.init(.init(culture, stem, .init(leaf, orientation: .straight)))
        }
    }

    public
    let id:ID 
    var path:Path

    init(id:ID, path:Path)
    {
        self.id = id
        self.path = path
    }
}
extension Article
{
    var name:String 
    {
        self.path.last
    }
    var route:Route 
    {
        self.id.route
    }
}
