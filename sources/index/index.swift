@_exported import Biome 
import StructuredDocument
import Bureaucrat
import JSON

extension Documentation.Catalog where Location == FilePath 
{
    init(loading descriptor:Documentation.CatalogDescriptor)
    {
        let id:Biome.Package.ID
        switch descriptor.name 
        {
        case "swift-standard-library", "swift-stdlib", "swift", 
                   "standard-library",       "stdlib",      "":
            id = .swift 
        case let name:
            id = .community(name)
        }
        
        var articles:[Article] = []
        var graphs:[Substring: [Graph]] = [:]
        for include:FilePath in descriptor.include.map(FilePath.init(_:))
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
        let modules:[Module] = graphs.sorted 
        {
            $0.key < $1.key
        }.compactMap 
        {
            let id:Biome.Module.ID = .init($0.key)
            
            var core:Graph? = nil 
            var bystanders:[Graph] = []
            for graph:Graph in $0.value
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
            guard let core:Graph = core 
            else 
            {
                print("warning: skipped module '\(id.string)' because its core symbolgraph is missing")
                return nil
            }
            return .init(core: core, bystanders: bystanders)
        }
        self.init(id: id, articles: articles, modules: modules)
    }
}
extension Documentation 
{
    struct CatalogDescriptor:Decodable 
    {
        let name:String
        let include:[String]
    }
    
    public 
    init(serving bases:[URI.Base: String], 
        template:DocumentTemplate<Anchor, [UInt8]>, 
        indexfile path:FilePath) async throws
    {
        let file:[UInt8] = try Bureaucrat.read(from: path)
        let descriptors:[JSON] = try Grammar.parse(_move(file), as: JSON.Rule<Array<UInt8>.Index>.Array.self)
        let catalogs:[Catalog<FilePath>] = try _move(descriptors).map
        {
            Catalog<FilePath>.init(loading: try CatalogDescriptor.init(from: $0))
        }
        
        try await self.init(serving: bases, template: template, loading: catalogs)
        {
            .utf8(encoded: try Bureaucrat.read(from: $0), type: $1, version: nil)
        }
    }
}
