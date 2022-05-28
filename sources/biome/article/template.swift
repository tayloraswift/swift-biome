import HTML

extension Article 
{
    struct Template<Anchor> where Anchor:Hashable
    {
        let errors:[Error]
        let summary:DocumentTemplate<Anchor, [UInt8]>
        let discussion:DocumentTemplate<Anchor, [UInt8]>
        
        static 
        var empty:Self 
        {
            .init(errors: [], summary: .empty, discussion: .empty)
        }
        
        init(errors:[Error], 
            summary:DocumentTemplate<Anchor, [UInt8]>, 
            discussion:DocumentTemplate<Anchor, [UInt8]>) 
        {
            self.errors = errors
            self.summary = summary
            self.discussion = discussion
        }
        
        func map<T>(_ transform:(Anchor) throws -> T) rethrows -> Template<T>
            where T:Hashable
        {
            return .init(errors: self.errors, summary: try self.summary.map(transform), 
                discussion: try self.discussion.map(transform))
        }
    }
}
