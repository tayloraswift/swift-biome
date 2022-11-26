import BSONEncoding

extension Mongo
{
    /// Explicitly creates a collection or view.
    ///
    /// > See:  https://www.mongodb.com/docs/manual/reference/command/create/
    public
    struct Create:Sendable
    {
        public
        let collection:Collection
        
        public
        let collation:Collation?
        public
        let writeConcern:WriteConcern?
        public
        let indexOptionDefaults:StorageConfiguration?
        public
        let storageEngine:StorageConfiguration?

        public
        let variant:Variant

        public
        init(collection:Collection,
            collation:Collation? = nil,
            writeConcern:WriteConcern? = nil,
            indexOptionDefaults:StorageConfiguration? = nil,
            storageEngine:StorageConfiguration? = nil,
            variant:Variant)
        {
            self.collection = collection
            self.collation = collation
            self.writeConcern = writeConcern
            self.indexOptionDefaults = indexOptionDefaults
            self.storageEngine = storageEngine
            self.variant = variant
        }
    }
}

extension Mongo.Create:MongoDatabaseCommand, MongoImplicitSessionCommand
{
    public static
    let node:Mongo.InstanceSelector = .master
    
    public
    var fields:BSON.Fields<[UInt8]>
    {
        var fields:BSON.Fields<[UInt8]> = 
        [
            "create":
                .string(self.collection.name),
            "collation":
                .document(self.collation?.bson),
            "writeConcern":
                .document(self.writeConcern?.bson),
            "indexOptionDefaults":
                .document(self.indexOptionDefaults?.bson),
            "storageEngine":
                .document(self.storageEngine?.bson),
        ]
        switch self.variant
        {
        case .collection(cap: let cap,
            validationAction: let action,
            validationLevel: let level,
            validator: let validator):

            if let cap:Mongo.Cap
            {
                fields.add(key: "capped", value: .bool(true))
                fields.add(key: "size", value: .int64(Int64.init(cap.size)))
                if let max:Int = cap.max
                {
                    fields.add(key: "max", value: .int64(Int64.init(max)))
                }
            }
            if let validator:BSON.Document<[UInt8]>
            {
                fields.add(key: "validator", value: .document(validator))
            }
            if let action:Mongo.ValidationAction
            {
                fields.add(key: "validationAction", value: .string(action.rawValue))
            }
            if let level:Mongo.ValidationLevel
            {
                fields.add(key: "validationLevel", value: .string(level.rawValue))
            }
        
        case .timeseries(let timeseries):
            fields.add(key: "timeseries", value: .document(timeseries.bson))
        
        case .view(on: let collection, pipeline: let pipeline):
            fields.add(key: "viewOn", value: .string(collection.name))
            fields.add(key: "pipeline", value: .tuple(pipeline.lazy.map { BSON.Value[UInt8].document($0.bson) }))
        }
        return fields
    }
}
