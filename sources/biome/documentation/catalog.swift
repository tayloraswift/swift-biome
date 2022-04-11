extension Documentation 
{
    @frozen public 
    struct Catalog<Location>
    {
        @frozen public 
        struct ModuleDescriptor 
        {
            public 
            let core:GraphDescriptor
            public 
            let bystanders:[GraphDescriptor]
            
            @inlinable public
            init(core:GraphDescriptor, bystanders:[GraphDescriptor])
            {
                self.core = core 
                self.bystanders = bystanders
            }
        }
        @frozen public 
        struct GraphDescriptor 
        {
            public 
            let namespace:Module.ID
            public 
            let location:Location
            
            @inlinable public
            init(namespace:Module.ID, location:Location)
            {
                self.namespace = namespace 
                self.location = location
            }
        }
        @frozen public 
        struct ArticleDescriptor 
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
        
        public 
        let format:Format
        public
        let package:Package.ID
        public 
        let modules:[ModuleDescriptor],
            articles:[ArticleDescriptor]
        
        @inlinable public
        init(format:Format, package:Package.ID, modules:[ModuleDescriptor],articles:[ArticleDescriptor])
        {
            self.format = format
            self.package = package 
            self.modules = modules 
            self.articles = articles
        }
    }
}
