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
                if case true? = connection.handshake.readOnly
                {
                    return false
                }
                if !connection.handshake.ismaster
                {
                    return false
                }
            }
            return true
        }
    }
}
