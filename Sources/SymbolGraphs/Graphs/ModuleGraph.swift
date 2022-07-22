public 
struct ModuleGraph:Identifiable, Sendable 
{
    public 
    typealias Extension = (name:String, source:String)
    
    @frozen public 
    struct Dependency:Decodable, Sendable
    {
        public
        var package:PackageIdentifier
        public
        var modules:[ModuleIdentifier]
        
        public 
        init(package:PackageIdentifier, modules:[ModuleIdentifier])
        {
            self.package = package 
            self.modules = modules 
        }
    }

    public 
    var id:ModuleIdentifier 
    {
        self.core.namespace
    }
    public 
    let core:SymbolGraph,
        colonies:[SymbolGraph], 
        extensions:[Extension], 
        dependencies:[Dependency]
    
    public
    var edges:[[Edge]] 
    {
        [self.core.edges] + self.colonies.map(\.edges)
    }
    
    public 
    init(id:ID, 
        extensions:[Extension], 
        dependencies:[Dependency] = [])
    {
        self.init(core: .init(namespace: id), extensions: extensions, 
            dependencies: dependencies)
    }
    public 
    init(core:SymbolGraph, 
        colonies:[SymbolGraph] = [], 
        extensions:[Extension] = [], 
        dependencies:[Dependency] = []) 
    {
        self.core = core 
        self.colonies = colonies 
        self.extensions = extensions 
        self.dependencies = dependencies
    }
}