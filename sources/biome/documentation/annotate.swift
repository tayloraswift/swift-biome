import Resource 
import StructuredDocument
import HTML

extension Documentation 
{
    public 
    func annotate<T>(markdown:Resource, for _:T.Type = T.self) -> [Anchor: [UInt8]]
    {
        let source:String
        switch markdown 
        {
        case .text(let string, type: .markdown, version: let version):
            source = string
        case .bytes(let bytes, type: .markdown, version: let version):
            source = String.init(decoding: bytes, as: Unicode.UTF8.self)
                
        default: 
            fatalError("Unsupported")
        }
        let surveyed:Surveyed = .init(markdown: _move(source), format: .entrapta)
        
        guard case .explicit(let title) = surveyed.heading 
        else 
        {
            fatalError("cannot annotate article without a title")
        }
        
        let (content, context):(Article<UnresolvedLink>.Content, UnresolvedLinkContext) = 
            surveyed.rendered(biome: self.biome, routing: self.routing, greenzone: nil)
        
        let resolved:Article<ResolvedLink>.Content = 
            self.routing.resolve(article: _move(content), context: context)
        
        return self.substitutions(title: title.plainText, content: resolved)
    }
}
