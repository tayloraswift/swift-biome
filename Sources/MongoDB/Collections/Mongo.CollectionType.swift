extension Mongo
{
    @frozen public
    enum CollectionType:String
    {
        case collection
        case timeseries
        case view
    }
}
