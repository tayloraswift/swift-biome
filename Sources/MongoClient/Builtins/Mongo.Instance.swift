import NIOCore
import BSONDecoding
import BSONEncoding

extension Mongo.Instance
{
    /// Fields present when the server is a sharded instance. There are no fields
    /// of interest, so this structure is completely empty.
    @frozen public
    struct Sharded
    {
    }
}
extension Mongo.Instance
{
    /// Fields present when the server is a member of a
    /// [replica set](https://www.mongodb.com/docs/manual/reference/glossary/#std-term-replica-set).
    @frozen public
    struct ReplicaSet
    {
        /// The name of the current replica set.
        /// This is called `setName` in the server reply.
        public
        let name:String

        /// The config version of the current replica set.
        /// This is called `setVersion` in the server reply.
        public
        let version:String

        /// The member of the replica set that returned this response.
        public
        let me:Mongo.Host

        /// The current
        /// [primary](https://www.mongodb.com/docs/manual/reference/glossary/#std-term-primary)
        /// member of the replica set.
        public
        let primary:Mongo.Host

        /// The list of all members of the replica set that are
        /// [arbiters](https://www.mongodb.com/docs/manual/reference/glossary/#std-term-arbiter).
        public
        let arbiters:[Mongo.Host]

        /// The list of all members of the replica set which have a
        /// [priority](https://www.mongodb.com/docs/manual/reference/replica-configuration/#mongodb-rsconf-rsconf.members-n-.priority)
        /// of 0.
        public
        let passives:[Mongo.Host]

        /// The list of all members of the replica set that are neither
        /// [hidden](https://www.mongodb.com/docs/manual/reference/glossary/#std-term-hidden-member),
        /// [passive](https://www.mongodb.com/docs/manual/reference/glossary/#std-term-passive-member),
        /// nor [arbiters](https://www.mongodb.com/docs/manual/reference/glossary/#std-term-arbiter).
        public
        let hosts:[Mongo.Host]

        /// This is called `arbiterOnly` in the server reply.
        public
        let isArbiter:Bool

        /// This is called `passive` in the server reply.
        public
        let isPassive:Bool

        /// This is called `hidden` in the server reply.
        public
        let isHidden:Bool

        /// Indicates if the `mongod` is a
        /// [secondary](https://www.mongodb.com/docs/manual/reference/glossary/#std-term-secondary)
        /// member of a replica set.
        /// This is called `secondary` in the server reply.
        public
        let isSecondary:Bool

        /// This is called ``electionId` in the server reply.
        public
        let election:BSON.Identifier?

        /// Unimplemented.
        ///
        /// This document has dedicated storage to permit deallocating the original
        /// ``ByteBufferView``.
        public
        let tags:BSON.Document<[UInt8]>

        // TODO
        // public
        // let lastWrite:Never
    }
}
extension Mongo.Instance.ReplicaSet
{
    public
    init?(from bson:BSON.Dictionary<ByteBufferView>) throws
    {
        guard let name:String = try bson["setName"]?.decode(to: String.self)
        else
        {
            return nil
        }

        self.name = name
        self.version = try bson["setVersion"].decode(to: String.self)

        self.me = try bson["me"].decode(as: String.self,
            with: Mongo.Host.mongodb(parsing:))
        
        self.primary = try bson["primary"].decode(as: String.self,
            with: Mongo.Host.mongodb(parsing:))
        
        self.arbiters = try bson["arbiters"]?.decode(as: BSON.Array<ByteBufferView>.self)
        {
            try $0.map
            {
                try $0.decode(as: String.self, with: Mongo.Host.mongodb(parsing:))
            }
        } ?? []

        self.passives = try bson["passives"]?.decode(as: BSON.Array<ByteBufferView>.self)
        {
            try $0.map
            {
                try $0.decode(as: String.self, with: Mongo.Host.mongodb(parsing:))
            }
        } ?? []

        self.hosts = try bson["hosts"].decode(as: BSON.Array<ByteBufferView>.self)
        {
            try $0.map
            {
                try $0.decode(as: String.self, with: Mongo.Host.mongodb(parsing:))
            }
        }

        self.isSecondary = try bson["secondary"]?.decode(to: Bool.self) ?? false
        self.isArbiter = try bson["arbiterOnly"]?.decode(to: Bool.self) ?? false
        self.isPassive = try bson["passive"]?.decode(to: Bool.self) ?? false
        self.isHidden = try bson["hidden"]?.decode(to: Bool.self) ?? false

        self.election = try bson["electionId"]?.decode(to: BSON.Identifier.self)

        // copy to dedicated storage.
        let tags:BSON.Document<ByteBufferView> = try bson["tags"].decode(
            to: BSON.Document<ByteBufferView>.self)
        self.tags = .init([UInt8].init(tags.bytes))
    }
}
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
        let logicalSessionTimeoutMinutes:Int

        /// An identifier for the `mongod`/`mongos` instance's outgoing connection
        /// to the client.
        /// This is called `connectionId` in the server reply.
        public
        let connection:Mongo.ConnectionIdentifier

        /// The range of versions of the wire protocol that this `mongod` or `mongos`
        /// instance is capable of using to communicate with clients.
        /// This is called `minWireVersion` and `maxWireVersion` in the server reply.
        public
        let wireVersions:ClosedRange<Mongo.WireVersion>

        /// A boolean value that, when true, indicates that the `mongod` or `mongos`
        /// instance is running in read-only mode.
        /// This is called `readOnly` in the server reply.
        public
        let isReadOnly:Bool

        /// An array of SASL mechanisms used to create the user's credential or credentials.
        public
        let saslSupportedMechs:[SASL.Mechanism]?

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
extension Mongo.Instance:MongoResponse
{
    public
    init(from bson:BSON.Dictionary<ByteBufferView>) throws
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
            to: Int.self)
        
        self.connection = try bson["connectionId"].decode(as: Int32.self,
            with: Mongo.ConnectionIdentifier.init(_:))
        
        let minWireVersion:Mongo.WireVersion = try bson["minWireVersion"].decode(as: Int32.self,
            with: Mongo.WireVersion.init(rawValue:))
        let maxWireVersion:Mongo.WireVersion = try bson["maxWireVersion"].decode(as: Int32.self,
            with: Mongo.WireVersion.init(rawValue:))
        
        guard minWireVersion <= maxWireVersion
        else
        {
            fatalError("unimplemented: server returned inverted wire version bounds!")
        }
        self.wireVersions = minWireVersion ... maxWireVersion

        self.isReadOnly = try bson["readOnly"].decode(to: Bool.self)

        // TODO
        self.saslSupportedMechs = nil

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
