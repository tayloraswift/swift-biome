import RSS 
import URI

extension Ecosystem 
{
    public 
    func generateRssFeed(for module:Module.Index, domain:String) -> [RSS.Element<Never>] 
    {
        let pinned:Package.Pinned = self[module.package].pinned()
        return pinned.package[local: module].articles.joined().map
        {
            let excerpt:Article.Excerpt = pinned.excerpt($0)
            let uri:URI = self.uri(of: $0, in: pinned)
            return .item(
                .title(excerpt.title),
                .description(excerpt.snippet),
                .link("https://\(domain)\(uri.description)"))
        }
    }
}
