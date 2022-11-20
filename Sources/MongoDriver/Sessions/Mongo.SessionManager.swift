extension Mongo
{
    class SessionManager
    {
        // TODO: implement time gossip
        private
        let cluster:Mongo.Cluster
        let id:Session.ID

        private
        init(cluster:Mongo.Cluster, id:Session.ID)
        {
            self.cluster = cluster
            self.id = id
        }
        func extend(timeout:ContinuousClock.Instant)
        {
            Task.init
            {
                [id] in await self.cluster.extendSession(id, timeout: timeout)
            }
        }
        deinit
        {
            Task.init
            {
                [id, cluster] in await cluster.releaseSession(id)
            }
        }
    }
}
extension Mongo.SessionManager
{
    convenience
    init(cluster:Mongo.Cluster) async
    {
        self.init(cluster: cluster, id: await cluster.startSession())
    }
}
