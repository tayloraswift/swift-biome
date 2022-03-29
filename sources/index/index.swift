@_exported import Biome 
import Bureaucrat
import JSON

extension Documentation 
{
    struct CatalogDescriptor:Decodable 
    {
        let name:String
        let include:[String]
        
        func load() -> Catalog<FilePath>
        {
            let package:Biome.Package.ID 
            switch self.name 
            {
            case "swift-standard-library", "swift-stdlib", "swift", 
                       "standard-library",       "stdlib",      "":
                package = .swift 
            case let name:
                package = .community(name)
            }
            
            var articles:[Catalog<FilePath>.Article] = []
            var graphs:[Substring: [Catalog<FilePath>.Graph]] = [:]
            for include:FilePath in self.include.map(FilePath.init(_:))
            {
                include.walk
                {
                    (path:FilePath) in 
                    
                    guard let file:FilePath.Component = path.components.last 
                    else 
                    {
                        return 
                    }
                    let location:FilePath = include.appending(path.components)
                    switch file.extension
                    {
                    case "md"?:
                        var path:[String] = path.components.dropLast().map(\.string)
                            path.append(file.stem)
                        articles.append(.init(path: path, location: location))
                    case "json"?:
                        
                        guard   let reduced:FilePath.Component = .init(file.stem),
                                case "symbols"? = reduced.extension
                        else 
                        {
                            break 
                        }
                        let identifiers:[Substring] = reduced.stem.split(separator: "@", omittingEmptySubsequences: false)
                        guard   let first:Substring = identifiers.first, 
                                let last:Substring  = identifiers.last, identifiers.count <= 2 
                        else 
                        {
                            print("warning: ignored symbolgraph with invalid name '\(reduced.stem)'")
                            break 
                        }
                        graphs[first, default: []]
                            .append(.init(id: Biome.Module.ID.init(last), location: location))
                        
                    default: 
                        break
                    }
                }
            }
            
            return .init(id: package, articles: articles, modules: graphs.sorted 
            {
                $0.key < $1.key
            }.compactMap 
            {
                let id:Biome.Module.ID = .init($0.key)
                
                var core:Catalog<FilePath>.Graph? = nil 
                var bystanders:[Catalog<FilePath>.Graph] = []
                for graph:Catalog<FilePath>.Graph in $0.value
                {
                    guard graph.id != id 
                    else 
                    {
                        if case nil = core
                        {
                            core = graph
                        }
                        else 
                        {
                            print("warning: ignored duplicate symbolgraph '\(graph.id.string)'")
                        }
                        continue 
                    }
                    bystanders.append(graph)
                }
                guard let core:Catalog<FilePath>.Graph = core 
                else 
                {
                    print("warning: skipped module '\(id.string)' because its core symbolgraph is missing")
                    return nil
                }
                return .init(core: core, bystanders: bystanders)
            })
        }
    }
    
    public static 
    func loadFromIndexFile(at path:FilePath) throws
    {
        let file:[UInt8] = try Bureaucrat.read(from: path)
        let descriptors:[JSON] = try Grammar.parse(_move(file), as: JSON.Rule<Array<UInt8>.Index>.Array.self)
        for catalog:CatalogDescriptor in try _move(descriptors).map(CatalogDescriptor.init(from:))
        {
            print(catalog.load())
        }
    }
}
