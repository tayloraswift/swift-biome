import BSONDecoding
import MongoWire

extension Mongo
{
    @frozen public
    struct Instance
    {
        //  all instances:

        /// A boolean value that reports when this node is writable.
        ///
        /// If [`true`](), then this instance is a
        /// [primary](https://www.mongodb.com/docs/manual/reference/glossary/#std-term-primary)
        /// in a [replica set](https://www.mongodb.com/docs/manual/reference/glossary/#std-term-replica-set),
        /// or a [`mongos`](https://www.mongodb.com/docs/manual/reference/program/mongos/#mongodb-binary-bin.mongos) instance,
        /// or a standalone [`mongod`](https://www.mongodb.com/docs/manual/reference/program/mongod/#mongodb-binary-bin.mongod).
        ///
        /// This field will be [`false`]() if the instance is a
        /// [secondary](https://www.mongodb.com/docs/manual/reference/glossary/#std-term-secondary)
        /// member of a replica set or if the member is an
        /// [arbiter](https://www.mongodb.com/docs/manual/reference/glossary/#std-term-arbiter)
        /// of a replica set.
        public
        let isWritablePrimary:Bool

        /// The maximum permitted size of a BSON object in bytes for this
        /// [mongod](https://www.mongodb.com/docs/manual/reference/program/mongod/#mongodb-binary-bin.mongod)
        /// process.
        public
        let maxBsonObjectSize:Int

        /// The maximum permitted size of a BSON wire protocol message. 
        public
        let maxMessageSizeBytes:Int

        /// The maximum number of write operations permitted in a write batch.
        public
        let maxWriteBatchSize:Int

        /// Returns the local server time in UTC. This value is an
        /// [ISO date](https://www.mongodb.com/docs/manual/reference/glossary/#std-term-ISODate).
        public
        let localTime:BSON.Millisecond

        /// The time in minutes that a
        /// [session](https://www.mongodb.com/docs/manual/core/read-isolation-consistency-recency/#std-label-sessions)
        /// remains active after its most recent use. Sessions that have not received
        /// a new read/write operation from the client or been refreshed with
        /// [`refreshSessions`](https://www.mongodb.com/docs/manual/reference/command/refreshSessions/#mongodb-dbcommand-dbcmd.refreshSessions)
        /// within this threshold are cleared from the cache. State associated with
        /// an expired session may be cleaned up by the server at any time.
        public
        let logicalSessionTimeoutMinutes:Minutes

        /// An identifier for the `mongod`/`mongos` instance's outgoing connection
        /// to the client.
        /// This is called `connectionId` in the server reply.
        public
        let connection:ConnectionIdentifier

        /// The range of versions of the wire protocol that this `mongod` or `mongos`
        /// instance is capable of using to communicate with clients.
        /// This is called `minWireVersion` and `maxWireVersion` in the server reply.
        public
        let wireVersions:ClosedRange<MongoWire>

        /// A boolean value that, when true, indicates that the `mongod` or `mongos`
        /// instance is running in read-only mode.
        /// This is called `readOnly` in the server reply.
        public
        let isReadOnly:Bool

        /// An array of SASL mechanisms used to create the user's credential or credentials.
        public
        let saslSupportedMechs:Set<Authentication.SASL>?

        /// Fields present when the server is a sharded instance.
        /// There are no such fields, so this property is only useful for
        /// determining if an instance is sharded or not.
        public
        let sharded:Sharded?

        /// Fields present when the server is a member of a replica set.
        public
        let set:ReplicaSet?
    }
}
extension Mongo.Instance:BSONDictionaryDecodable
{
    public
    init<Bytes>(bson:BSON.Dictionary<Bytes>) throws
    {
        self.isWritablePrimary = try bson["isWritablePrimary"].decode(to: Bool.self)

        self.maxBsonObjectSize = try bson["maxBsonObjectSize"]?.decode(
            to: Int.self) ?? 16 * 1024 * 1024
        self.maxMessageSizeBytes = try bson["maxMessageSizeBytes"]?.decode(
            to: Int.self) ?? 48_000_000
        self.maxWriteBatchSize = try bson["maxWriteBatchSize"]?.decode(
            to: Int.self) ?? 100_000
        
        self.localTime = try bson["localTime"].decode(to: BSON.Millisecond.self)
        self.logicalSessionTimeoutMinutes = try bson["logicalSessionTimeoutMinutes"].decode(
            to: Mongo.Minutes.self)
        
        self.connection = try bson["connectionId"].decode(
            to: Mongo.ConnectionIdentifier.self)
        
        let minWireVersion:MongoWire = try bson["minWireVersion"].decode(as: Int32.self,
            with: MongoWire.init(rawValue:))
        let maxWireVersion:MongoWire = try bson["maxWireVersion"].decode(as: Int32.self,
            with: MongoWire.init(rawValue:))
        
        guard minWireVersion <= maxWireVersion
        else
        {
            fatalError("unimplemented: server returned inverted wire version bounds!")
        }
        self.wireVersions = minWireVersion ... maxWireVersion

        self.isReadOnly = try bson["readOnly"].decode(to: Bool.self)

        self.saslSupportedMechs = try bson["saslSupportedMechs"]?.decode(
            to: Set<Mongo.Authentication.SASL>.self)

        self.sharded = try bson["msg"]?.decode(as: String.self)
        {
            if $0 == "isdbgrid"
            {
                return .init()
            }
            else
            {
                fatalError("unimplemented: server returned invalid 'msg' value ('\($0)')!")
            }
        }
        self.set = try .init(from: bson)
    }
}
