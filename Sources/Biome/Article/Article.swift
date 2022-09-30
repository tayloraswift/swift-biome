import SymbolSource
import HTML

@usableFromInline 
struct Article:Sendable
{
    @usableFromInline 
    typealias Culture = Atom<Module>
    @usableFromInline 
    typealias Offset = UInt32 

    @usableFromInline 
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

    @usableFromInline 
    let id:ID 
    var path:Path

    var metadata:History<Metadata?>.Head?
    var documentation:History<DocumentationExtension<Never>>.Head?
    
    init(id:ID, path:Path)
    {
        self.id = id
        self.path = path

        self.metadata = nil 
        self.documentation = nil
    }

    var name:String 
    {
        self.path.last
    }
    var route:Route 
    {
        self.id.route
    }
}
