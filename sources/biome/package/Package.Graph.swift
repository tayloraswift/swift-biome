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
        func graph() throws -> Graph
        {
            .init(id: self.id, modules: try self.modules.map { try $0.graph() })
        }
    }
    public
    struct Graph 
    {
        let id:ID 
        let modules:[Module.Graph]
        
        public 
        init(id:ID, modules:[Module.Graph])
        {
            self.id = id 
            self.modules = modules
        }
    }
}
