import BSON

extension Mongo
{
    @frozen public
    struct Cap:Sendable
    {
        public
        let size:Int
        public
        let max:Int?

        @inlinable public
        init(size:Int, max:Int? = nil)
        {
            self.size = size
            self.max = max
        }
    }
    @frozen public
    struct Validation:Sendable
    {
        @frozen public
        enum Action:String, Sendable
        {
            case error
            case warn
        }
        @frozen public
        enum Level:String, Sendable
        {
            case moderate
            case strict
        }

        public
        let validator:BSON.Document<[UInt8]>
        public
        let action:Action
        public
        let level:Level

        @inlinable public
        init(validator:BSON.Document<[UInt8]>, action:Action = .error, level:Level = .strict)
        {
            self.validator = validator
            self.action = action
            self.level = level
        }
    }
    /// Explicitly creates a collection or view.
    ///
    /// > See:  https://www.mongodb.com/docs/manual/reference/command/create/
    @frozen public
    struct Create:Sendable
    {
        public
        let binding:Collection
        public
        let cap:Cap?
        public
        let collation:Collation?
        public
        let pipeline:[BSON.Document<[UInt8]>]
        public
        let validation:Validation?
        public
        let viewOn:Collection?
        public
        let writeConcern:WriteConcern?

        @inlinable public
        init(binding:Collection,
            cap:Cap? = nil,
            collation:Collation? = nil,
            pipeline:[BSON.Document<[UInt8]>] = [],
            validation:Validation? = nil,
            viewOn:Collection? = nil,
            writeConcern:WriteConcern? = nil)
        {
            self.binding = binding
            self.cap = cap
            self.collation = collation
            self.pipeline = pipeline
            self.validation = validation
            self.viewOn = viewOn
            self.writeConcern = writeConcern
        }
    }
}
extension Mongo.Create:DatabaseCommand
{
    public static
    let node:Mongo.Cluster.Role = .master
    
    public
    var fields:BSON.Fields<[UInt8]>
    {
        var fields:BSON.Fields<[UInt8]> = 
        [
            "create": .string(self.binding.name),
            "collation": (self.collation?.bson).map(BSON.Value<[UInt8]>.document(_:)),
            "pipeline": self.pipeline.isEmpty ? nil : 
                .tuple(.init(self.pipeline.lazy.map(BSON.Value<[UInt8]>.document(_:)))),
            "viewOn": (self.viewOn?.name).map(BSON.Value<[UInt8]>.string(_:)),
            "writeConcern": (self.writeConcern?.bson).map(BSON.Value<[UInt8]>.document(_:)),
        ]
        if let cap:Mongo.Cap = self.cap
        {
            fields.add(key: "capped", value: .bool(true))
            fields.add(key: "size", value: .int64(Int64.init(cap.size)))
            if let max:Int = cap.max
            {
                fields.add(key: "max", value: .int64(Int64.init(max)))
            }
        }
        if let validation:Mongo.Validation = self.validation
        {
            fields.add(key: "validator", value: .document(validation.validator))
            if validation.action != .error
            {
                fields.add(key: "validationAction", value: .string(validation.action.rawValue))
            }
            if validation.level != .strict
            {
                fields.add(key: "validationLevel", value: .string(validation.level.rawValue))
            }
        }
        return fields
    }
}
