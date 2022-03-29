extension Documentation 
{
    @frozen public 
    struct Catalog<Location>
    {
        @frozen public 
        struct Article 
        {
            public 
            let path:[String]
            public 
            let location:Location
            
            @inlinable public
            init(path:[String], location:Location)
            {
                self.path = path 
                self.location = location
            }
        }
        @frozen public 
        struct Module 
        {
            public 
            let core:Graph
            public 
            let bystanders:[Graph]
            
            @inlinable public
            init(core:Graph, bystanders:[Graph])
            {
                self.core = core 
                self.bystanders = bystanders
            }
        }
        @frozen public 
        struct Graph 
        {
            public 
            let id:Biome.Module.ID
            public 
            let location:Location
            
            @inlinable public
            init(id:Biome.Module.ID, location:Location)
            {
                self.id = id 
                self.location = location
            }
        }
        
        public
        let id:Biome.Package.ID
        public 
        let modules:[Module],
            articles:[Article]
        
        @inlinable public
        init(id:Biome.Package.ID, articles:[Article], modules:[Module])
        {
            self.id = id 
            self.modules = modules 
            self.articles = articles
        }
    }
}
