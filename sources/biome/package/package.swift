import Resource

/// # lexicon 
/// 
/// - **citizenship**: the package or module that originally declared a witness.
///     citizenship can be package-level or module-level, but we are 
///     usually interested in package citizenship. 
/// 
/// - **crossing**: a protocol that a coyote uses to smuggle a member 
///     into a nation. 
/// 
/// - **coyote**: a perpetrator that states that a symbol in a foreign 
///     package has a member. 
/// 
/// - **feature**: an inherited symbol. every feature maps to a witness, 
///     but multiple feature can map to the same witness.
///     features are always undocumented, and don’t “exist” on their own.
/// 
/// - **namespace**: a module name. it is not the same thing as the module  
///     itself, but every module creates a namespace.
/// 
/// - **nation**: a package name. it is not the same thing as the package 
///     itself, but every package creates a nation.
/// 
/// - **opinion**: an extrinsic relationship referring to a symbol 
///     in a foreign package. for example, a perpetrator module may 
///     state that a type in a foreign package conforms to a protocol in 
///     another foreign package. 
/// 
/// - **perpetrator**: a module that states an opinion about a symbol 
///     in another package.
/// 
/// - **victim**: a type that inherits a feature.
///
/// - **witness**: a concrete declaration. it is conceptually unique and 
///     canonical.
public 
struct Package:Identifiable, Sendable
{
    /// A globally-unique index referencing a package. 
    struct Index:Hashable, Sendable 
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
    private 
    var table:Table
    
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
        table:Table,
        hash:Resource.Version?)
    {
        self.id = id
        self.hash = hash
        self.indices = indices
        self.modules = modules
        self.symbols = symbols
        self.table = table
    }
}
