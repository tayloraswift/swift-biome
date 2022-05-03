import Resource

public 
struct Package:Sendable, Identifiable
{
    /// A globally-unique index referencing a package. 
    struct Index 
    {
        let bits:UInt16
        
        var offset:Int 
        {
            .init(self.bits)
        }
        init(offset:Int)
        {
            self.bits = .init(offset)
        }
    }

    /* struct Dependency
    {
        let package:Int 
        let imports:[Int]
    }  */
    
    public 
    let id:ID
    private 
    var hash:Resource.Version?
    private(set)
    var modules:[Module], 
        symbols:[Symbol]
    
    private(set)
    var indices:
    (
        modules:[Module.ID: Module.Index],
        symbols:[Symbol.ID: Symbol.Index]
    )
    
    var name:String 
    {
        self.id.name
    }
    
    init(id:ID, indices:
        (
            modules:[Module.ID: Module.Index],
            symbols:[Symbol.ID: Symbol.Index]
        ), 
        modules:[Module], 
        symbols:[Symbol], 
        hash:Resource.Version?)
    {
        self.id = id
        self.hash = hash
        self.indices = indices
        self.modules = modules
        self.symbols = symbols
    }
}
