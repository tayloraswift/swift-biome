extension Mongo.Cluster
{
    struct Hosts
    {
        private(set)
        var undiscovered:Set<Mongo.Host>
        private(set)
        var discovered:Set<Mongo.Host>
        var blacklist:Set<Mongo.Host>
    }
}
extension Mongo.Cluster.Hosts
{
    init(_ hosts:some Sequence<Mongo.Host>)
    {
        self.undiscovered = .init(hosts)
        self.discovered = []
        self.blacklist = []
    }

    mutating
    func update(with host:Mongo.Host)
    {
        if  self.discovered.contains(host)
        {
            return
        }
        else
        {
            self.blacklist.remove(host)
            self.undiscovered.update(with: host)
        }
    }
    mutating
    func checkout() -> Mongo.Host?
    {
        if let host:Mongo.Host = self.undiscovered.popFirst()
        {
            self.discovered.insert(host)
            return host
        }
        else
        {
            return nil
        }
    }
    mutating
    func checkin(_ host:Mongo.Host)
    {
        self.discovered.remove(host)
        self.undiscovered.update(with: host)
    }
    mutating
    func blacklist(_ host:Mongo.Host)
    {
        self.discovered.remove(host)
        self.blacklist.update(with: host)
    }
}
