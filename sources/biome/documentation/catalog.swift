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
            @frozen public 
            struct Graph 
            {
                public 
                let namespace:Biome.Module.ID
                public 
                let location:Location
                
                @inlinable public
                init(namespace:Biome.Module.ID, location:Location)
                {
                    self.namespace = namespace 
                    self.location = location
                }
            }
            
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
        
        public 
        let format:Format
        public
        let package:Biome.Package.ID
        public 
        let modules:[Module],
            articles:[Article]
        
        @inlinable public
        init(format:Format, package:Biome.Package.ID, articles:[Article], modules:[Module])
        {
            self.format = format
            self.package = package 
            self.modules = modules 
            self.articles = articles
        }
    }
}
