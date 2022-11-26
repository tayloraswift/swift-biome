import BSONDecoding
import UUID

extension Mongo
{
    @frozen public
    struct CollectionMetadata:Sendable
    {
        public
        let collection:Collection
        public
        let options:Options
        public
        let info:Info

        @inlinable public
        init(collection:Collection, options:Options, info:Info)
        {
            self.collection = collection
            self.options = options
            self.info = info
        }
    }
}
extension Mongo.CollectionMetadata
{
    @inlinable public
    var name:String
    {
        self.collection.name
    }
    public
    var type:Mongo.CollectionType
    {
        self.options.variant.type
    }
}
extension Mongo.CollectionMetadata:BSONDictionaryDecodable
{
    @inlinable public
    init<Bytes>(bson:BSON.Dictionary<Bytes>) throws
    {
        self.init(
            collection: try bson["name"].decode(to: Mongo.Collection.self),
            options: try bson["options"].decode(as: BSON.Dictionary<Bytes.SubSequence>.self)
            {
                try .init(bson: $0, 
                    type: try bson["type"].decode(to: Mongo.CollectionType.self))
            },
            info: try bson["info"].decode(to: Info.self))
    }
}
