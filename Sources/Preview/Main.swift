import ArgumentParser
import Backtrace
@preconcurrency import SystemPackage
@preconcurrency import NIO

@main 
struct Main:AsyncParsableCommand 
{
    static 
    var configuration:CommandConfiguration = .init(abstract: "preview swift-biome documentation")
        
    @Option(name: [.customShort("p"), .customLong("port")], 
        help: "port number to listen on")
    var port:Int = 8080
    @Option(name: [.customShort("h"), .customLong("host")], 
        help: "private host name to listen on")
    var host:String = "0.0.0.0" 
    @Option(name: [.customShort("d"), .customLong("domain")], 
        help: "public host name")
    var domain:String = "127.0.0.1" 

    @Option(name: [.customLong("swift")], 
        help: "swift standard library version")
    var swift:String = "*"
    
    @Option(name: [.customLong("resources")], 
        help: "path to a copy of the 'swift-biome-resources' repository")
    var resources:String = "resources"
    
    @Argument(help: "path(s) to project repositories")
    var projects:[String] 
    
    static 
    func main() async 
    {
        do 
        {
            let command:Self = try Self.parseAsRoot() as! Self
            try await command.run()
        } 
        catch 
        {
            exit(withError: error)
        }
    }
    
    func run() async throws 
    {
        Backtrace.install()
        
        let group:MultiThreadedEventLoopGroup = .init(numberOfThreads: 2)
        let port:Int = self.port 
        
        async let preview:Preview = .init(projects: self.projects.map(FilePath.init(_:)), 
            resources: .init(self.resources), 
            swift: try .init(parsing: self.swift))

        let requests:AsyncStream<Preview.Request.Enqueued> = .init 
        { 
            (queue:AsyncStream<Preview.Request.Enqueued>.Continuation) in 
            Task.init 
            {
                while true 
                {
                    do 
                    {
                        try await self.open(port: port, queue: queue, group: group)
                    }
                    catch let error 
                    {
                        print(error)
                    }
                }
            }
        }
        
        try await preview.serve(requests)
    }
    
    private 
    func open(port:Int, 
        queue:AsyncStream<Preview.Request.Enqueued>.Continuation, 
        group:MultiThreadedEventLoopGroup) 
        async throws
    {
        let channels:[any Channel] = try await withThrowingTaskGroup(of: (any Channel).self)
        {
            (tasks:inout ThrowingTaskGroup<any Channel, Error>) in 
            
            tasks.addTask
            {
                try await Listener<Preview.Request>.send(to: queue, 
                    domain: self.domain, 
                    host: self.host, 
                    port: port,
                    group: group)
            }
            
            var channels:[any Channel] = []
            for try await channel:any Channel in tasks
            {
                let address:SocketAddress? = channel.localAddress 
                print("opened channel on \(address?.description ?? "<unavailable>")")
                channels.append(channel)
            }
            return channels
        }
        
        await withTaskGroup(of: Void.self)
        {
            (tasks:inout TaskGroup<Void>) in 
            
            for channel:Channel in channels 
            {
                tasks.addTask 
                {
                    // must capture this before the channel closes, since 
                    // the local address will be cleared
                    let address:SocketAddress? = channel.localAddress 
                    do 
                    {
                        try await channel.closeFuture.get()
                    }
                    catch let error 
                    {
                        print(error)
                    }
                    print("closed channel \(address?.description ?? "<unavailable>")")
                }
            }
            
            await tasks.next()
            
            for channel:Channel in channels 
            {
                tasks.addTask 
                {
                    do 
                    {
                        try await channel.pipeline.close(mode: .all)
                    }
                    catch let error 
                    {
                        print(error)
                    }
                }
            }
        }
    }
}
