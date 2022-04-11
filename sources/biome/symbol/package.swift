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
    struct Version:CustomStringConvertible, Sendable
    {
        var major:Int 
        var minor:Int?
        var patch:Int?
        
        public 
        var description:String 
        {
            switch (self.minor, self.patch)
            {
            case (nil       , nil):         return "\(self.major)"
            case (let minor?, nil):         return "\(self.major).\(minor)"
            case (let minor , let patch?):  return "\(self.major).\(minor ?? 0).\(patch)"
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
