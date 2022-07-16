import Resources 
import RSS 

extension Ecosystem 
{
    public 
    func generateRssFeed(for module:Module.Index, domain:String) -> [RSS.StaticElement] 
    {
        let pinned:Package.Pinned = self[module.package].pinned()
        return pinned.package[local: module].articles.joined().map
        {
            let excerpt:Article.Excerpt = pinned.excerpt($0)
            let uri:URI = self.uri(of: $0, in: pinned)
            return RSS.StaticElement[.item]
            {
                RSS.StaticElement[.title]
                {
                    excerpt.title
                }
                RSS.StaticElement[.description]
                {
                    excerpt.snippet
                }
                RSS.StaticElement[.link]
                {
                    "https://\(domain)\(uri.description)"
                }
            }
        }
    }
}
