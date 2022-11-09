import BSON

extension Mongo
{
    struct Hello:Sendable
    {
        let user:User?

        init(user:User?) 
        {
            self.user = user
        }
    }
}
extension Mongo.Hello
{
    private static
    var os:String
    {
        #if os(Linux)
        "Linux"
        #elseif os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        "Darwin"
        #elseif os(Windows)
        "Windows"
        #else
        "unknown"
        #endif
    }
    private static
    var client:BSON.Document<[UInt8]>
    {
        [
            "driver":
            [
                "name": "_BiomeMongoKitten",
                "version": "0",
            ],
            "os":
            [
                "type": .string(Self.os),
            ],
        ]
    }
}
extension Mongo.Hello:MongoCommand
{
    typealias Response = Mongo.Instance
    
    var fields:BSON.Fields<[UInt8]>
    {
        [
            "hello": true,
            "client": .document(Self.client),

            "saslSupportedMechs":
                (self.user?.description).map(BSON.Value<[UInt8]>.string(_:))
        ]
    }
}
