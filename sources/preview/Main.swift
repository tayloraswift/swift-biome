import ArgumentParser
import SystemPackage
import Backtrace
import NIO

@main 
struct Main:AsyncParsableCommand 
{
    static 
    var configuration:CommandConfiguration = .init(abstract: "preview swift-biome documentation")
        
    @Option(name: [.customShort("p"), .customLong("port")], help: "port number to listen on")
    var port:Int = 8080
    @Option(name: [.customShort("i"), .customLong("ip")], help: "private host name to listen on")
    var ip:String = "0.0.0.0" 
    @Option(name: [.customLong("host")], help: "public host name")
    var host:String = "127.0.0.1" 
    
    @Option(name: [.customShort("g"), .customLong("git")], help: "path to `git`, if different from '/usr/bin/git'")
    var git:String = "/usr/bin/git"
    @Option(name: [.customShort("b"), .customLong("resources")], help: "path to a copy of the 'swift-biome-resources' repository")
    var resources:String = "resources"
    
    @Option(name: [.customLong("merge-stylesheets")], help: "merge stylesheets into a single file")
    var mergeStylesheets:Bool = true
    
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
        
        let stylesheets:[String: [FilePath]]
        if  self.mergeStylesheets 
        {
            stylesheets = 
            [
                "/biome-common.css": 
                [
                    "default-dark/biome-header.css",
                    "default-dark/biome-body.css",
                    "default-dark/common.css", 
                ],
            ]
        }
        else 
        {
            stylesheets = 
            [
                "/biome-header.css":    ["default-dark/biome-header.css"],
                "/biome-body.css":      ["default-dark/biome-body.css"],
                "/common.css":          ["default-dark/common.css"],
            ]
        }
        
        let preview:Preview = try await .init(projects: self.projects.map(FilePath.init(_:)), 
            controller: .init(git: .init(self.git), repository: .init(self.resources)),
            stylesheets: stylesheets)
        
        let host:String = self.host 
        let port:Int = self.port
        
        let group:MultiThreadedEventLoopGroup   = .init(numberOfThreads: 4)
        let bootstrap:ServerBootstrap           = .init(group: group)
            .serverChannelOption(ChannelOptions.backlog,                        value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr),    value:   1)
            .childChannelInitializer 
        { 
            (channel:Channel) -> EventLoopFuture<Void> in
            
            return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap 
            {
                channel.pipeline.addHandler(Endpoint<Preview>.init(backend: preview, 
                    host: host, 
                    port: port))
            }
        }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr),     value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead,              value: 1)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure,          value: true)

        let channel:Channel = try await bootstrap.bind(host: self.ip, port: port).get()
        
        print("started server at http://\(host):\(port)")
        
        try await channel.closeFuture.get()
    }
}
