import BSON

extension Mongo
{
    struct IsMaster 
    {
        let user:User?

        init(user:User?) 
        {
            self.user = user
        }
    }
}
extension Mongo.IsMaster:MongoCommand
{
    var bson:Document
    {
        var bson:Document = 
        [
            "isMaster": 1,
            "client": Self.client,
        ]
        if let user:String = self.user?.description
        {
            bson.appendValue(user, forKey: "saslSupportedMechs")
        }
        return bson
    }

    static
    func decode(reply:OpMessage) throws -> ServerHandshake
    {
        if let document:Document = reply.first
        {
            return try BSONDecoder().decode(ServerHandshake.self, from: document)
        }
        else
        {
            throw MongoCommandError.emptyReply
        }
    }
}
extension Mongo.IsMaster
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
    var client:Document
    {
        [
            "driver":
            [
                "name": "_BiomeMongoKitten",
                "version": "0",
            ] as Document,
            "os":
            [
                "type": Self.os,
            ] as Document,
        ]
    }
}
