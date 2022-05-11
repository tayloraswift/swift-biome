import Resource

extension Package 
{
    public 
    struct Catalog<Location>
    {
        public 
        let id:ID 
        public 
        let modules:[Module.Catalog<Location>]
        
        public 
        init(id:ID, modules:[Module.Catalog<Location>])
        {
            self.id = id 
            self.modules = modules
        }
        func load(with loader:(Location, Resource.Text) async throws -> Resource) 
            async throws -> [Module.Graph]
        {
            var graphs:[Module.Graph] = []
            for module:Module.Catalog<Location> in self.modules 
            {
                graphs.append(try await module.load(with: loader))
            }
            return graphs
        }
    }
}
