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
                        let hlo:SymbolGraph.HLO = try catalog.read(relativeTo: project)
                        if width < self.threads
                        {
                            width += 1
                        }
                        else if let (graph, output):(SymbolGraph, FilePath) = try await queue.next() 
                        {
                            try graph.save(to: output)
                        }
                        queue.addTask 
                        {
                            (try .init(parsing: hlo), project.appending("\(hlo.id).ss"))
                        }
                    }
                }
            }
            for try await (graph, output):(SymbolGraph, FilePath) in queue 
            {
                try graph.save(to: output)
            }
        }
    }
}
extension SymbolGraph 
{
    func save(to output:FilePath) throws 
    {
        try output.write(self.serialized.description)
    }
}