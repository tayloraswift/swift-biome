extension Biome 
{    
    public 
    struct Module:Identifiable, Sendable
    {
        public 
        let id:ID
        public 
        let package:Int
        
        let symbols:(core:Range<Int>, extensions:[(bystander:Int, symbols:Range<Int>)])
        var toplevel:[Int]
        
        var title:String 
        {
            .init(self.id.title)
        }
        var allSymbols:FlattenSequence<[Range<Int>]>
        {
            ([self.symbols.core] + self.symbols.extensions.map(\.symbols)).joined()
        }
        
        init(id:ID, package:Int, core:Range<Int>, extensions:[(bystander:Int, symbols:Range<Int>)])
        {
            self.id         = id 
            self.package    = package
            self.symbols    = (core, extensions)
            self.toplevel   = []
        }
    }
    
    /* public 
    struct Graph:Hashable, Sendable 
    {
        var module:Module.ID, 
            bystander:Module.ID?
        
        var namespace:Module.ID 
        {
            self.bystander ?? self.module 
        }
    } */
}
