import NIO
import NIOConcurrencyHelpers
import Logging
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
extension ConnectionSettings
{
    fileprivate mutating
    func resolveSRV(on group:any EventLoopGroup) async throws -> DNSClient?
    {
        guard self.isSRV 
        else 
        {
            // not using DNS SRV
            return nil
        }

        guard let host:Mongo.Host = self.hosts.first
        else
        {
            fatalError("unreachable: `ConnectionSettings` structure contains at least one host")
        }

        let client:DNSClient
        if let server:String = self.dnsServer 
        {
            client = try await DNSClient.connect(on: group, host: server).get()
        } 
        else 
        {
            client = try await DNSClient.connect(on: group).get()
        }
        
        self.hosts = try await client.resolveSRV(host)
        return client
    }
}

extension Mongo.Cluster
{
    public
    enum ConnectionError:Error, Sendable
    {
        case noAvailableHosts(matching:Role)
        case closed
    }

    public
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

    fileprivate
    struct Hosts
    {
        private(set)
        var undiscovered:Set<Mongo.Host>
        private(set)
        var discovered:Set<Mongo.Host>
        private(set)
        var blacklist:Set<Mongo.Host>
    }
}
extension Mongo.Cluster.Hosts
{
    init(from settings:__shared ConnectionSettings)
    {
        self.undiscovered = .init(settings.hosts)
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

extension Mongo
{
    /// A high level ``MongoConnectionPool`` type tha is capable of "Service Discovery and Monitoring", automatically connects to new hosts. Is aware of a change in primary/secondary allocation.
    ///
    /// Use this type for connecting to MongoDB unless you have a very specific usecase.
    ///
    /// The ``MongoCluster`` uses ``MongoConnection`` instances under the hood to connect to specific servers, and run specific queries.s
    ///
    /// **Usage**
    ///
    /// ```swift
    /// let cluster = try await MongoCluster(
    ///     lazyConnectingTo: ConnectionSettings("mongodb://localhost")
    /// )
    /// let database = cluster["testapp"]
    /// let users = database["users"]
    /// ```
    public 
    actor Cluster
    {
        private 
        let group:any EventLoopGroup,
            metadata:ConnectionMetadata,
            dns:DNSClient?
        /// A list of currently open connections
        private 
        var pool:[Host: Connection]

        /// The minimum observed wire version among this cluster’s nodes. 
        /// This is [`nil`]() until the first node has been contacted.
        public private(set) 
        var version:WireVersion?

        /// If `true`, no connections will be opened and all existing connections will be shut down
        private 
        var isClosed:Bool

        /// Used as a shortcut to not have to set a callback on `isDiscovering`
        private 
        var completedInitialDiscovery:Bool = false
        private 
        var isDiscovering:Bool = false

        private 
        var sessions:SessionPool
        private 
        var hosts:Hosts

        private 
        init(settings:__shared ConnectionSettings, group:any EventLoopGroup, dns:DNSClient?) 
        {
            self.isClosed = false
            self.version = nil

            self.sessions = .init()
            self.hosts = .init(from: settings)
            self.pool = [:]

            self.metadata = .init(authentication: settings.authentication, 
                authenticationSource: settings.authenticationSource, 
                tls: settings.useSSL ? 
                    settings.sslCaCertificatePath.map(Mongo.ConnectionMetadata.TLS.init(certificatePath:)) : nil)
            self.group = group
            self.dns = dns
        }
        /// Connects to a cluster immediately, and awaits connection readiness.
        ///
        /// - Parameters:
        ///     - settings: The details used to set up a connection to, and authenticate with MongoDB
        ///     - allowFailure: If `true`, this method will always succeed - unless your settings are malformed.
        ///     - eventLoopGroup: If provided, an existing ``EventLoopGroup`` can be reused. By default, a new one will be created
        ///
        /// ```swift
        /// let cluster = try await MongoCluster(
        ///     connectingTo: ConnectionSettings("mongodb://localhost")
        /// )
        /// ```
        public 
        init(settings:ConnectionSettings, on group:any EventLoopGroup) async throws 
        {
            guard settings.hosts.count > 0 
            else 
            {
                throw MongoError(.cannotConnect, reason: .noHostSpecified)
            }

            var settings:ConnectionSettings = settings
            // Resolve SRV hostnames, if any
            let dns:DNSClient? = try await settings.resolveSRV(on: group)

            self.init(settings: settings, 
                group: group,
                dns: dns)
            
            _ = try await self.next(.master)
            
            // Establish initial connection
            scheduleDiscovery()

            // Check for connectivity
            if self.pool.count == 0 
            {
                throw MongoError(.cannotConnect, reason: .noAvailableHosts)
            }
        }
    }
}
extension Mongo.Cluster
{
    func update(session:SessionIdentifier, timeout:ContinuousClock.Instant)
    {
        self.sessions.update(session, timeout: timeout)
    }
    func release(session:SessionIdentifier)
    {
        self.sessions.release(session)
    }
}
extension Mongo.Cluster
{
    public
    func next(_ role:Role) async throws -> Mongo.Connection
    {
        if self.isClosed 
        {
            throw ConnectionError.closed
        }

        // look for existing connections
        for (_, connection):(Mongo.Host, Mongo.Connection) in self.pool
            where role.matches(connection)
        {
            return connection
        }
        // form new connections
        while let host:Mongo.Host = self.hosts.checkout()
        {
            let connection:Mongo.Connection
            do
            {
                connection = try await self.connect(to: host)
            }
            catch
            {
                self.hosts.blacklist(host)
                continue
            }
            if role.matches(connection)
            {
                return connection
            }
        }
        // if no undiscovered hosts exist we rediscover 
        // and update our list of undiscovered hosts
        // await self.rediscover()
        
        // TODO: we can potentially populate a host value from the 
        // updated undiscovered host list and continue execution below 
        // the guard statement instead of throwing an error
        throw ConnectionError.noAvailableHosts(matching: role)
    }
    private 
    func connect(to host:Mongo.Host) async throws -> Mongo.Connection 
    {
        let connection:Mongo.Connection = try await .connect(to: host, metadata: self.metadata,
            on: group,
            resolver: self.dns)
        
        self.register(connection, to: host)
        
        connection.channel.closeFuture.whenComplete 
        { 
            [weak self, host] _ in

            guard let cluster:Mongo.Cluster = self 
            else 
            { 
                return 
            }
            Task.init
            {
                await cluster.unregister(connectionTo: host)
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

        // add connection to pool
        guard case nil = self.pool.updateValue(connection, forKey: host)
        else
        {
            fatalError("unreachable: connected to the same host more than once!")
        }
        
        for string:String in [handshake.hosts ?? [], handshake.passives ?? []].joined() 
        {
            if let host:Mongo.Host = try? .init(parsing: string, srv: false)
            {
                self.hosts.update(with: host)
            }
        }
    }
    private
    func unregister(connectionTo host:Mongo.Host)
    {
        if let _:Mongo.Connection = self.pool.removeValue(forKey: host)
        {
            self.hosts.checkin(host)
            // `connection.channel` close handler should have canceled all queries
        }
        else
        {
            fatalError("unreachable: disconnected from the same host more than once!")
        }
    }
}
extension Mongo.Cluster
{
    public
    func start<Command>(for _:Command.Type) async throws -> Mongo.Session
        where Command:SessionCommand
    {
        let role:Role
        switch Command.color
        {
        case .nonmutating:  role = .any
        case .mutating:     role = .master
        }

        let connection:Mongo.Connection = try await self.next(role)
        let session:SessionIdentifier = self.sessions.obtain()
        return .init(connection: connection, cluster: self, id: session)
    }
}
extension Mongo.Cluster
{

    /// The settings used to connect to MongoDB.
    ///
    /// - Note: Might differ from the originally provided settings, since Service Discovery and Monitoring might have discovered more nodes belonging to this MongoDB cluster.
    // public private(set) var settings: ConnectionSettings {
    //     didSet {
    //         self.hosts = Set(settings.hosts)
    //     }
    // }

    
    
    /// Triggers every time the cluster rediscovers
    ///
    /// - Note: This is not thread safe outside of the cluster's `eventloop`
    // public var didRediscover: (() -> ())?
    
    // /// The interval at which cluster discovery is triggered, at a minimum of 500 milliseconds
    // ///
    // /// - Note: This is not thread safe outside of the cluster's eventloop
    // public var heartbeatFrequency = TimeAmount.seconds(10) {
    //     didSet {
    //         if heartbeatFrequency < .milliseconds(500) {
    //             heartbeatFrequency = .milliseconds(500)
    //         }
    //     }
    // }

    // /// When set to true, read queries are also executed on slave instances of MongoDB
    // ///
    // /// - Note: This is not thread safe outside of the cluster's eventloop
    // public var slaveOk = false {
    //     didSet {
    //         for connection in pool {
    //             connection.connection.slaveOk.store(self.slaveOk, ordering: .relaxed)
    //         }
    //     }
    // }
    
    

    @discardableResult
    private func scheduleDiscovery() -> Task<Void, Error> {
        return Task {
            // if isDiscovering { return }
            
            // isDiscovering = true
            // defer { isDiscovering = false }
            
            // while !isClosed {
            //     await rediscover()
            //     try await Task.sleep(nanoseconds: 1_000_000_000)
            // }
        }
    }

    // private func updateSDAM(from handshake: ServerHandshake) {

    // }


    

    /// Checks all known hosts for isMaster and writability
    // private mutating
    // func rediscover() async 
    // {
    //     if self.isClosed 
    //     {
    //         return
    //     }

    //     self.wireVersion = nil

    //     for pooledConnection in pool {
    //         let connection = pooledConnection.connection
            
    //         do {
    //             let handshake = try await connection.doHandshake(
    //                 clientDetails: nil,
    //                 credentials: settings.authentication
    //             )
                
    //             self.updateSDAM(from: handshake)
    //         } catch {
    //             await self.remove(connection: connection, error: error)
    //         }
    //     }
        
    //     self.timeoutHosts = []
    //     self.completedInitialDiscovery = true
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

    /// Prompts ``MongoCluster`` to close all connections, and connect to the remote(s) again.
    ///
    /// - Warning: Any outstanding query results may be cancelled, but the sent query might still be executed.
    ///
    /// - Note: This will also trigger a rediscovery of the cluster.
    // public mutating 
    // func reconnect() async throws 
    // {
    //     await disconnect()
    //     self.isClosed = false
    //     self.completedInitialDiscovery = false
    //     _ = try await self.next(for: .writable)
    //     await rediscover()
    // }
}

extension Mongo.Cluster
{
    public 
    enum ConnectionState 
    {
        /// Busy attempting to connect.
        case connecting
        /// Connected with `count` active connections.
        case connected(count:Int)
        /// The cluster has been shut down.
        case closed

        public static
        let disconnected:Self = .connected(count: 0)
    }

    /// The current state of the cluster's connection pool
    ///
    /// - Note: This is not thread safe outside of the cluster's eventloop
    public 
    var connectionState:ConnectionState 
    {
        if self.isClosed 
        {
            return .closed
        }

        if !completedInitialDiscovery 
        {
            return .connecting
        }
        return .connected(count: self.pool.count)
    }
}

fileprivate 
struct PooledConnection 
{
    let host:Mongo.Host
    let connection:Mongo.Connection
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