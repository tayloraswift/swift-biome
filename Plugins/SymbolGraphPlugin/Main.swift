import PackagePlugin

public
struct MissingOptionValueError:Error
{
    public 
    let option:String
}
extension MissingOptionValueError:CustomStringConvertible
{
    public
    var description:String 
    {
        "option '\(self.option)' expects a value"
    }
}
public
struct MissingNationalityError:Error 
{
    public
    let name:Package.ID
    public 
    init(name:Package.ID)
    {
        self.name = name 
    }
}
extension MissingNationalityError:CustomStringConvertible
{
    public 
    var description:String 
    {
        "nationality '\(self.name)' contributed no cultures to the symbolgraph"
    }
}
public
struct MissingCultureError:Error 
{
    public
    let name:String
    public 
    init(name:String)
    {
        self.name = name 
    }
}
extension MissingCultureError:CustomStringConvertible
{
    public 
    var description:String 
    {
        "culture '\(self.name)' is not a swift source module in this package"
    }
}

struct Filter
{
    // private(set)
    // var standardLibrary:Bool
    private
    var nationalities:Set<Package.ID>
    private
    var cultures:Set<String>

    init(parsing arguments:[String]) throws
    {
        // self.standardLibrary = false
        self.nationalities = []
        self.cultures = []

        var iterator:Array<String>.Iterator = arguments.makeIterator()
        while let argument:String = iterator.next()
        {
            switch argument
            {
            // case "-s", "-swift", "--swift":
            //     self.standardLibrary = true
            case "-n", "-nationality", "--nationality":
                if  let nationality:String = iterator.next()?.lowercased()
                {
                    self.nationalities.insert(nationality as Package.ID)
                }
                else
                {
                    throw MissingOptionValueError.init(option: argument)
                }
            
            case let culture:
                self.cultures.insert(culture)
            }
        }
    }

    func matches(nationality:Package.ID) -> Bool
    {
        self.nationalities.isEmpty ? true : self.nationalities.contains(nationality)
    }
    func matches(culture:String) -> Bool
    {
        self.cultures.isEmpty ? true : self.cultures.contains(culture)
    }

    func validate(_ found:[Module<SwiftSourceModuleTarget>]) throws
    {
        var nationalities:Set<Package.ID> = self.nationalities
        var cultures:Set<String> = self.cultures
        for culture:Module<SwiftSourceModuleTarget> in found
        {
            nationalities.remove(culture.nationality)
            cultures.remove(culture.target.name)
        }

        if let missing:String = nationalities.first 
        {
            throw MissingNationalityError.init(name: missing)
        }
        if let missing:String = cultures.first 
        {
            throw MissingCultureError.init(name: missing)
        }
    }
}
    
@main 
struct Main:CommandPlugin
{
    func performCommand(context:PluginContext, arguments:[String]) throws 
    {
        print(CommandLine.arguments)
        
        let filter:Filter = try .init(parsing: arguments)
        let tool:PluginContext.Tool = try context.tool(named: "swift-symbolgraphc")
        try tool.run(arguments: try self.builds(context: context, filter: filter))
    }
    func builds(context:PluginContext, filter:Filter) throws -> String
    {
        // determine which products belong to which packages 
        let graph:PackageGraph = .init(context.package)
        #if swift(>=5.7)
        var snippets:[Module<SwiftSourceModuleTarget>] = []
        #endif
        var cultures:[Module<SwiftSourceModuleTarget>] = []

        var seen:Set<Target.ID> = []
        for target:any Target in graph.local.targets 
        {
            graph.walk(target)
            {
                guard   filter.matches(nationality: $0.nationality),
                        let target:SwiftSourceModuleTarget = $0.target as? SwiftSourceModuleTarget, 
                        case nil = seen.update(with: $0.target.id)
                else 
                {
                    return 
                }
                let module:Module<SwiftSourceModuleTarget> = .init(target, in: $0.nationality)

                #if swift(>=5.7)
                if case .snippet = target.kind 
                {
                    snippets.append(module)
                    return
                }
                #endif
                if filter.matches(culture: $0.target.name)
                {
                    cultures.append(module)
                }
            }
        }
        
        try filter.validate(cultures)

        let options:PackageManager.SymbolGraphOptions = .init(
            minimumAccessLevel: .public,
            includeSynthesized: true,
            includeSPI: true)
        
        // add dependencies implicitly
        var added:Set<Target.ID> = []
        var packages:[Package.ID: Build] = [:]
        for culture:Module<SwiftSourceModuleTarget> in cultures 
        {
            let implicit:[Package.ID: [SwiftSourceModuleTarget]] = 
                graph.dependencies(of: culture)
            
            for (nationality, targets):(Package.ID, [SwiftSourceModuleTarget]) in 
                [(culture.nationality, [culture.target])] + implicit
            {
                for target:SwiftSourceModuleTarget in targets
                {
                    guard case nil = added.update(with: target.id), 
                        filter.matches(nationality: nationality)
                    else
                    {
                        continue
                    }

                    let dependencies:[Package.ID: [SwiftSourceModuleTarget]]
                    if target.id == culture.target.id
                    {
                        dependencies = implicit
                    }
                    else
                    {
                        print("generating colonial graphs for implicitly included culture '\(target.name)'")
                        dependencies = graph.dependencies(of: .init(target, in: nationality))
                    }

                    let graphs:PackageManager.SymbolGraphResult = 
                        try self.packageManager.getSymbolGraph(for: target, options: options)
                    var include:[String] = [graphs.directoryPath.string]
                    for file:File in target.sourceFiles
                    {
                        if  case .unknown = file.type, 
                            case "docc"?  = file.path.extension?.lowercased()
                        {
                            include.append(file.path.string)
                        }
                    }
                    
                    packages[nationality, default: .init()].append(culture: target, 
                        dependencies: dependencies,
                        include: include)
                }
            }
        }
        #if swift(>=5.7)
        for snippet:Module<SwiftSourceModuleTarget> in snippets
        {
            let sources:[String] = snippet.target.sourceFiles.compactMap 
            {
                if case .source = $0.type 
                {
                    return $0.path.string 
                }
                else 
                {
                    return nil 
                }
            }
            packages[snippet.nationality, default: .init()].append(snippet: snippet.target, 
                dependencies: graph.dependencies(of: snippet), 
                sources: sources)
        }
        #endif
        let builds:String =
        """
        [\(packages.sorted { $0.key < $1.key }.map 
        { 
            """
            
                {
                    "symbolgraph_tools_version": 4,
                    "id": "\($0.key)", 
                    "cultures": 
                    [\($0.value.cultures.joined(separator: ", "))
                    ],
                    "snippets": 
                    [\($0.value.snippets.joined(separator: ", "))
                    ]
                }
            """
        }.joined(separator: ", "))
        ]
        """
        return builds
    }
}