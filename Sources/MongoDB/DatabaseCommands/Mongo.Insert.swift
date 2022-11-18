import BSONEncoding

extension Mongo
{
    /// Inserts one or more documents and returns a document containing the
    /// status of all inserts.
    ///
    /// > See:  https://www.mongodb.com/docs/manual/reference/command/insert/
    @frozen public
    struct Insert<Elements>:Sendable
        where Elements:Sequence & Sendable, Elements.Element:MongoEncodable
    {
        public
        let collection:Collection.ID
        public
        let elements:Elements

        public
        let bypassDocumentValidation:Bool
        public
        let ordered:Bool
        public
        let writeConcern:WriteConcern?

        @inlinable public
        init(collection:Collection.ID, elements:Elements,
            bypassDocumentValidation:Bool = false,
            ordered:Bool = true,
            writeConcern:WriteConcern? = nil)
        {
            self.collection = collection
            self.elements = elements

            self.bypassDocumentValidation = bypassDocumentValidation
            self.ordered = ordered
            self.writeConcern = writeConcern
        }
    }
}
extension Mongo.Insert:MongoDatabaseCommand
{
    @inlinable public static
    var node:Mongo.InstanceSelector
    {
        .master
    }
    
    @inlinable public
    var fields:BSON.Fields<[UInt8]>
    {
        [
            "insert":
                .string(self.collection.name),
            "documents":
                .tuple(BSON.Tuple<[UInt8]>.init(self.elements.lazy.map
            {
                .document($0.bson)
            })),
            "bypassDocumentValidation":
                .bool(self.bypassDocumentValidation ? true : nil),
            "ordered":
                .bool(self.ordered ? nil : false),
            "writeConcern":
                .document(self.writeConcern?.bson),
        ]
    }

    public
    typealias Response = Mongo.InsertResponse
}
