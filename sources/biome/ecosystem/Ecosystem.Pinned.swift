extension Ecosystem 
{
    struct Pinned 
    {
        let ecosystem:Ecosystem 
        let pins:[Package.Index: Version]
        
        func pin(_ package:Package.Index, exhibit:Version? = nil) -> Package.Pinned 
        {
            self.ecosystem[package].pinned(self.pins, exhibit: exhibit)
        }
        
        init(_ ecosystem:Ecosystem, pins:[Package.Index: Version])
        {
            self.ecosystem = ecosystem 
            self.pins = pins
        }
        
        func uri(of choices:[Symbol.Composite]) -> URI
        {
            // `first` should always exist, if not, something has gone seriously 
            // wrong in swift-biome...
            guard let exemplar:Symbol.Composite = choices.first 
            else 
            {
                fatalError("empty disambiguation group")
            }
            let pinned:Package.Pinned = self.pin(exemplar.culture.package)
            return .init(root: self.ecosystem.root.master, 
                path: pinned.path(to: exemplar, ecosystem: self.ecosystem), 
                orientation: self.ecosystem[exemplar.base].orientation)
        }
        func uri(of index:Index, exhibit:Version? = nil) -> URI
        {
            switch index 
            {
            case .composite(let composite):
                return self.ecosystem.uri(of: composite, 
                    in: self.pin(composite.culture.package, exhibit: exhibit))
            case .article(let article):
                return self.ecosystem.uri(of: article, 
                    in: self.pin(article.module.package, exhibit: exhibit))
            case .module(let module):
                return self.ecosystem.uri(of: module, 
                    in: self.pin(module.package, exhibit: exhibit))
            case .package(let package):
                return self.ecosystem.uri(
                    of: self.pin(package, exhibit: exhibit))
            }
        }
        func uri(of index:Index, cache:inout [Index: String]) 
            -> String
        {
            if let cached:String = cache[index] 
            {
                return cached 
            }
            else 
            {
                let uri:String = self.uri(of: index).description 
                cache[index] = uri 
                return uri
            }
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
                let headline:Article.Headline = 
                    self.pin(article.module.package).headline(article)
                cache[article] = headline.formatted
                return headline.formatted
            }
        }
    }
}
