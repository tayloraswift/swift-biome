import BSON

extension Mongo
{
    @available(*, deprecated, renamed: "BSON.Fields")
    public
    typealias Document = BSON.Fields
}
