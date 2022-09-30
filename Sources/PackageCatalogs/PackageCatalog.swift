import SymbolSource 
import SystemPackage
import Grammar
import JSON

public 
enum PackageCatalogError:Error
{
    case toolsVersion(Int)
}

public 
struct PackageCatalog:Identifiable, Sendable 
{
    public
    let id:PackageIdentifier
    public 
    let brand:String?
    public
    let modules:[ModuleCatalog]
    public
    let snippets:[SnippetCatalog]
    
    public 
    init(id:ID, brand:String? = nil, modules:[ModuleCatalog] = [], snippets:[SnippetCatalog] = [])
    {
        self.id = id 
        self.brand = brand 
        self.modules = modules
        self.snippets = snippets
    }
    public 
    init(from json:JSON) throws 
    {
        self = try json.lint 
        {
            switch try $0.remove("catalog_tools_version", as: Int.self)
            {
            case 3:
                return .init(
                    id: try $0.remove("package", as: String.self, PackageIdentifier.init(_:)), 
                    brand: try $0.pop("brand", as: String.self), 
                    modules: try $0.remove("modules", as: [JSON].self)
                    {
                        try $0.map(ModuleCatalog.init(from:))
                    }, 
                    snippets: try $0.pop("snippets", as: [JSON].self)
                    {
                        try $0.map(SnippetCatalog.init(from:))
                    } ?? [])

            case let unsupported:
                throw PackageCatalogError.toolsVersion(unsupported)
            }
        }
    }
}
extension RangeReplaceableCollection<PackageCatalog>
{
    @inlinable public 
    init<UTF8>(parsing utf8:UTF8) throws where UTF8:Collection<UInt8>
    {
        let json:[JSON] = try JSON.Rule<UTF8.Index>.Array.parse(utf8)
        self.init()
        self.reserveCapacity(json.count)
        for json:JSON in json
        {
            self.append(try .init(from: json))
        }
    }
}
