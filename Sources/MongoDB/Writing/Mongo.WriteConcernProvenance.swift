extension Mongo
{
    @frozen public
    enum WriteConcernProvenance:String, Hashable, Sendable
    {
        case clientSupplied
        case customDefault
        case getLastErrorDefaults
        case implicitDefault
    }
}
