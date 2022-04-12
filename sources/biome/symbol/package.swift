import Resource

public 
struct Package:Sendable, Identifiable
{
    @frozen public 
    enum ID:Hashable, Comparable, Sendable  
    {
        case swift 
        case community(String)
        
        var root:[UInt8]
        {
            Documentation.URI.encode(component: self.name.utf8)
        }
        
        public 
        var name:String 
        {
            switch self 
            {
            case .swift:                return "swift-standard-library"
            case .community(let name):  return name 
            }
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
