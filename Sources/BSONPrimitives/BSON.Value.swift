import BSON

extension BSON.Value
{
    /// Promotes a [`nil`]() result to a thrown ``TypecastError``.
    /// 
    /// If `T` conforms to ``BSONDecodable``, prefer calling its throwing
    /// ``BSONDecodable/.init(bson:)`` to calling this method directly.
    ///
    /// >   Throws: A ``TypecastError`` if the given curried method returns [`nil`]().
    @inline(__always)
    @inlinable public 
    func cast<T>(with cast:(Self) throws -> T?) throws -> T
    {
        if let value:T = try cast(self)
        {
            return value 
        }
        else 
        {
            throw BSON.TypecastError<T>.init(invalid: self.type)
        }
    }
}
