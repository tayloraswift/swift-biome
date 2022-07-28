@preconcurrency import SystemExtras
import ArgumentParser
import PackageCatalogs
import SymbolGraphs

@main 
struct Main:AsyncParsableCommand 
{
    static 
    var configuration:CommandConfiguration = .init(
        abstract: "compile swift partial symbolgraphs to intermediate representation")
    
    @Option(name: [.customShort("j"), .customLong("threads")], 
        help: "maximum number of threads to use")
    var threads:Int = 8
    @Argument(help: "path(s) to directories containing a Package.catalog file")
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
        try await withThrowingTaskGroup(of: (SymbolGraph, FilePath).self)
        {
            (queue:inout ThrowingTaskGroup<(SymbolGraph, FilePath), Error>) in 

            var width:Int = 0
            for project:FilePath in self.projects.map(FilePath.init(_:))
            {
                try Task.checkCancellation() 
                
                let catalogs:[PackageCatalog] = 
                    try .init(parsing: try project.appending("Package.catalog").read())
                
                print("found Package.catalog in '\(project)'...")

                for catalog:PackageCatalog in catalogs
                {
                    for catalog:ModuleCatalog in catalog.modules 
                    {
                        let graph:RawSymbolGraph = try catalog.read(relativeTo: project)
                        if width < self.threads
                        {
                            width += 1
                        }
                        else if let (ss, output):(String, FilePath) = try await queue.next() 
                        {
                            try output.write(ss)
                        }
                        queue.addTask 
                        {
                            let output:FilePath = project.appending("\(graph.id).ss")
                            let graph:SymbolGraph = try .init(graph)
                            return (graph.serialized.description, output)
                        }
                    }
                }
            }
            for try await (ss, output):(String, FilePath) in queue 
            {
                try output.write(ss)
            }
        }
    }
}