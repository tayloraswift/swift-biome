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
        let validator:Document
        public
        let action:Action
        public
        let level:Level

        @inlinable public
        init(validator:Document, action:Action = .error, level:Level = .strict)
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
        let pipeline:[Document]
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
            pipeline:[Document] = [],
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
    let color:MongoCommandColor = .mutating
    
    public
    var bson:Document
    {
        var bson:Document = 
        [
            "create": self.binding.name,
        ]
        if let cap:Mongo.Cap = self.cap
        {
            bson.appendValue(true, forKey: "capped")
            bson.appendValue(cap.size, forKey: "size")
            if let max:Int = cap.max
            {
                bson.appendValue(max, forKey: "max")
            }
        }
        if let collation:Mongo.Collation = self.collation
        {
            bson.appendValue(collation.bson, forKey: "collation")
        }
        if !self.pipeline.isEmpty
        {
            bson.appendValue(self.pipeline, forKey: "pipeline")
        }
        if let validation:Mongo.Validation = self.validation
        {
            bson.appendValue(validation.validator, forKey: "validator")
            if validation.action != .error
            {
                bson.appendValue(validation.action.rawValue, forKey: "validationAction")
            }
            if validation.level != .strict
            {
                bson.appendValue(validation.level.rawValue, forKey: "validationLevel")
            }
        }
        if let viewOn:Mongo.Collection = self.viewOn
        {
            bson.appendValue(viewOn.name, forKey: "viewOn")
        }
        if let writeConcern:Mongo.WriteConcern = self.writeConcern
        {
            bson.appendValue(writeConcern.bson, forKey: "writeConcern")
        }
        return bson
    }
}