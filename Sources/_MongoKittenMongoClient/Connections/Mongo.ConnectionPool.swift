extension Mongo
{
    struct ConnectionPool
    {
        private(set)
        var connections:[Host: Connection]

        init()
        {
            self.connections = [:]
        }
    }
}
extension Mongo.ConnectionPool
{
    mutating
    func add(host:Mongo.Host, connection:Mongo.Connection)
    {
        guard case nil = self.connections.updateValue(connection, forKey: host)
        else
        {
            fatalError("unreachable: added a connection to a pool more than once!")
        }
    }
    mutating
    func remove(host:Mongo.Host)
    {
        if let connection:Mongo.Connection = self.connections.removeValue(forKey: host)
        {
            connection.close()
        }
    }
    mutating
    func removeAll()
    {
        for connection:Mongo.Connection in self.connections.values
        {
            connection.close()
        }
        self.connections = [:]
    }
}
