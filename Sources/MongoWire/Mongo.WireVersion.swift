extension Mongo
{
    /// A MongoDB wire protocol version. This is not the same thing as a server version.
    ///
    /// See: https://github.com/mongodb/specifications/blob/master/source/wireversion-featurelist.rst
    @frozen public
    struct WireVersion:RawRepresentable
    {
        public
        let rawValue:Int32

        @inlinable public
        init(rawValue:Int32)
        {
            self.rawValue = rawValue
        }
    }
}
extension Mongo.WireVersion:Comparable
{
    @inlinable public static
    func < (lhs:Self, rhs:Self) -> Bool
    {
        lhs.rawValue < rhs.rawValue
    }
}
extension Mongo.WireVersion:ExpressibleByIntegerLiteral
{
    @inlinable public
    init(integerLiteral:Int32)
    {
        self.init(rawValue: integerLiteral)
    }
}
