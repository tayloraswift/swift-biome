extension BSON
{
    /// A document had an invalid key schema.
    @frozen public
    struct ArrayShapeError:Equatable, Error
    {
        public
        let count:Int
        public
        let expected:Int?

        @inlinable public
        init(count:Int, expected:Int? = nil)
        {
            self.count = count
            self.expected = expected
        }
    }
}
extension BSON.ArrayShapeError:CustomStringConvertible
{
    public
    var description:String
    {
        if let expected:Int = self.expected
        {
            return "invalid element count (\(self.count)), expected \(expected) elements"
        }
        else
        {
            return "invalid element count (\(self.count))"
        }
    }
}
