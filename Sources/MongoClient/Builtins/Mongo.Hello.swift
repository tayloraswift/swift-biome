import BSONEncoding

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
}
extension Mongo.Hello:MongoCommand
{
    typealias Response = Mongo.Instance
    
    var fields:BSON.Fields<[UInt8]>
    {
        [
            "hello": true,
            "client":
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
            ],
            "saslSupportedMechs": self.user?.bson
        ]
    }
}
