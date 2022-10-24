extension Mongo
{
    struct SessionPool
    {
        private
        var available:[SessionIdentifier: ContinuousClock.Instant]
        private
        var claimed:[SessionIdentifier: ContinuousClock.Instant]

        init()
        {
            self.available = [:]
            self.claimed = [:]
        }
    }
}
extension Mongo.SessionPool
{
    private mutating
    func next(now:ContinuousClock.Instant) -> 
    (
        session:SessionIdentifier, 
        timeout:ContinuousClock.Instant
    )?
    {
        while case let (session, timeout)? = self.available.popFirst()
        {
            if now < timeout
            {
                return (session, timeout)
            }
        }
        return nil
    }
    mutating
    func obtain() -> SessionIdentifier
    {
        let now:ContinuousClock.Instant = .now
        let (session, timeout):(SessionIdentifier, ContinuousClock.Instant) = 
            self.next(now: now) ?? (._random, now)
        
        guard case nil = self.claimed.updateValue(timeout, forKey: session)
        else
        {
            fatalError("unreachable: obtained a duplicate session!")
        }
        print("obtained", session)
        return session
    }
    mutating
    func update(_ session:SessionIdentifier, timeout:ContinuousClock.Instant)
    {
        if  let index:Dictionary<SessionIdentifier, ContinuousClock.Instant>.Index = 
                self.claimed.index(forKey: session)
        {
            self.claimed.values[index] = timeout
        }
        else
        {
            fatalError("unreachable: retained an unknown session! (\(session))")
        }
    }
    mutating
    func release(_ session:SessionIdentifier)
    {
        guard let time:ContinuousClock.Instant = self.claimed.removeValue(forKey: session)
        else
        {
            fatalError("unreachable: released an unknown session! (\(session))")
        }
        guard case nil = self.available.updateValue(time, forKey: session)
        else
        {
            fatalError("unreachable: released an duplicate session! (\(session))")
        }
    }
}