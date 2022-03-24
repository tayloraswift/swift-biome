import Resource 
import StructuredDocument
import HTML

extension Documentation 
{
    public 
    func annotate<T>(markdown:Resource, for _:T.Type = T.self) -> [Anchor: [UInt8]]
    {
        let surveyed:Surveyed
        switch markdown 
        {
        case .text(let string, type: .markdown, version: let version):
            surveyed = .init(markdown: string)
        case .bytes(let bytes, type: .markdown, version: let version):
            surveyed = .init(markdown: String.init(decoding: bytes, as: Unicode.UTF8.self))
                
        default: 
            fatalError("Unsupported")
        }
        
        guard case .explicit(let title) = surveyed.heading 
        else 
        {
            fatalError("cannot annotate article without a title")
        }
        
        for node in surveyed.nodes
        {
            switch node 
            {
            case .block(let block):
                Swift.print(block.debugDescription())
            case .section(let heading, let children):
                Swift.print(heading.debugDescription())
                Swift.print("(\(children.count) children)")
            }
        }
        
        let context:UnresolvedLinkContext = .init(namespace: 0, scope: [])
        let unresolved:Article<UnresolvedLink>.Content = 
            surveyed.rendered(as: .docc, biome: self.biome, routing: self.routing, context: context)
        
        Swift.print("\(unresolved.errors.count) errors")
        for error:Error in unresolved.errors
        {
            Swift.print(error)
        }
        
        let resolved:Article<ResolvedLink>.Content = 
            self.routing.resolve(article: _move(unresolved), context: context)
        
        return self.substitutions(title: title.plainText, content: resolved)
    }
}
