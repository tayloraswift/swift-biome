public
struct PackageGraph:Identifiable, Sendable
{
    public 
    let id:PackageIdentifier 
    public 
    var brand:String?
    public 
    var modules:[ModuleGraph]
    
    public 
    init(id:ID, brand:String? = nil, modules:[ModuleGraph])
    {
        self.id = id 
        self.brand = brand
        self.modules = modules
    }
}
