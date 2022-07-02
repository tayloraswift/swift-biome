import VersionControl
import Biome 
import JSON

extension Package 
{
    public 
    struct Descriptor:Decodable, Sendable 
    {
        public
        enum CodingKeys:String, CodingKey 
        {
            case id             = "package" 
            case modules        = "modules"
            case toolsVersion   = "catalog_tools_version"
        }
        
        public
        let id:ID
        public
        let modules:[Module.Descriptor]
        let toolsVersion:Int
        
        static 
        let toolsVersion:Int = 2
        
        public 
        init(id:ID, modules:[Module.Descriptor])
        {
            self.id = id 
            self.modules = modules
            self.toolsVersion = Self.toolsVersion
        }
        
        public 
        func load(with controller:VersionController?) 
            async throws -> Package.Catalog
        {
            // don’t check for task cancellation, because each constituent 
            // call to `Module.Descriptor.load(with:)` checks for it
            guard self.toolsVersion == Self.toolsVersion
            else 
            {
                fatalError("version mismatch")
            }
            var modules:[Module.Catalog] = []
            for module:Module.Descriptor in self.modules 
            {
                modules.append(try await module.load(with: controller))
            }
            return .init(id: self.id, modules: modules)
        }
    }
    
    public static 
    func descriptors(parsing file:[UInt8]) throws -> [Descriptor]
    {
        try Grammar.parse(file, as: JSON.Rule<Array<UInt8>.Index>.Array.self).map(Descriptor.init(from:))
    }
}
