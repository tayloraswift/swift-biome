extension BSON
{
    /// The MongoDB min-key. This type has a single state, and is
    /// isomorphic to ``Void``. It is mainly used by the decoding
    /// and encoding layers as an API landmark.
    @frozen public
    struct Min:Hashable, Equatable, Sendable
    {
        @inlinable public
        init()
        {
        }
    }
}
