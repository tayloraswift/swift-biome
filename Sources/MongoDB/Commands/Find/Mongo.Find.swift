import BSONEncoding

extension Mongo
{
    @frozen public
    struct Find<Element>:Sendable where Element:MongoDecodable
    {
        public
        let collection:Collection
        public
        let batching:Int
        public
        let timeout:Milliseconds?
        public
        let tailing:Tailing?

        public
        let `let`:Document?
        public
        let filter:Document?
        public
        let sort:Document?
        public
        let projection:Document?

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
        let min:Document?
        public
        let max:Document?
        public
        let returnKey:Bool?
        public
        let showRecordIdentifier:Bool?

        public
        init(collection:Collection, returning batching:Int,
            timeout:Milliseconds? = nil,
            tailing:Tailing? = nil,
            `let`:Document? = nil,
            filter:Document? = nil,
            sort:Document? = nil,
            projection:Document? = nil,
            skip:Int = 0,
            limit:Int = 0,
            collation:Collation? = nil,
            readConcern:ReadConcern? = nil,
            hint:IndexHint? = nil,
            min:Document? = nil,
            max:Document? = nil,
            returnKey:Bool? = nil,
            showRecordIdentifier:Bool? = nil)
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
    // var batchSize:Int64
    // {
    //     switch self.batching
    //     {
    //     case .batch(of: let size), .batches(of: let size):
    //         return .init(size)
    //     }
    // }
    // var singleBatch:Bool
    // {
    //     switch self.batching
    //     {
    //     case .batch:    return true
    //     case .batches:  return false
    //     }
    // }
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
extension Mongo.Find:MongoStreamableCommand
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
                .int64(Int64.init(self.batching)),
            // "singleBatch":
            //     .bool(self.singleBatch ? true : nil),
            "maxTimeMS":
                .int64(self.timeout?.rawValue),
            "tailable":
                .bool(self.tailable ? true : nil),
            "awaitData":
                .bool(self.awaitData ? true : nil),
            
            "let":
                .document(self.let?.bson),
            "filter":
                .document(self.filter?.bson),
            "sort":
                .document(self.sort?.bson),
            "projection":
                .document(self.projection?.bson),
            
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
                .document(self.min?.bson),
            "max":
                .document(self.max?.bson),
            
            "returnKey":
                .bool(self.returnKey),
            "showRecordId":
                .bool(self.showRecordIdentifier),
        ]
    }

    public
    typealias Response = Mongo.Cursor<Element>
}
