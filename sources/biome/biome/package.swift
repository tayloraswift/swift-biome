import Resource

extension Biome 
{
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
        let id:ID
        let modules:Range<Int>, 
            hash:Resource.Version?
        
        var name:String 
        {
            self.id.name
        }
    }
}
