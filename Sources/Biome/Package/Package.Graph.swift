extension Package 
{
    public
    struct Graph:Sendable
    {
        let id:ID 
        let brand:String?
        let modules:[Module.Graph]
        
        public 
        init(id:ID, brand:String? = nil, modules:[Module.Graph])
        {
            self.id = id 
            self.brand = brand
            self.modules = modules
        }
    }
}
