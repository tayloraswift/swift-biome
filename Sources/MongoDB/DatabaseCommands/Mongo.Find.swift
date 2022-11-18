import BSONEncoding

extension Mongo
{
    @frozen public
    struct Find<Element>:Sendable where Element:MongoDecodable
    {
        public
        let collection:Collection.ID
        public
        let batching:Batching
        public
        let timeout:Duration?
        public
        let tailing:Tailing?

        public
        let `let`:BSON.Document<[UInt8]>?
        public
        let filter:BSON.Document<[UInt8]>?
        public
        let sort:BSON.Document<[UInt8]>?
        public
        let projection:BSON.Document<[UInt8]>?

        public
        let skip:Int
        public
        let limit:Int

        public
        let collation:Collation?
        public
        let readConcern:ReadConcern?

        public
        let hint:IndexHint?
        public
        let min:BSON.Document<[UInt8]>?
        public
        let max:BSON.Document<[UInt8]>?
        public
        let returnKey:Bool
        public
        let showRecordIdentifier:Bool

        public
        init(collection:Collection.ID, returning batching:Batching,
            timeout:Duration? = nil,
            tailing:Tailing? = nil,
            `let`:BSON.Document<[UInt8]>? = nil,
            filter:BSON.Document<[UInt8]>? = nil,
            sort:BSON.Document<[UInt8]>? = nil,
            projection:BSON.Document<[UInt8]>? = nil,
            skip:Int = 0,
            limit:Int = 0,
            collation:Collation? = nil,
            readConcern:ReadConcern? = nil,
            hint:IndexHint? = nil,
            min:BSON.Document<[UInt8]>? = nil,
            max:BSON.Document<[UInt8]>? = nil,
            returnKey:Bool = false,
            showRecordIdentifier:Bool = false)
        {
            self.collection = collection
            self.batching = batching
            self.timeout = timeout
            self.tailing = tailing
            self.let = `let`
            self.filter = filter
            self.sort = sort
            self.projection = projection
            self.skip = skip
            self.limit = limit
            self.collation = collation
            self.readConcern = readConcern
            self.hint = hint
            self.min = min
            self.max = max
            self.returnKey = returnKey
            self.showRecordIdentifier = showRecordIdentifier
        }
    }
}
extension Mongo.Find
{
    var batchSize:Int64
    {
        switch self.batching
        {
        case .batch(of: let size), .batches(of: let size):
            return .init(size)
        }
    }
    var singleBatch:Bool
    {
        switch self.batching
        {
        case .batch:    return true
        case .batches:  return false
        }
    }
    var tailable:Bool
    {
        switch self.tailing
        {
        case _?:        return true
        case nil:       return false
        }
    }
    var awaitData:Bool
    {
        switch self.tailing
        {
        case .await:    return true
        default:        return false
        }
    }
}
extension Mongo.Find:MongoDatabaseCommand
{
    public static
    var node:Mongo.InstanceSelector
    {
        .any
    }
    
    public
    var fields:BSON.Fields<[UInt8]>
    {
        [
            "find":
                .string(self.collection.name),
            "batchSize":
                .int64(self.batchSize),
            "singleBatch":
                .bool(self.singleBatch ? true : nil),
            "maxTimeMS":
                .int64(self.timeout?.milliseconds),
            "tailable":
                .bool(self.tailable ? true : nil),
            "awaitData":
                .bool(self.awaitData ? true : nil),
            
            "let":
                .document(self.let),
            "filter":
                .document(self.filter),
            "sort":
                .document(self.sort),
            "projection":
                .document(self.projection),
            
            "skip":
                .int64(Int64.init(self.skip)),
            "limit":
                .int64(Int64.init(self.limit)),

            "collation":
                .document(self.collation?.bson),
            "readConcern":
                .document(self.readConcern?.bson),
            
            "hint":
                self.hint?.bson,
            "min":
                .document(self.min),
            "max":
                .document(self.max),
            
            "returnKey":
                .bool(self.returnKey ? true : nil),
            "showRecordId":
                .bool(self.showRecordIdentifier ? true : nil),
        ]
    }

    public
    typealias Response = Mongo.Cursor<Element>
}
