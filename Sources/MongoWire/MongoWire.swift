/// A MongoDB wire protocol version. This is not the same thing as a server version.
///
/// See: https://github.com/mongodb/specifications/blob/master/source/wireversion-featurelist.rst
@frozen public
struct MongoWire:RawRepresentable
{
    public
    let rawValue:Int32

    @inlinable public
    init(rawValue:Int32)
    {
        self.rawValue = rawValue
    }
}
extension MongoWire:Comparable
{
    @inlinable public static
    func < (lhs:Self, rhs:Self) -> Bool
    {
        lhs.rawValue < rhs.rawValue
    }
}
extension MongoWire:ExpressibleByIntegerLiteral
{
    @inlinable public
    init(integerLiteral:Int32)
    {
        self.init(rawValue: integerLiteral)
    }
}
