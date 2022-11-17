import BSON

extension Mongo
{
    @frozen public
    struct CollectionValidation:Sendable
    {
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
}
extension Mongo.CollectionValidation
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
}
