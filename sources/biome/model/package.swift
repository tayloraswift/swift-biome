import Resource

extension Biome 
{
    public 
    enum PackageIdentifierError:Error 
    {
        case duplicate(package:Package.ID)
    }
    
    public 
    struct Package:Sendable, Identifiable
    {
        public 
        enum ID:Hashable, Comparable, Sendable  
        {
            case swift 
            case community(String)
            
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
        let id:ID
        let modules:Range<Int>, 
            hash:Resource.Version
        
        var name:String 
        {
            self.id.name
        }
    }
}
