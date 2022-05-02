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
    public 
    struct Catalog<Location>
    {
        public 
        let id:ID 
        public 
        let modules:[Module.Catalog<Location>]
    }
    
    public 
    enum Version:CustomStringConvertible, Sendable
    {
        case date(year:Int, month:Int, day:Int)
        case tag(major:Int, (minor:Int, (patch:Int, edition:Int?)?)?)
        
        public 
        var description:String 
        {
            switch self
            {
            case .date(year: let year, month: let month, day: let day):
                // not zero-padded, and probably unsuitable for generating 
                // links to toolchains.
                return "\(year)-\(month)-\(day)"
            case .tag(major: let major, nil):
                return "\(major)"
            case .tag(major: let major, (minor: let minor, nil)?):
                return "\(major).\(minor)"
            case .tag(major: let major, (minor: let minor, (patch: let patch, edition: nil)?)?):
                return "\(major).\(minor).\(patch)"
            case .tag(major: let major, (minor: let minor, (patch: let patch, edition: let edition?)?)?):
                return "\(major).\(minor).\(patch).\(edition)"
            }
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
    
    init(id:ID, graphs:[_Graph], at index:Int, in table:URI.GlobalTable) throws 
    {
        self.id = id
        self.hash = graphs.reduce(.semantic(0, 1, 2)) { $0 * $1.hash }
        self.modules = []
        
    }
}
