import Resource

public 
struct Package:Sendable, Identifiable
{
    public 
    struct ID:Hashable, Comparable, Sendable, ExpressibleByStringLiteral
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
    
    public 
    let id:ID
    let modules:Range<Int>, 
        hash:Resource.Version?
    
    var name:String 
    {
        self.id.name
    }
}
