public 
struct Module:Identifiable, Sendable
{
    /// A globally-unique index referencing a module. 
    struct Index 
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
    struct ID:Hashable, Sendable, Decodable, ExpressibleByStringLiteral, CustomStringConvertible
    {
        public
        let string:String 
        
        public 
        var description:String 
        {
            self.string 
        }
        
        // lowercased. it is possible for lhs == rhs even if lhs.string != rhs.string
        var value:String 
        {
            self.title.lowercased()
        }
        
        public static 
        func == (lhs:Self, rhs:Self) -> Bool 
        {
            lhs.value == rhs.value
        }
        public 
        func hash(into hasher:inout Hasher) 
        {
            self.value.hash(into: &hasher)
        }
        
        @available(*, deprecated, renamed: "value")
        var trunk:[UInt8]
        {
            Documentation.URI.encode(component: self.title.utf8)
        }
        
        @inlinable public 
        init(from decoder:any Decoder) throws 
        {
            self.init(try decoder.decode(String.self))
        }
        public
        init(stringLiteral:String)
        {
            self.string = stringLiteral
        }
        @inlinable public
        init<S>(_ string:S) where S:StringProtocol 
        {
            self.string = .init(string)
        }
        var title:Substring 
        {
            self.string.drop { $0 == "_" } 
        }
    }
    
    typealias Colony = (module:Index, symbols:Symbol.IndexRange)
        
    public 
    let id:ID
    
    /// the complete list of symbols vended by this module. the ranges are *contiguous*.
    /// ``core`` contains the symbols with the lowest addresses.
    let core:Symbol.IndexRange
    let colonies:[Colony]
    /// the symbols scoped to this module’s top-level namespace. every index in 
    /// this array falls within the range of ``core``, since it is not possible 
    /// to extend the top-level namespace of a module.
    let toplevel:[Symbol.Index]
    /// the list of modules this module depends on, grouped by package. 
    let dependencies:[[Module.Index]]
    
    var symbols:Symbol.IndexRange
    {
        self.colonies.last?.symbols.bits.upperBound.map { self.core.lowerBound ..< $0 } ?? self.core
    }
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
    init(id:ID, 
        core:Symbol.IndexRange, 
        colonies:[Colony], 
        toplevel:[Symbol.Index], 
        dependencies:[[Module.Index]])
    {
        self.id = id 
        self.core = core 
        self.colonies = colonies 
        self.toplevel = toplevel
        self.dependencies = dependencies
    }
}
