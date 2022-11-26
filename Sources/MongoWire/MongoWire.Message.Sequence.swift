import BSON
import BSONTraversal

extension MongoWire.Message
{
    @frozen public
    struct Sequence
    {
        public
        let bytes:Bytes

        /// Stores the argument in ``bytes`` unchanged.
        ///
        /// >   Complexity: O(1)
        @inlinable public
        init(bytes:Bytes)
        {
            self.bytes = bytes
        }
    }
}
extension MongoWire.Message.Sequence:VariableLengthBSON
{
    public
    typealias Frame = MongoWire.SequenceFrame

    /// Stores the argument in ``bytes`` unchanged. Equivalent to ``init(_:)``.
    ///
    /// >   Complexity: O(1)
    @inlinable public
    init(slicing bytes:Bytes)
    {
        self.init(bytes: bytes)
    }
}
extension MongoWire.Message.Sequence
{
    /// The length that would be encoded in this document-sequence’s
    /// prefixed header. Equal to [`self.size`]().
    @inlinable public
    var header:Int32
    {
        .init(self.size)
    }
    
    /// The size of this document-sequence when encoded with its header.
    /// This *is* the same as the length encoded in the header itself.
    @inlinable public
    var size:Int
    {
        4 + self.bytes.count
    }
}
extension MongoWire.Message.Sequence where Bytes:RangeReplaceableCollection<UInt8>
{
    @inlinable public
    init<Other>(id:String, documents:some Collection<BSON.Document<Other>>)
    {
        let size:Int = documents.reduce(id.utf8.count + 1) { $0 + $1.size }
        var output:BSON.Output<Bytes> = .init(capacity: size)
        // do *not* emit the length header!
        output.serialize(cString: id)
        for document:BSON.Document<Other> in documents
        {
            output.serialize(document: document)
        }
        assert(output.destination.count == size,
            "precomputed size (\(size)) does not match output size (\(output.destination.count))")
        self.init(bytes: output.destination)
    }
}
