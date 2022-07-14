import HTML

extension Article 
{
    struct Headline:Equatable 
    {
        let formatted:[UInt8]
        let plain:String
        
        init(_ plain:String)
        {
            self.init(formatted: .init(plain.utf8), plain: plain)
        }
        init(formatted:[UInt8], plain:String)
        {
            self.formatted = formatted 
            self.plain = plain 
        }
    }
    
    struct Template<Key>:Equatable where Key:Equatable
    {
        let errors:[Error]
        let summary:DOM.Template<Key>
        let discussion:DOM.Template<Key>
        
        // don’t include ``errors`` 
        static 
        func == (lhs:Self, rhs:Self) -> Bool 
        {
            lhs.summary == rhs.summary && lhs.discussion == rhs.discussion
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
            summary:DOM.Template<Key>, 
            discussion:DOM.Template<Key>) 
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
            let summary:DOM.Template<T> = try self.summary.transform
            {
                try transform($0, &errors)
            }
            let discussion:DOM.Template<T> = try self.discussion.transform
            {
                try transform($0, &errors)
            }
            return .init(errors: errors, summary: summary, discussion: discussion)
        }
    }
}
