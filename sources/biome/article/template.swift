import HTML

extension Article 
{
    struct Template<Anchor>:Hashable where Anchor:Hashable
    {
        let errors:[Error]
        let summary:DOM.Template<Anchor, [UInt8]>
        let discussion:DOM.Template<Anchor, [UInt8]>
        
        // don’t include ``errors`` 
        static 
        func == (lhs:Self, rhs:Self) -> Bool 
        {
            lhs.summary == rhs.summary && lhs.discussion == rhs.discussion
        }
        func hash(into hasher:inout Hasher) 
        {
            self.summary.hash(into: &hasher)
            self.discussion.hash(into: &hasher)
        }
        
        static 
        var empty:Self 
        {
            .init(errors: [], summary: .empty, discussion: .empty)
        }
        
        init(errors:[Error], 
            summary:DOM.Template<Anchor, [UInt8]>, 
            discussion:DOM.Template<Anchor, [UInt8]>) 
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
