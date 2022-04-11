import Resource 
import StructuredDocument
import HTML

extension Documentation 
{
    public 
    func annotate(markdown:Resource) -> Article.Rendered<ResolvedLink>
    {
        let source:String
        switch markdown 
        {
        case .text  (let string, type: _, version: let version):
            source = string
        case .binary(let bytes,  type: _, version: let version):
            source = String.init(decoding: bytes, as: Unicode.UTF8.self)
        }
        let surveyed:Article.Surveyed = .init(markdown: _move(source), format: .entrapta)
        
        guard case .explicit(let title) = surveyed.headline 
        else 
        {
            fatalError("cannot annotate article without a title")
        }
        
        let context:UnresolvedLink.Context
        var content:Article.Rendered<UnresolvedLink>.Content
        
        (content, context) = surveyed.rendered(biome: self.biome, routing: self.routing, greenzone: nil)
        
        let headline:Element? = surveyed.metadata.noTitle ? nil : surveyed.headline.rendered()
        let resolved:Article.Rendered<ResolvedLink>.Content = 
            self.routing.resolve(article: content, context: context)
        let article:Article.Rendered<ResolvedLink> = .init(
            title: title.plainText, 
            path: surveyed.metadata.path, 
            snippet: surveyed.snippet, 
            headline: headline, 
            content: resolved)
        return article
    }
}
