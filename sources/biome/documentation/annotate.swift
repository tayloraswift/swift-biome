import Resource 
import StructuredDocument
import HTML

extension Documentation 
{
    /* public 
    struct _Article<Anchor> 
    {
        public 
        typealias Element = HTML.Element<Anchor>
        
        public 
        var title:String 
        public
        var heading:Element
        public
        var summary:Element?
        public
        var discussion:[Element]
    } */
    public 
    func annotate<T>(markdown:Resource, for _:T.Type = T.self) -> [Anchor: [UInt8]]
    {
        let (title, summary, discussion, context, errors):
        (
            ArticleTitle, 
            Article<UnresolvedLink>.Element?, 
            [Article<UnresolvedLink>.Element], 
            UnresolvedLinkContext, 
            [Error]
        ) 
        switch markdown 
        {
        case .text(let string, type: .markdown, version: let version):
            (title, summary, discussion, context, errors) = 
                ArticleRenderer.render(.docc, 
                    article: string, 
                    biome: self.biome, 
                    routing: self.routing, 
                    namespace: 0)
        case .bytes(let bytes, type: .markdown, version: let version):
            (title, summary, discussion, context, errors) = 
                ArticleRenderer.render(.docc,
                    article: String.init(decoding: bytes, as: Unicode.UTF8.self), 
                    biome: self.biome, 
                    routing: self.routing, 
                    namespace: 0)
        default: 
            fatalError("Unsupported")
        }
        Swift.print("\(errors.count) errors")
        for error:Error in errors
        {
            Swift.print(error)
        }
        
        let unresolved:ArticleContent<UnresolvedLink> = .init(errors: errors, summary: summary, discussion: discussion)
        let resolved:ArticleContent<ResolvedLink> = self.routing.resolve(article: unresolved, context: context)
        
        var anchors:Set<ResolvedLink> = []
        if let template:DocumentTemplate<ResolvedLink, [UInt8]> = resolved.summary 
        {
            anchors.formUnion(template.anchors.map(\.id))
        }
        if let template:DocumentTemplate<ResolvedLink, [UInt8]> = resolved.discussion
        {
            anchors.formUnion(template.anchors.map(\.id))
        }
        
        let presented:[ResolvedLink: StaticElement] = .init(uniqueKeysWithValues: anchors.map 
        {
            ($0, self.present(reference: $0))
        })
        
        var substitutions:[Anchor: [UInt8]] = [:]
        substitutions[.discussion] = (resolved.discussion?.apply(presented).joined()).map([UInt8].init(_:))
        return substitutions
    }
}
