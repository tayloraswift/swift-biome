import SystemPackage
import Biome 
import JSON

extension Package 
{
    public 
    struct Catalog:Decodable, Sendable 
    {
        public
        enum CodingKeys:String, CodingKey 
        {
            case id             = "package" 
            case brand          = "brand"
            case modules        = "modules"
            case toolsVersion   = "catalog_tools_version"
        }
        
        public
        let id:ID
        let brand:String?
        public
        let modules:[Module.Catalog]
        let toolsVersion:Int
        
        static 
        let toolsVersion:Int = 2
        
        public 
        init(id:ID, modules:[Module.Catalog])
        {
            self.id = id 
            self.brand = nil
            self.modules = modules
            self.toolsVersion = Self.toolsVersion
        }
        
        public 
        func loadGraph(relativeTo prefix:FilePath?) throws -> Graph
        {
            // don’t check for task cancellation, because each constituent 
            // call to `Module.Catalog.load(with:)` checks for it
            guard self.toolsVersion == Self.toolsVersion
            else 
            {
                fatalError("version mismatch")
            }
            return .init(id: self.id, brand: self.brand, modules: try self.modules.map 
            {
                try $0.loadGraph(relativeTo: prefix)
            })
        }
    }
}
extension RangeReplaceableCollection where Element == Package.Catalog 
{
    @inlinable public 
    init<UTF8>(parsing json:UTF8) throws where UTF8:Collection, UTF8.Element == UInt8
    {
        let json:[JSON] = try Grammar.parse(json, as: JSON.Rule<UTF8.Index>.Array.self)
        self.init()
        self.reserveCapacity(json.count)
        for json:JSON in json
        {
            self.append(try .init(from: json))
        }
    }
}
