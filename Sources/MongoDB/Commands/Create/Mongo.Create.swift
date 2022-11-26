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
            variant:Variant = .collection())
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
    func encode(to bson:inout BSON.Fields)
    {
        bson["create"] = self.collection
        bson["collation"] = self.collation
        bson["writeConcern"] = self.writeConcern
        bson["indexOptionDefaults", elide: true] = self.indexOptionDefaults
        bson["storageEngine", elide: true] = self.storageEngine

        switch self.variant
        {
        case .collection(cap: let cap,
            validationAction: let action,
            validationLevel: let level,
            validator: let validator):

            if let cap:Mongo.Cap
            {
                bson["capped"] = true
                bson["size"] = cap.size
                bson["max"] = cap.max
            }

            bson["validator", elide: true] = validator
            bson["validationAction"] = action
            bson["validationLevel"] = level
        
        case .timeseries(let timeseries):
            bson["timeseries"] = timeseries
        
        case .view(on: let collection, pipeline: let pipeline):
            // don’t elide pipeline, it should always be there
            bson["viewOn"] = collection
            bson["pipeline", elide: false] = pipeline
        }
    }
}
