import BSONDecoding
import BSONEncoding
import NIOCore

extension Mongo
{
    @frozen public
    enum TimeseriesGranularity:String, Sendable
    {
        case seconds
        case minutes
        case hours
    }
    @frozen public
    struct TimeseriesOptions:Sendable
    {
        public
        let timeField:String
        public
        let metaField:String?
        public
        let granularity:TimeseriesGranularity

        @inlinable public
        init(timeField:String, metaField:String? = nil,
            granularity:TimeseriesGranularity = .seconds)
        {
            self.timeField = timeField
            self.metaField = metaField
            self.granularity = granularity
        }
    }
}
extension Mongo.TimeseriesOptions:MongoScheme, MongoRepresentable
{
    public
    init(bson:BSON.Dictionary<ByteBufferView>) throws
    {
        self.init(
            timeField: try bson["timeField"].decode(to: String.self),
            metaField: try bson["metaField"]?.decode(to: String.self),
            granularity: try bson["granularity"].decode(
                cases: Mongo.TimeseriesGranularity.self))
    }
    public
    var bson:BSON.Document<[UInt8]>
    {
        let fields:BSON.Fields<[UInt8]> =
        [
            "timeField": .string(self.timeField),
            "metaField": .string(self.metaField),
            "granularity": .string(self.granularity.rawValue),
        ]
        return .init(fields)
    }
}
// extension Mongo
// {
//     @frozen public
//     struct ViewOptions
//     {
//         public
//         let on:String
//         public
//         let metaField:String?
//         public
//         let granularity:TimeseriesGranularity

//         @inlinable public
//         init(timeField:String, metaField:String? = nil,
//             granularity:TimeseriesGranularity = .seconds)
//         {
//             self.timeField = timeField
//             self.metaField = metaField
//             self.granularity = granularity
//         }
//     }
// }
extension Mongo
{
    /// Collection options.
    @frozen public
    struct CollectionOptions
    {
        public
        let cap:CollectionCap?
        public
        let collation:Collation?
        public
        let timeseries:TimeseriesOptions?
        public
        let validation:CollectionValidation?
        public
        let viewOn:Collection.ID?
        public
        let writeConcern:WriteConcern?

        public
        let pipeline:[BSON.Document<[UInt8]>]
        public
        let indexOptionDefaults:BSON.Document<[UInt8]>?
        public
        let storageEngine:BSON.Document<[UInt8]>?

        @inlinable public
        init(cap:CollectionCap? = nil,
            collation:Collation? = nil,
            timeseries:TimeseriesOptions? = nil,
            validation:CollectionValidation? = nil,
            viewOn:Collection.ID? = nil,
            writeConcern:WriteConcern? = nil,
            pipeline:[BSON.Document<[UInt8]>] = [],
            indexOptionDefaults:BSON.Document<[UInt8]>? = nil,
            storageEngine:BSON.Document<[UInt8]>? = nil)
        {
            self.cap = cap
            self.collation = collation
            self.timeseries = timeseries
            self.validation = validation
            self.viewOn = viewOn
            self.writeConcern = writeConcern
            self.pipeline = pipeline
            self.indexOptionDefaults = indexOptionDefaults
            self.storageEngine = storageEngine
        }
    }
}
extension Mongo.CollectionOptions:MongoScheme
{
    public
    init(bson:BSON.Dictionary<ByteBufferView>) throws
    {
        let cap:Mongo.CollectionCap?
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
        let validation:Mongo.CollectionValidation? = try bson["validator"]?.decode(
            as: BSON.Document<ByteBufferView>.self)
        {
            .init(validator: .init([UInt8].init($0.bytes)),
                action: try bson["validationAction"]?.decode(
                    cases: Mongo.CollectionValidation.Action.self) ?? .error,
                level: try bson["validationLevel"]?.decode(
                    cases: Mongo.CollectionValidation.Level.self) ?? .strict)
        }
        self.init(cap: cap, 
            collation: try bson["collation"]?.decode(
                as: BSON.Dictionary<ByteBufferView>.self,
                with: Mongo.Collation.init(bson:)),
            timeseries: try bson["timeseries"]?.decode(
                as: BSON.Dictionary<ByteBufferView>.self,
                with: Mongo.TimeseriesOptions.init(bson:)),
            validation: validation,
            viewOn: try bson["viewOn"]?.decode(as: String.self,
                with: Mongo.Collection.ID.init(_:)),
            writeConcern: try bson["writeConcern"]?.decode(
                as: BSON.Dictionary<ByteBufferView>.self,
                with: Mongo.WriteConcern.init(bson:)),
            pipeline: try bson["pipeline"]?.decode(
                as: BSON.Array<ByteBufferView>.self)
            {
                try $0.map
                {
                    .init([UInt8].init(
                        try $0.decode(to: BSON.Document<ByteBufferView>.self).bytes))
                }
            } ?? [],
            indexOptionDefaults: try bson["indexOptionDefaults"]?.decode(
                as: BSON.Document<ByteBufferView>.self)
            {
                .init([UInt8].init($0.bytes))
            },
            storageEngine: try bson["storageEngine"]?.decode(
                as: BSON.Document<ByteBufferView>.self)
            {
                .init([UInt8].init($0.bytes))
            })
    }
}
extension Mongo.CollectionOptions
{
    public
    var fields:BSON.Fields<[UInt8]>
    {
        var fields:BSON.Fields<[UInt8]> = 
        [
            "collation": .document(self.collation?.bson),
            "timeseries": .document(self.timeseries?.bson),
            "viewOn": .string(self.viewOn?.name),
            "writeConcern": .document(self.writeConcern?.bson),
            "pipeline": self.pipeline.isEmpty ? nil : 
                .tuple(.init(self.pipeline.lazy.map(BSON.Value<[UInt8]>.document(_:)))),
            "indexOptionDefaults": .document(self.indexOptionDefaults),
            "storageEngine": .document(self.storageEngine),
        ]
        if let cap:Mongo.CollectionCap = self.cap
        {
            fields.add(key: "capped", value: .bool(true))
            fields.add(key: "size", value: .int64(Int64.init(cap.size)))
            if let max:Int = cap.max
            {
                fields.add(key: "max", value: .int64(Int64.init(max)))
            }
        }
        if let validation:Mongo.CollectionValidation = self.validation
        {
            fields.add(key: "validator", value: .document(validation.validator))
            if validation.action != .error
            {
                fields.add(key: "validationAction", value: .string(validation.action.rawValue))
            }
            if validation.level != .strict
            {
                fields.add(key: "validationLevel", value: .string(validation.level.rawValue))
            }
        }
        return fields
    }
}
