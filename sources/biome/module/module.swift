public 
struct Module:Identifiable, Sendable
{
    /// A globally-unique index referencing a module. 
    struct Index:Hashable, Sendable 
    {
        let package:Package.Index 
        let bits:UInt16
        
        var offset:Int 
        {
            .init(self.bits)
        }
        init(package:Int, offset:Int)
        {
            self.init(Package.Index.init(offset: package), offset: offset)
        }
        init(_ package:Package.Index, offset:Int)
        {
            self.package = package 
            self.bits = .init(offset)
        }
    }
    
    public 
    let id:ID
    let index:Index 
    
    var matrix:[Symbol.ColonialRange]
    /// the complete list of symbols vended by this module. the ranges are *contiguous*.
    /// ``core`` contains the symbols with the lowest addresses.
    // let core:Symbol.IndexRange
    // let colonies:[Symbol.ColonialRange]
    /// the symbols scoped to this module’s top-level namespace. every index in 
    /// this array falls within the range of ``core``, since it is not possible 
    /// to extend the top-level namespace of a module.
    var toplevel:[Symbol.Index]
    /// the list of modules this module depends on, grouped by package. 
    // let dependencies:[[Module.Index]]
    
    /// this module’s exact identifier string, e.g. '_Concurrency'
    var name:String 
    {
        self.id.string 
    }
    /// this module’s identifier string with leading underscores removed, e.g. 'Concurrency'
    var title:Substring 
    {
        self.id.title
    }
    var index:Index 
    {
        // since ``core`` stores a symbol index, we can get the module index 
        // for free!
        self.core.module
    }
    
    // only the core subgraph can contain top-level symbols.
    init(id:ID)
    {
        self.id = id 
        self.matrix = []
        self.toplevel = []
    }
    
    /// all symbols declared by this module, including symbols in other namespaces 
    /* var symbols:Symbol.IndexRange
    {
        if let last:Symbol.ColonialRange = self.colonies.last 
        {
            return .init(self.core.module, bits: self.core.bits.lowerBound ..< last.bits.upperBound)
        }
        else 
        {
            return self.core 
        }
    } */
}
