import NIOCore
@preconcurrency import DNSClient

extension DNSClient
{
    fileprivate
    func resolveSRV(_ host:Mongo.Host) async throws -> [Mongo.Host] 
    {
        let records:[ResourceRecord<SRVRecord>] = 
            try await self.getSRVRecords(from: "_mongodb._tcp.\(host.name)").get()
        return records.map 
        { 
            .init($0.resource.domainName.string, host.port)
        }
    }
}

extension Mongo.Cluster
{
    public
    struct ConnectivityError:Error, Sendable
    {
        public
        let role:Role
        public
        let errors:[any Error]
    }
}
extension Mongo.Cluster.ConnectivityError:CustomStringConvertible
{
    public
    var description:String
    {
        var description:String =
        """
        Could not connect to any hosts matching role '\(self.role)'!
        """
        if !self.errors.isEmpty
        {
            description +=
            """

            Note: Some hosts could not be reached because:
            """
            for (ordinal, error):(Int, any Error) in self.errors.enumerated()
            {
                description +=
                """

                \(ordinal). \(error)
                """
            }
        }
        return description
    }
}

extension Mongo
{
    public 
    actor Cluster
    {
        private 
        let group:any EventLoopGroup,
            dns:DNSClient?
        private
        let settings:ConnectionSettings

        /// A list of currently open connections.
        private 
        var pool:ConnectionPool

        /// The minimum observed wire version among this cluster’s nodes. 
        /// This is [`nil`]() until the first node has been contacted.
        public private(set) 
        var version:WireVersion?

        private 
        var sessions:SessionPool
        private 
        var hosts:Hosts

        private 
        init(settings:ConnectionSettings, hosts:[Mongo.Host], group:any EventLoopGroup, dns:DNSClient?) 
        {
            self.version = nil

            self.sessions = .init()
            self.hosts = .init(hosts)
            self.pool = .init()

            self.settings = settings
            self.group = group
            self.dns = dns
        }

        deinit
        {
            self.pool.removeAll()
        }
    }
}
extension Mongo.Cluster
{
    public 
    init(settings:Mongo.ConnectionSettings, hosts:Mongo.ConnectionString.Hosts,
        group:any EventLoopGroup,
        dnsServer:String? = nil) async throws 
    {
        switch hosts
        {
        case .srv(let host):
            let dns:DNSClient
            if let server:String = dnsServer 
            {
                dns = try await DNSClient.connect(on: group, host: server).get()
            } 
            else 
            {
                dns = try await DNSClient.connect(on: group).get()
            }
            self.init(settings: settings, hosts: try await dns.resolveSRV(host),
                group: group,
                dns: dns)
        
        case .standard(let hosts):
            assert(!hosts.isEmpty)

            self.init(settings: settings, hosts: hosts,
                group: group,
                dns: nil)
        }
        
        _ = try await self.next(.master)
    }

    public
    func start<Command>(for _:Command.Type) async throws -> Mongo.Session
        where Command:SessionCommand
    {
        let connection:Mongo.Connection = try await self.next(Command.node)
        let session:Mongo.Session.ID = self.sessions.obtain()
        return .init(connection: connection, cluster: self, id: session)
    }

    func update(session:Mongo.Session.ID, timeout:ContinuousClock.Instant)
    {
        self.sessions.update(session, timeout: timeout)
    }
    func release(session:Mongo.Session.ID)
    {
        self.sessions.release(session)
    }
}
extension Mongo.Cluster
{
    private
    func next(_ role:Role) async throws -> Mongo.Connection
    {
        // look for existing connections
        for (_, connection):(Mongo.Host, Mongo.Connection) in self.pool.connections
            where role.matches(connection)
        {
            return connection
        }
        // form new connections
        var errors:[any Error] = []
        while let host:Mongo.Host = self.hosts.checkout()
        {
            let connection:Mongo.Connection
            do
            {
                connection = try await self.connect(to: host)
            }
            catch let error
            {
                errors.append(error)
                self.hosts.blacklist(host)
                continue
            }
            if role.matches(connection)
            {
                return connection
            }
        }
        throw ConnectivityError.init(role: role, errors: errors)
    }
    private 
    func connect(to host:Mongo.Host) async throws -> Mongo.Connection 
    {
        let connection:Mongo.Connection = try await .connect(to: host,
            settings: self.settings,
            group: group,
            dns: self.dns)
        
        self.register(connection, to: host)
        
        connection.closeFuture.whenComplete 
        { 
            [weak self, host] _ in

            if let cluster:Mongo.Cluster = self 
            { 
                Task.init
                {
                    await cluster.unregister(connectionTo: host)
                }
            }
        }
        
        return connection
    }
    private
    func register(_ connection:Mongo.Connection, to host:Mongo.Host)
    {
        let handshake:ServerHandshake = connection.handshake
        /// Ensures we default to the cluster's lowest version
        if  let version:WireVersion = self.version
        {
            self.version = min(handshake.maxWireVersion, version)
        } 
        else 
        {
            self.version = handshake.maxWireVersion
        }

        self.pool.add(host: host, connection: connection)
        
        for string:String in [handshake.hosts ?? [], handshake.passives ?? []].joined() 
        {
            self.hosts.update(with: .mongodb(parsing: string))
        }
    }
    private
    func unregister(connectionTo host:Mongo.Host)
    {
        self.pool.remove(host: host)
        self.hosts.checkin(host)
    }
}

extension Mongo.Cluster
{
    // private
    // func rediscover() async 
    // {
    //     self.version = nil
    //     var blacklist:[Mongo.Host] = []
    //     for (host, connection):(Mongo.Host, Mongo.Connection) in self.pool
    //     {
    //         if  let connection:Mongo.Connection = try? await connection.reestablish(
    //                 authentication: self.settings.authentication)
    //         {
    //             self.register(connection, to: host)
    //         }
    //         else 
    //         {
    //             self.hosts.blacklist(host)
    //             blacklist.append(host)
    //         }
    //     }
    //     self.hosts.blacklist = []
    //     for host:Mongo.Host in blacklist
    //     {
    //         self.pool.removeValue(forKey: host)
    //     }
    // }

    /// Closes all connections, and stops polling for cluster changes.
    ///
    /// - Warning: Any outstanding query results may be cancelled, but the sent query might still be executed.
    // public 
    // func disconnect() async throws
    // {
    //     self.wireVersion = nil
    //     self.isClosed = true
    //     let connections = self.pool
    //     self.pool = []
    //     //self.discoveredHosts = []

    //     for pooledConnection in connections {
    //         try await pooledConnection.connection.close()
    //     }
    // }
}

extension Mongo.Cluster
{
    @discardableResult
    public
    func run<Command>(command:Command) async throws -> Command.Success
        where Command:AdministrativeCommand
    {    
        try await self.start(for: Command.self).run(command: command)
    }
    @discardableResult
    public
    func run<Command>(command:Command, 
        against database:Mongo.Database) async throws -> Command.Success
        where Command:DatabaseCommand
    {    
        try await self.start(for: Command.self).run(command: command, against: database)
    }
}
