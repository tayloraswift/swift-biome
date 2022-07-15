extension Ecosystem 
{
    struct Pinned 
    {
        let ecosystem:Ecosystem 
        let pins:[Package.Index: Version]
        
        func pin(_ package:Package.Index) -> Package.Pinned 
        {
            self.ecosystem[package].pinned(self.pins)
        }
        
        init(_ ecosystem:Ecosystem, pins:[Package.Index: Version])
        {
            self.ecosystem = ecosystem 
            self.pins = pins
        }
        
        func uri(of index:Index, cache:inout [Index: String]) -> String
        {
            if let cached:String = cache[index] 
            {
                return cached 
            }
            let uri:URI 
            switch index 
            {
            case .composite(let composite):
                uri = self.ecosystem.uri(of: composite, 
                    in: self.pin(composite.culture.package))
            case .article(let article):
                uri = self.ecosystem.uri(of: article, 
                    in: self.pin(article.module.package))
            case .module(let module):
                uri = self.ecosystem.uri(of: module, 
                    in: self.pin(module.package))
            case .package(let package):
                uri = self.ecosystem.uri(
                    of: self.pin(package))
            }
            let string:String = uri.description 
            cache[index] = string
            return string
        }
        func headline(of article:Article.Index, cache:inout [Article.Index: [UInt8]]) 
            -> [UInt8]
        {
            if let cached:[UInt8] = cache[article] 
            {
                return cached 
            }
            else 
            {
                let excerpt:Article.Excerpt = 
                    self.pin(article.module.package).excerpt(article)
                cache[article] = excerpt.headline
                return excerpt.headline
            }
        }
    }
}
