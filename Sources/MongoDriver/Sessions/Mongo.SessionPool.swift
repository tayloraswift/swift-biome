extension Mongo
{
    private
    struct SessionMetadata
    {
        /// The instant of time at which the driver believes the associated
        /// session is likely to time out.
        var timeout:ContinuousClock.Instant
    }
}
extension Mongo
{
    struct SessionPool
    {
        private
        var available:[Session.ID: SessionMetadata]
        private
        var claimed:[Session.ID: SessionMetadata]

        init()
        {
            self.available = [:]
            self.claimed = [:]
        }
    }
}
extension Mongo.SessionPool
{
    mutating
    func checkout() -> Mongo.Session.ID
    {
        let now:ContinuousClock.Instant = .now
        while case let (session, metadata)? = self.available.popFirst()
        {
            if now < metadata.timeout
            {
                self.claimed.updateValue(metadata, forKey: session)
                return session
            }
        }
        // very unlikely, but do not generate a session id that we have
        // already generated. this is not foolproof (because we could
        // have persistent sessions from a previous run), but allows us
        // to maintain local dictionary invariants.
        while true
        {
            let session:Mongo.Session.ID = .random()
            if  !self.available.keys.contains(session),
                !self.claimed.keys.contains(session)
            {
                self.claimed.updateValue(.init(timeout: now), forKey: session)
                return session
            }
        }
    }
    mutating
    func extend(_ session:Mongo.Session.ID, timeout:ContinuousClock.Instant)
    {
        guard case ()? = self.claimed[session]?.timeout = timeout
        else
        {
            fatalError("unreachable: retained an unknown session! (\(session))")
        }
    }
    mutating
    func checkin(_ session:Mongo.Session.ID)
    {
        guard let metadata:Mongo.SessionMetadata = self.claimed.removeValue(forKey: session)
        else
        {
            fatalError("unreachable: released an unknown session! (\(session))")
        }
        guard case nil = self.available.updateValue(metadata, forKey: session)
        else
        {
            fatalError("unreachable: released an duplicate session! (\(session))")
        }
    }
}
