import Resource 
import StructuredDocument
import HTML

extension Documentation 
{
    public 
    func annotate<T>(markdown:Resource, for _:T.Type = T.self) -> [Anchor: [UInt8]]
    {
        let survey:ArticleSurvey
        switch markdown 
        {
        case .text(let string, type: .markdown, version: let version):
            survey = ArticleRenderer.survey(markdown: string)
        case .bytes(let bytes, type: .markdown, version: let version):
            survey = ArticleRenderer.survey(markdown: String.init(decoding: bytes, as: Unicode.UTF8.self))
                
        default: 
            fatalError("Unsupported")
        }
        
        guard case .explicit(let title) = survey.heading 
        else 
        {
            fatalError("cannot annotate article without a title")
        }
        
        let context:UnresolvedLinkContext = .init(namespace: 0, scope: [])
        let unresolved:ArticleContent<UnresolvedLink> = ArticleRenderer.render(survey, 
            as: .docc,
            biome: self.biome, 
            routing: self.routing, 
            context: context)
        
        Swift.print("\(unresolved.errors.count) errors")
        for error:Error in unresolved.errors
        {
            Swift.print(error)
        }
        
        let resolved:ArticleContent<ResolvedLink> = 
            self.routing.resolve(article: _move(unresolved), context: context)
        
        return self.substitutions(title: title.plainText, content: resolved, filter: [])
    }
}
