extension Biome 
{
    func uri(_ index:Ecosystem.Index, pins:[Package.Index: Version]) -> URI
    {
        let prefix:String 
        let location:Link.Reference<[String]>
        switch index 
        {
        case .composite(let composite):
            prefix = self.prefixes.master
            location = self.ecosystem.location(of: composite, pins: pins)
        
        case .article(let article):
            prefix = self.prefixes.doc
            location = self.ecosystem.location(of: article, pins: pins)
        
        case .module(let module):
            prefix = self.prefixes.master
            location = self.ecosystem.location(of: module, pins: pins)
        
        case .package(let package):
            prefix = self.prefixes.master
            location = self.ecosystem.location(of: package, pins: pins)
        }
        return .init(prefix: prefix, location)
    }
    
    func resolve<Tail>(uri:Link.Reference<Tail>) -> Ecosystem.Resolution?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        guard let prefix:String = uri.first?.identifier ?? nil
        else 
        {
            return nil
        }
        switch self.keys[leaf: prefix]
        {
        case self.keyword.master?:
            return self.ecosystem.resolve(location: uri.dropFirst(), keys: self.keys) 
            
        case self.keyword.doc?:
            break
        case self.keyword.lunr?:
            break
        case self.keyword.sitemaps?:
            break
        default:
            break
        }
        return nil
    }
}
