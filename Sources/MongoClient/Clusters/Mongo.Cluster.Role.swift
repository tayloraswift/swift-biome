extension Mongo.Cluster
{
    @frozen public
    enum Role:Sendable
    {
        case master
        case any

        func matches(_ connection:Mongo.Connection) -> Bool
        {
            if case .master = self
            {
                if  connection.instance.isReadOnly
                {
                    return false
                }
                if !connection.instance.isWritablePrimary
                {
                    return false
                }
            }
            return true
        }
    }
}
