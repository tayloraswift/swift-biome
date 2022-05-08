import StructuredDocument 
import HTML

public 
enum Article 
{    
    public
    struct Rendered<Anchor> where Anchor:Hashable
    {
        typealias Element = HTML.Element<Anchor> 
        
        struct Content
        {
            var errors:[Error]
            let summary:DocumentTemplate<Anchor, [UInt8]>?
            let discussion:DocumentTemplate<Anchor, [UInt8]>?
            
            static 
            var empty:Self 
            {
                .init(errors: [], summary: nil, discussion: nil)
            }
            
            init(errors:[Error], 
                summary:DocumentTemplate<Anchor, [UInt8]>?, 
                discussion:DocumentTemplate<Anchor, [UInt8]>?) 
            {
                self.errors = errors
                self.summary = summary
                self.discussion = discussion
            }
            init(errors:[Error], summary:Element?, discussion:[Element]) 
                where Anchor == UnresolvedLink
            {
                self.errors = errors
                self.summary = summary.map(DocumentTemplate<Anchor, [UInt8]>.init(freezing:))
                self.discussion = discussion.isEmpty ? nil : .init(freezing: discussion)
            }
            
            func compactMapAnchors<T>(_ transform:(Anchor) throws -> T?) rethrows -> Rendered<T>.Content
                where T:Hashable
            {
                .init(errors:   self.errors, 
                    summary:    try self.summary?.compactMap(transform), 
                    discussion: try self.discussion?.compactMap(transform))
            }
        }
        
        public
        let title:String, 
            path:[String]
        public 
        let snippet:String
        let headline:Documentation.Element?
        var content:Content
        
        var stem:[[UInt8]]
        {
            //self.path.map { URI.encode(component: $0.utf8) }
            self.path.suffix(1).map { Documentation.URI.encode(component: $0.utf8) }
        }
        var leaf:[UInt8]
        {
            []
        }
    }
}
