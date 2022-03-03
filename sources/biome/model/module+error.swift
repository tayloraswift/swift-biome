extension Biome 
{
    public 
    struct GraphLoadingError:Error 
    {
        let underlying:Error
        let module:Module.ID, 
            bystander:Module.ID?
        
        init(_ underlying:Error, module:Module.ID, bystander:Module.ID?)
        {
            self.underlying = underlying
            self.module     = module
            self.bystander  = bystander
        }
    }
    public 
    enum ModuleIdentifierError:Error 
    {
        case mismatch(decoded:Module.ID)
        case duplicate(module:Module.ID)
        case undefined(module:Module.ID)
    }
}
