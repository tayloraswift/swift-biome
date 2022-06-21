extension Biome 
{
    func uri(of resolution:Ecosystem.Resolution) -> URI 
    {
        let prefix:String 
        let location:Link.Reference<[String]>
        switch resolution 
        {        
        case .selection(   .index(let index), let pins):
            return self.uri(of: index, pins: pins)
        
        case .selection(.composites(let all), let pins):
            // `first` should always exist, if not, something has gone seriously 
            // wrong in swift-biome...
            guard let exemplar:Symbol.Composite = all.first 
            else 
            {
                fatalError("empty disambiguation group")
            }
            let version:Version = pins[exemplar.culture.package] ?? 
                self.ecosystem[exemplar.culture.package].latest
            
            location = self.ecosystem.location(of: exemplar, at: version, group: true)
            prefix = self.prefixes.master
        
        case .searchIndex(let package): 
            location = .init(path: [self.ecosystem[package].name, "types"])
            prefix = self.prefixes.lunr
        }
        return .init(prefix: prefix, location)
    }
    func uri(of index:Ecosystem.Index, at version:Version) -> URI
    {
        let prefix:String 
        let location:Link.Reference<[String]>
        switch index 
        {
        case .composite(let composite):
            prefix = self.prefixes.master
            location = self.ecosystem.location(of: composite, at: version)
        
        case .article(let article):
            prefix = self.prefixes.doc
            location = self.ecosystem.location(of: article, at: version)
        
        case .module(let module):
            prefix = self.prefixes.master
            location = self.ecosystem.location(of: module, at: version)
        
        case .package(let package):
            prefix = self.prefixes.master
            location = self.ecosystem.location(of: package, at: version)
        }
        return .init(prefix: prefix, location)
    }
    func uri(of index:Ecosystem.Index, pins:[Package.Index: Version]) -> URI
    {
        self.uri(of: index, at: pins[index.culture] ?? self.ecosystem[index.culture].latest)
    }
    
    func resolve<Tail>(uri:Link.Reference<Tail>) 
        -> (resolution:Ecosystem.Resolution, redirected:Bool)?
        where Tail:BidirectionalCollection, Tail.Element == Link.Component
    {
        guard let first:String = uri.first?.identifier ?? nil
        else 
        {
            return nil
        }
        let prefix:URI.Prefix 
        switch self.keys[leaf: first]
        {
        case self.keyword.master?:  prefix = .master
        case self.keyword.doc?:     prefix = .doc
        case self.keyword.lunr?:    prefix = .lunr 
        default:
            return nil 
        }
        return self.ecosystem.resolve(prefix: prefix, 
            global: uri.dropFirst(), 
            keys: self.keys) 
    }
}
