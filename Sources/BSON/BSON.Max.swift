extension BSON
{
    /// The MongoDB max-key. This type has a single state, and is
    /// isomorphic to ``Void``. It is mainly used by the decoding
    /// and encoding layers as an API landmark.
    @frozen public
    struct Max:Hashable, Equatable, Sendable
    {
        @inlinable public
        init()
        {
        }
    }
}
