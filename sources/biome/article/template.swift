import HTML

extension Article 
{
    struct Template<Key>:Hashable where Key:Hashable
    {
        let errors:[Error]
        let summary:DOM.Template<Key, [UInt8]>
        let discussion:DOM.Template<Key, [UInt8]>
        
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
        
        var isEmpty:Bool 
        {
            self.summary.isEmpty && self.discussion.isEmpty
        }
        
        init() 
        {
            self.errors = []
            self.summary = .init()
            self.discussion = .init()
        }
        init(errors:[Error], 
            summary:DOM.Template<Key, [UInt8]>, 
            discussion:DOM.Template<Key, [UInt8]>) 
        {
            self.errors = errors
            self.summary = summary
            self.discussion = discussion
        }
        
        func map<T>(_ transform:(Key) throws -> T) 
            rethrows -> Template<T>
            where T:Hashable
        {
            return .init(errors: self.errors, 
                summary: try self.summary.map(transform), 
                discussion: try self.discussion.map(transform))
        }
        func transform<T, Segment>(
            _ transform:(Key, inout [Error]) throws -> DOM.Substitution<T, Segment>) 
            rethrows -> Template<T>
            where T:Hashable, Segment:Sequence, Segment.Element == UInt8
        {
            var errors:[Error] = self.errors 
            let summary:DOM.Template<T, [UInt8]> = try self.summary.transform
            {
                try transform($0, &errors)
            }
            let discussion:DOM.Template<T, [UInt8]> = try self.discussion.transform
            {
                try transform($0, &errors)
            }
            return .init(errors: errors, summary: summary, discussion: discussion)
        }
    }
}
