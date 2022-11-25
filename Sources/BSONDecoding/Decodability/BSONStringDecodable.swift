/// A type that can be decoded from a BSON UTF-8 string. This protocol
/// exists to allow types that also conform to ``LosslessStringConvertible``
/// to opt-in to automatic ``BSONDecodable`` conformance as well.
public
protocol BSONStringDecodable:BSONDecodable
{
    /// Initializes an instance of this type from a string. This requirement
    /// restates its counterpart in ``LosslessStringConvertible`` if
    /// [`Self`]() also conforms to it.
    init?(_:String)
}
extension BSONStringDecodable
{
    /// Attempts to cast the given variant value to a string, and then
    /// delegates to this type’s ``init(_:)`` witness.
    ///
    /// This default implementation is provided on an extension on a
    /// dedicated protocol rather than an extension on ``BSONDecodable``
    /// itself to prevent unexpected behavior for types (such as ``Double``)
    /// who implement ``LosslessStringConvertible``, but expect to be
    /// decoded from a variant value that is not a string.
    @inlinable public
    init(bson:BSON.Value<some RandomAccessCollection<UInt8>>) throws
    {
        let string:String = try .init(bson: bson)
        if  let value:Self = .init(string)
        {
            self = value
        }
        else 
        {
            throw BSON.ValueError<String, Self>.init(invalid: string)
        }
    }
}
