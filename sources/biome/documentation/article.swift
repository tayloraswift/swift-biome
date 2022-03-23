import StructuredDocument 
import HTML

extension Documentation 
{
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
    struct Article<Anchor> where Anchor:Hashable
    {
        typealias Element = HTML.Element<Anchor> 
        
        let title:String
        let stem:[[UInt8]]
        let content:ArticleContent<Anchor>
        let context:UnresolvedLinkContext
    }
    struct ArticleContent<Anchor> where Anchor:Hashable 
    {
        typealias Element = HTML.Element<Anchor> 
        
        let errors:[Error]
        let summary:DocumentTemplate<Anchor, [UInt8]>?
        let discussion:DocumentTemplate<Anchor, [UInt8]>?
        
        static 
        var empty:Self 
        {
            .init(errors: [], summary: nil, discussion: nil)
        }
        
        func compactMapAnchors<T>(_ transform:(Anchor) throws -> T?) rethrows -> ArticleContent<T> 
            where T:Hashable
        {
            .init(errors:   self.errors, 
                summary:    try self.summary?.compactMap(transform), 
                discussion: try self.discussion?.compactMap(transform))
        }
    }
}
extension Documentation.ArticleContent where Anchor == Documentation.UnresolvedLink
{    
    init(errors:[Error], summary:Element?, discussion:[Element]) 
    {
        self.errors = errors
        self.summary = summary.map(DocumentTemplate<Anchor, [UInt8]>.init(freezing:))
        self.discussion = discussion.isEmpty ? nil : .init(freezing: discussion)
    }
}
