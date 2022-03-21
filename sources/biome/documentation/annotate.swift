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
        let article:(head:Article<UnresolvedLink>.Element?, body:[Article<UnresolvedLink>.Element], context:UnresolvedLinkContext, errors:[Error])
        switch markdown 
        {
        case .text(let string, type: .markdown, version: let version):
            article = ArticleRenderer.render(_article: string, 
                biome: self.biome, 
                routing: self.routing)
        case .bytes(let bytes, type: .markdown, version: let version):
            article = ArticleRenderer.render(_article: String.init(decoding: bytes, as: Unicode.UTF8.self), 
                biome: self.biome, 
                routing: self.routing)
        default: 
            fatalError("Unsupported")
        }
        Swift.print("\(article.errors.count) errors")
        for error:Error in article.errors
        {
            Swift.print(error)
        }
        
        let _comment:Comment<UnresolvedLink> = .init(errors: article.errors, summary: article.head, discussion: article.body)
        let resolved:Comment<ResolvedLink> = self.routing.resolve(comment: _comment, context: article.context)
        
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
