import BSONDecoding

extension Mongo.CollectionMetadata
{
    /// Collection options.
    @frozen public
    struct Options:Sendable
    {
        public
        let collation:Mongo.Collation?
        public
        let writeConcern:Mongo.WriteConcern?
        public
        let indexOptionDefaults:Mongo.StorageConfiguration?
        public
        let storageEngine:Mongo.StorageConfiguration?

        public
        let variant:Mongo.Create.Variant

        public
        init(collation:Mongo.Collation?,
            writeConcern:Mongo.WriteConcern?,
            indexOptionDefaults:Mongo.StorageConfiguration?,
            storageEngine:Mongo.StorageConfiguration?,
            variant:Mongo.Create.Variant)
        {
            self.collation = collation
            self.writeConcern = writeConcern
            self.indexOptionDefaults = indexOptionDefaults
            self.storageEngine = storageEngine
            self.variant = variant
        }
    }
}
extension Mongo.CollectionMetadata.Options
{
    @inlinable public
    var capped:Bool
    {
        if case _? = self.variant.cap
        {
            return true
        }
        else
        {
            return false
        }
    }
    @inlinable public
    var size:Int?
    {
        self.variant.cap?.size
    }
    @inlinable public
    var max:Int?
    {
        self.variant.cap?.max
    }
    @inlinable public
    var validationAction:Mongo.ValidationAction?
    {
        switch self.variant
        {
        case .collection(cap: _, validationAction: let action, validationLevel: _, validator: _):
            return action
        default:
            return nil
        }
    }
    @inlinable public
    var validationLevel:Mongo.ValidationLevel?
    {
        switch self.variant
        {
        case .collection(cap: _, validationAction: _, validationLevel: let level, validator: _):
            return level
        default:
            return nil
        }
    }
    @inlinable public
    var timeseries:Mongo.Timeseries?
    {
        switch self.variant
        {
        case .timeseries(let timeseries):
            return timeseries
        default:
            return nil
        }
    }
    @inlinable public
    var viewOn:Mongo.Collection?
    {
        switch self.variant
        {
        case .view(on: let collection, pipeline: _):
            return collection
        default:
            return nil
        }
    }
    @inlinable public
    var pipeline:[BSON.Fields]?
    {
        switch self.variant
        {
        case .view(on: _, pipeline: let pipeline):
            return pipeline
        default:
            return nil
        }
    }
}
extension Mongo.CollectionMetadata.Options
{
    @inlinable public
    init(bson:BSON.Dictionary<some RandomAccessCollection<UInt8>>,
        type:Mongo.CollectionType) throws
    {
        let variant:Mongo.Create.Variant
        switch type
        {
        case .collection:
            let cap:Mongo.Cap?
            if case true? = try bson["capped"]?.decode(to: Bool.self)
            {
                cap = .init(
                    size: try bson["size"].decode(to: Int.self),
                    max: try bson["max"]?.decode(to: Int.self))
            }
            else
            {
                cap = nil
            }
            variant = .collection(cap: cap,
                validationAction: try bson["validationAction"]?.decode(
                    to: Mongo.ValidationAction.self),
                validationLevel: try bson["validationLevel"]?.decode(
                    to: Mongo.ValidationLevel.self),
                validator: try bson["validator"]?.decode(to: BSON.Fields.self) ?? [:])
        
        case .timeseries:
            variant = .timeseries(try bson["timeseries"].decode(to: Mongo.Timeseries.self))
        
        case .view:
            variant = .view(
                on: try bson["viewOn"].decode(to: Mongo.Collection.self),
                pipeline: try bson["pipeline"].decode(to: [BSON.Fields].self))
        }
        self.init(
            collation: try bson["collation"]?.decode(to: Mongo.Collation.self),
            writeConcern: try bson["writeConcern"]?.decode(to: Mongo.WriteConcern.self),
            indexOptionDefaults: try bson["indexOptionDefaults"]?.decode(
                to: Mongo.StorageConfiguration.self),
            storageEngine: try bson["storageEngine"]?.decode(
                to: Mongo.StorageConfiguration.self),
            variant: variant)
    }
}
