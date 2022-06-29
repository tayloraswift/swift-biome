extension Package 
{
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
