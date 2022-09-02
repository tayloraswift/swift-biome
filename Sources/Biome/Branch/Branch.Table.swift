extension Branch.Table:Sendable where Key:Sendable 
{
}
extension Branch 
{
    struct Table<Key>:ExpressibleByDictionaryLiteral where Key:Hashable
    {
        private 
        var items:[Key: Stack]

        subscript(prefix:PartialRangeThrough<_Version.Revision>) -> Prefix
        {
            return .init(self.items, limit: prefix.upperBound)
        }
        subscript(_:UnboundedRange) -> Prefix
        {
            return .init(self.items, limit: .max)
        }

        init(dictionaryLiteral:(Key, Stack)...)
        {
            self.items = .init(uniqueKeysWithValues: dictionaryLiteral)
        }
    }
}

extension Branch.Table.Prefix:Sendable where Key:Sendable 
{
}
extension Branch.Table 
{
    struct Prefix 
    {
        private 
        let items:[Key: Branch.Stack]
        let limit:_Version.Revision

        init(_ items:[Key: Branch.Stack], limit:_Version.Revision)
        {
            self.items = items 
            self.limit = limit
        }
    }
}