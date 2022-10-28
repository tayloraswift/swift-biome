extension BSON
{
    /// A MongoDB object reference. This type models a MongoDB `ObjectId`.
    ///
    /// This type has reference semantics, but (needless to say) it is
    /// completely unmanaged, as it is nothing more than a 96-bit integer.
    ///
    /// The type name is chosen to avoid conflict with Swift’s ``ObjectIdentifier``.
    @frozen public 
    struct Identifier:Sendable
    {
        public 
        typealias Seed = 
        (
            UInt8,
            UInt8,
            UInt8,
            UInt8,
            UInt8
        )
        public 
        typealias Ordinal = 
        (
            UInt8,
            UInt8,
            UInt8
        )

        public 
        let timestamp:UInt32 
        public 
        let seed:Seed
        public 
        let ordinal:Ordinal

        @inlinable public
        init(timestamp:UInt32, _ seed:Seed, _ ordinal:Ordinal)
        {
            self.timestamp = timestamp
            self.seed = seed
            self.ordinal = ordinal
        }
    }
}
extension BSON.Identifier:Equatable
{
    @inlinable public static
    func == (lhs:Self, rhs:Self) -> Bool
    {
        lhs.timestamp   == rhs.timestamp &&
        lhs.seed        == rhs.seed &&
        lhs.ordinal     == rhs.ordinal
    }
}
extension BSON.Identifier:Hashable
{
    @inlinable public
    func hash(into hasher:inout Hasher)
    {
        self.timestamp.hash(into: &hasher)
        withUnsafeBytes(of: self.seed)
        {
            hasher.combine(bytes: $0)
        }
        withUnsafeBytes(of: self.ordinal)
        {
            hasher.combine(bytes: $0)
        }
    }
}
