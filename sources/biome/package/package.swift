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
    
    public 
    struct ID:Hashable, Comparable, Sendable, Decodable, ExpressibleByStringLiteral, CustomStringConvertible
    {
        public 
        enum Kind:Hashable, Comparable, Sendable 
        {
            case swift 
            case community(String)
        }
        
        @usableFromInline
        let kind:Kind 
        
        public static 
        func < (lhs:Self, rhs:Self) -> Bool 
        {
            lhs.kind < rhs.kind
        }
        
        public static 
        let swift:Self = .init(kind: .swift)
        
        public 
        var string:String 
        {
            switch self.kind
            {
            case .swift:                return "swift-standard-library"
            case .community(let name):  return name 
            }
        }
        public 
        var description:String 
        {
            switch self.kind
            {
            case .swift:                return "(swift)"
            case .community(let name):  return name 
            }
        }
        
        @inlinable public 
        init(from decoder:any Decoder) throws 
        {
            self.init(try decoder.decode(String.self))
        }
        public 
        init(stringLiteral:String)
        {
            self.init(stringLiteral)
        }
        @inlinable public
        init<S>(_ string:S) where S:StringProtocol
        {
            switch string.lowercased() 
            {
            case    "swift-standard-library",
                    "standard-library",
                    "swift-stdlib",
                    "stdlib":
                self.init(kind: .swift)
            case let name:
                self.init(kind: .community(name))
            }
        }
        
        @inlinable public 
        init(kind:Kind)
        {
            self.kind = kind
        }
        
        @available(*, deprecated)
        var root:[UInt8]
        {
            Documentation.URI.encode(component: self.name.utf8)
        }
        
        @available(*, deprecated, renamed: "string")
        public 
        var name:String 
        {
            self.string 
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
