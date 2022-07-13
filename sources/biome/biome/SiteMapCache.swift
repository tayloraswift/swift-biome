import Resources

struct SiteMapCache:Cache 
{
    private
    var cache:[Package.Index: Resource]
    
    subscript(package:Package.Index) -> Resource?
    {
        _read 
        {
            yield self.cache[package]
        }
    }
    
    init()
    {
        self.cache = [:]
    }
    mutating 
    func regenerate(for package:Package.Index, from ecosystem:Ecosystem)
    {
        self.cache[package] = Self.generate(for: package, from: ecosystem)
    }
    private static 
    func generate(for package:Package.Index, from ecosystem:Ecosystem) -> Resource
    {
        let domain:String.UTF8View = "https://swiftinit.org".utf8
        let current:Package.Pinned = ecosystem[package].pinned()
        // only include natural symbols in a sitemap, since google is likely to 
        // consider the synthesized ones non-canonical
        var sitemap:[UInt8] = []
        for module:Module in current.package.modules.all 
        {
            let uri:URI = ecosystem.uri(of: module.index, in: current)
            sitemap += domain
            sitemap += uri.description.utf8
            sitemap.append(0x0a) // '\n'
        }
        for module:Module in current.package.modules.all 
        {
            for offset:Int in module.articles.joined() 
            {
                let index:Article.Index = .init(module.index, offset: offset)
                let uri:URI = ecosystem.uri(of: index, in: current)
                sitemap += domain
                sitemap += uri.description.utf8
                sitemap.append(0x0a) // '\n'
            }
            for colony:Symbol.ColonialRange in module.symbols 
            {
                for offset:Int in colony.offsets 
                {
                    let index:Symbol.Index = .init(module.index, offset: offset)
                    let uri:URI = ecosystem.uri(of: .init(natural: index), 
                        in: current)
                    sitemap += domain
                    sitemap += uri.description.utf8
                    sitemap.append(0x0a) // '\n'
                }
            }
        }
        return .init(hashing: sitemap, type: .utf8(encoded: .plain))
    }
}
