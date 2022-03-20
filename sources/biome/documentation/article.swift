import StructuredDocument 
import HTML

extension Documentation 
{
    enum UnresolvedLink:Hashable, Sendable
    {
        case doc(namespace:Int, stem:[[UInt8]], leaf:[UInt8])
    }
    enum ResolvedLink:Hashable, Sendable
    {
        case article(Int)
    }

    enum Format 
    {
        /// entrapta format 
        case entrapta
        
        /// lorentey’s `swift-collections` format
        // case collections
        
        /// nate cook’s `swift-algorithms` format
        // case algorithms 
        
        /// apple’s DocC format
        case docc
    }
    struct ArticleRenderingContext 
    {
        let format:Format
        let namespace:Int 
        let scope:[[UInt8]]
    }
    enum ArticleOwner 
    {
        case free(title:String)
        case module(summary:Article<UnresolvedLink>.Element?, index:Int)
        case symbol(summary:Article<UnresolvedLink>.Element?, index:Int) 
    }
    struct Article<Anchor> where Anchor:Hashable
    {
        typealias Element = HTML.Element<Anchor> 
        
        let namespace:Int
        let path:[[UInt8]]
        let title:String
        let content:DocumentTemplate<Anchor, [UInt8]>
        
        init(namespace:Int, path:[[UInt8]], title:String, content:DocumentTemplate<Anchor, [UInt8]>)
        {
            self.namespace = namespace
            self.path = path
            self.title = title
            self.content = content
        }
        init<S>(namespace:Int, path:S, title:String, content:[Element])
            where S:Sequence, S.Element:StringProtocol
        {
            self.namespace  = namespace
            self.path       = path.map{ URI.encode(component: $0.utf8) }
            self.title      = title
            self.content    = .init(freezing: content)
        }
        
        func compactMapAnchors<T>(_ transform:(Anchor) throws -> T?) rethrows -> Article<T> 
            where T:Hashable
        {
            .init(namespace: self.namespace, path: self.path, title: self.title, 
                content: try self.content.compactMap(transform))
        }
    }
}
