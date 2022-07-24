public
struct PackageGraph:Identifiable, Sendable
{
    public 
    let id:PackageIdentifier 
    public 
    var brand:String?
    public 
    var modules:[SymbolGraph]
    
    public 
    init(id:ID, brand:String? = nil, modules:[SymbolGraph])
    {
        self.id = id 
        self.brand = brand
        self.modules = modules
    }
}
