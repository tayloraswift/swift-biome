import BSONDecoding

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
        public
        let tags:BSON.Fields

        // TODO
        // public
        // let lastWrite:Never
    }
}
extension Mongo.Instance.ReplicaSet
{
    init?<Bytes>(from bson:BSON.Dictionary<Bytes>) throws
    {
        guard let name:String = try bson["setName"]?.decode(to: String.self)
        else
        {
            return nil
        }

        self.name = name
        self.version = try bson["setVersion"].decode(to: String.self)

        self.me = try bson["me"].decode(to: Mongo.Host.self)
        
        self.primary = try bson["primary"].decode(to: Mongo.Host.self)
        self.arbiters = try bson["arbiters"]?.decode(to: [Mongo.Host].self) ?? []
        self.passives = try bson["passives"]?.decode(to: [Mongo.Host].self) ?? []
        self.hosts = try bson["hosts"].decode(to: [Mongo.Host].self)

        self.isSecondary = try bson["secondary"]?.decode(to: Bool.self) ?? false
        self.isArbiter = try bson["arbiterOnly"]?.decode(to: Bool.self) ?? false
        self.isPassive = try bson["passive"]?.decode(to: Bool.self) ?? false
        self.isHidden = try bson["hidden"]?.decode(to: Bool.self) ?? false

        self.election = try bson["electionId"]?.decode(to: BSON.Identifier.self)

        self.tags = try bson["tags"].decode(to: BSON.Fields.self)
    }
}
