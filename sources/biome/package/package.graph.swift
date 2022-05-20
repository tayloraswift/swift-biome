extension Package 
{
    public 
    struct Catalog
    {
        public 
        let id:ID 
        public 
        let modules:[Module.Catalog]
        
        public 
        init(id:ID, modules:[Module.Catalog])
        {
            self.id = id 
            self.modules = modules
        }
        public 
        func graph(_version version:Version) throws -> Graph
        {
            .init(id: self.id, version: version, modules: try self.modules.map { try $0.graph() })
        }
    }
    public
    struct Graph 
    {
        let id:ID 
        let version:Version
        let modules:[Module.Graph]
        
        public 
        init(id:ID, version:Version, modules:[Module.Graph])
        {
            self.id = id 
            self.version = version
            self.modules = modules
        }
    }
}
