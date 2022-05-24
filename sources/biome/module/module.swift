public 
struct Module:Identifiable, Sendable
{
    /// A globally-unique index referencing a module. 
    struct Index:CulturalIndex, Hashable, Sendable 
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
    
    struct Dependencies:Equatable, Sendable 
    {
        // must *not* include current package. 
        // (this is why it cannot be a computed property)
        let packages:Set<Package.Index>
        var modules:Set<Index>
    }
    
    struct Heads 
    {
        @Keyframe<Dependencies>.Head
        var dependencies:Keyframe<Dependencies>.Buffer.Index?
        
        init() 
        {
            self._dependencies = .init()
        }
    }
    
    public 
    let id:ID
    let index:Index 
    
    var matrix:[Symbol.ColonialRange]
    var toplevel:[Symbol.Index]
    
    var heads:Heads
    
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
    
    init(id:ID, index:Index)
    {
        self.id = id 
        self.index = index
        self.matrix = []
        self.toplevel = []
        
        self.heads = .init()
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
