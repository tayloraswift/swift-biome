import BSON

extension Mongo.Create
{
    @frozen public
    enum Variant:Sendable
    {
        case collection(cap:Mongo.Cap? = nil,
            validationAction:Mongo.ValidationAction? = nil,
            validationLevel:Mongo.ValidationLevel? = nil,
            validator:BSON.Fields = [:])
        
        case timeseries(Mongo.Timeseries)

        case view(on:Mongo.Collection,
            pipeline:[BSON.Fields])
    }
}
extension Mongo.Create.Variant
{
    @inlinable public
    var type:Mongo.CollectionType
    {
        switch self
        {
        case .collection:   return .collection
        case .timeseries:   return .timeseries
        case .view:         return .view
        }
    }
    @inlinable public
    var cap:Mongo.Cap?
    {
        switch self
        {
        case .collection(cap: let cap?, validationAction: _, validationLevel: _, validator: _):
            return cap
        default:
            return nil
        }
    }
}
