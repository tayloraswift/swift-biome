extension Mongo
{
    @frozen public
    enum InstanceSelector:Sendable
    {
        case master
        case any
    }
}
extension Mongo.InstanceSelector
{
    static
    func ~= (self:Self, instance:Mongo.Instance) -> Bool
    {
        if case .master = self
        {
            if  instance.isReadOnly
            {
                return false
            }
            if !instance.isWritablePrimary
            {
                return false
            }
        }
        return true
    }
}
