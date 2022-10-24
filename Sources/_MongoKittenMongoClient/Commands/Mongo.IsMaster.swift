import BSON

extension Mongo
{
    struct IsMaster 
    {
        let userNamespace:String?

        init(userNamespace:String?) 
        {
            self.userNamespace = userNamespace
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
        if let userNamespace:String = self.userNamespace
        {
            bson.appendValue(userNamespace, forKey: "saslSupportedMechs")
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
