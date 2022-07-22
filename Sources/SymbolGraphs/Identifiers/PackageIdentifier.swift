@frozen public 
struct PackageIdentifier:Hashable, Sendable
{
    @frozen public 
    enum Kind:Hashable, Comparable, Sendable 
    {
        case swift 
        case core
        case community(String)
    }
    
    public static 
    let swift:Self = .init(kind: .swift)
    public static 
    let core:Self = .init(kind: .core)
    
    public
    let kind:Kind 
    
    @inlinable public 
    init(kind:Kind)
    {
        self.kind = kind
    }
}
extension PackageIdentifier:Comparable 
{
    @inlinable public static 
    func < (lhs:Self, rhs:Self) -> Bool 
    {
        lhs.kind < rhs.kind
    }
}
extension PackageIdentifier:ExpressibleByStringLiteral 
{
    @inlinable public 
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
        case    "swift-core-libraries":
            self.init(kind: .core)
        case let name:
            self.init(kind: .community(name))
        }
    }
}
extension PackageIdentifier:LosslessStringConvertible 
{
    @inlinable public 
    var string:String 
    {
        switch self.kind
        {
        case .swift:                return "swift-standard-library"
        case .core:                 return "swift-core-libraries"
        case .community(let name):  return name 
        }
    }
    @inlinable public 
    var description:String 
    {
        self.string
    }
}
extension PackageIdentifier:Decodable 
{
    @inlinable public 
    init(from decoder:any Decoder) throws 
    {
        self.init(try decoder.singleValueContainer().decode(String.self))
    }
}