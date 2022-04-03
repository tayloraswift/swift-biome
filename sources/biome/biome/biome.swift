import JSON 
import Resource

public 
struct Biome:Sendable 
{
    private(set)
    var symbols:Storage<Symbol>,
        modules:Storage<Module>, 
        packages:Storage<Package>
    
    private static 
    func indices<S, ID>(for elements:S, by id:KeyPath<S.Element, ID>, else error:(ID) -> Error) 
        throws -> [ID: Int]
        where S:Sequence, ID:Hashable
    {
        var indices:[ID: Int] = [:]
        for (index, element):(Int, S.Element) in elements.enumerated()
        {
            guard case nil = indices.updateValue(index, forKey: element[keyPath: id])
            else
            {
                throw error(element[keyPath: id])
            }
        }
        return indices
    }
    
    static 
    func load<Location>(catalogs:[Documentation.Catalog<Location>], 
        with loader:(Location, Resource.Text) async throws -> Resource) 
        async throws -> (biome:Self, comments:[String])
    {
        let packageIndices:[Package.ID: Int]    = try Self.indices(for: catalogs, by: \.package, 
            else: Graph.PackageError.duplicate(id:))
        let moduleIndices:[Module.ID: Int]      = try Self.indices(for: catalogs.map(\.modules).joined(), by: \.core.namespace, 
            else: Graph.ModuleError.duplicate(id:))
        var symbolIndices:[Symbol.ID: Int]      = [:]
        // we need the mythical dictionary in case we run into synthesized 
        // extensions before the generic base (in which case, they would be assigned 
        // to the wrong module)
        var mythical:[Symbol.ID: Graph.Vertex]  = [:]
        var vertices:[Graph.Vertex] = []
        var edges:Set<Graph.Edge> = []
        var modules:[Module]    = []
        var packages:[Package]  = []
        for catalog:Documentation.Catalog<Location> in catalogs 
        {
            var hash:Resource.Version? = .semantic(0, 1, 2)
            let start:Int = modules.endIndex
            for entry:Documentation.Catalog<Location>.Module in catalog.modules
            {
                let core:Range<Int>
                do 
                {
                    let graph:Graph = try await catalog.load(core: entry.core, with: loader)
                    try graph.populate(&edges)
                    core  = try graph.populate(&vertices, mythical: &mythical, indices: &symbolIndices)
                    hash *=     graph.version
                }
                catch let error 
                {
                    throw Graph.LoadingError.init(error, module: entry.core.namespace, bystander: nil)
                }
                var extensions:[(bystander:Int, symbols:Range<Int>)] = [] 
                for bystander:Documentation.Catalog<Location>.Module.Graph in entry.bystanders
                {
                    guard let index:Int = moduleIndices[bystander.namespace]
                    else 
                    {
                        // a module extends a bystander module we do not have the primary symbolgraph for
                        throw Graph.ModuleError.undefined(id: bystander.namespace)
                    }
                    do 
                    {
                        let graph:Graph = try await catalog.load(graph: bystander, of: entry.core.namespace, with: loader)
                        try graph.populate(&edges)
                        extensions.append((index, try graph.populate(&vertices, mythical: &mythical, indices: &symbolIndices)))
                        hash *= graph.version
                    }
                    catch let error 
                    {
                        throw Graph.LoadingError.init(error, module: entry.core.namespace, bystander: bystander.namespace)
                    }
                }
                let module:Module = .init(id: entry.core.namespace, package: packages.endIndex, 
                    core: core, extensions: extensions)
                // sanity check 
                guard case modules.endIndex? = moduleIndices[entry.core.namespace]
                else 
                {
                    fatalError("unreachable")
                }
                modules.append(module)
                
                if entry.bystanders.isEmpty
                {
                    Swift.print("loaded module '\(entry.core.namespace.string)' (from package '\(catalog.package.name)')")
                }
                else 
                {
                    Swift.print("loaded module '\(entry.core.namespace.string)' (from package '\(catalog.package.name)', bystanders: \(entry.bystanders.map{ "'\($0.namespace.string)'" }.joined(separator: ", ")))")
                }
            }
            let end:Int = modules.endIndex
            if case nil = hash 
            {
                print("warning: package '\(catalog.package)' is unversioned. this will degrade network performance.")
            }
            let package:Package = .init(id: catalog.package, modules: start ..< end, hash: hash)
            packages.append(package)
        }
        // only keep mythical vertices if we don’t have the generic base available
        for (generic, vertex):(Symbol.ID, Graph.Vertex) in mythical 
        {
            guard case nil = symbolIndices.updateValue(vertices.endIndex, forKey: generic)
            else 
            {
                fatalError("unreachable")
            }
            vertices.append(vertex)
            
            Swift.print("note: inferred existence of mythical symbol '\(generic)'")
        }
        
        /* if start != end 
        {
            // generate the mythical package and module 
            let module:Module   = .init(id: .mythical, package: packages.endIndex, 
                path: .init(prefix: prefix, package: .mythical, namespace: .mythical), 
                core: start ..< end, 
                extensions: [])
            modules.append(module)
            let package:Package = .init(id: package.id, path: path, search: search, modules: modules.endIndex - 1 ..< modules.endIndex, 
                hash: .semantic(0, 0, 0))
        } */
        
        Swift.print("loaded \(vertices.count) vertices and \(edges.count) edges from \(modules.count) module(s)")
        
        let biome:Biome = try .init(
            indices:    symbolIndices, 
            vertices:   vertices, 
            edges:      edges, 
            modules:   .init(indices: _move(moduleIndices),  elements: modules), 
            packages:  .init(indices: _move(packageIndices), elements: packages))
        
        var _memory:Int 
        {
            MemoryLayout<Module>.stride * biome.modules.count + biome.symbols.reduce(0)
            {
                $0 + $1._size
            }
        }
        Swift.print("initialized biome (\(_memory >> 10) KB)")
        return (biome, vertices.map(\.comment))
    }
    
    private 
    struct Lineage:Hashable
    {
        let namespace:Int 
        let path:ArraySlice<String>
        
        init(namespace:Int, path:ArraySlice<String>)
        {
            self.namespace  = namespace 
            self.path       = path
        }
        init(namespace:Int, path:[String])
        {
            self.init(namespace: namespace, path: path[...])
        }
        
        var parent:Self? 
        {
            let path:ArraySlice<String> = self.path.dropLast()
            return path.isEmpty ? nil : .init(namespace: self.namespace, path: path)
        }
    }
    private static 
    func lineages(vertices:[Graph.Vertex], modules:Storage<Module>) -> [(module:Int, lineage:Lineage)]
    {
        modules.indices.flatMap
        {
            (module:Int) -> [(module:Int, lineage:Lineage)] in
            
            var lineages:[Lineage] = modules[module].symbols.core.map 
            {
                .init(namespace: module, path: vertices[$0].path)
            }
            for (bystander, symbols):(Int, Range<Int>) in modules[module].symbols.extensions
            {
                for index:Int in symbols
                {
                    lineages.append(.init(namespace: bystander, path: vertices[index].path))
                }
            }
            return lineages.map { (module, $0) }
        }
    }
    private static 
    func parents(vertices:[Graph.Vertex], modules:Storage<Module>) 
        throws -> [Graph.Edge.References]
    {
        // lineages. these only form a *subsequence* of all the vertices; mythical 
        // symbols do not have lineages
        let lineages:[(module:Int, lineage:Lineage)] = Self.lineages(vertices: vertices, modules: modules)
        let parents:[Lineage: Int] = [Lineage: [Int]].init(grouping: lineages.indices)
        {
            lineages[$0].lineage
        }.compactMapValues 
        {
            if let first = $0.first, $0.dropFirst().isEmpty 
            {
                return first
            }
            else 
            {
                return nil 
            }
        }
        let references:[Graph.Edge.References] = try lineages.indices.map
        {
            let (module, lineage):(Int, Lineage) = lineages[$0]
            let bystander:Int? = module == lineage.namespace ? nil : lineage.namespace
            guard let parent:Lineage = lineage.parent
            else 
            {
                // is a top-level symbol  
                return .init(parent: nil, module: module, bystander: bystander) 
            }
            if let parent:Int = parents[parent] 
            {
                return .init(parent: parent, module: module, bystander: bystander) 
            }
            else 
            {
                throw SymbolLinkingError.orphaned(symbol: $0)
            }
        }
        return references + repeatElement(.init(parent: nil, module: nil, bystander: nil), 
            count: vertices.count - references.count)
    }
    private 
    init(indices:[Symbol.ID: Int], vertices:[Graph.Vertex], edges:Set<Graph.Edge>, 
        modules:Storage<Module>, packages:Storage<Package>)
        throws
    {
        var references:[Graph.Edge.References] = try Self.parents(vertices: vertices, modules: modules)
        //  link 
        for edge:Graph.Edge in _move(edges)
        {
            try edge.link(&references, indices: indices)
        }
        // sometimes symbols get marked as sponsored even if they have 
        // docs of their own. only keep this flag is the docs are truly duplicated
        for index:Int in references.indices
        {
            if  let      sponsor:Int =     references[index].sponsor, 
                                            !vertices[index].comment.isEmpty, 
                vertices[sponsor].comment != vertices[index].comment
            {
                references[index].sponsor = nil
            }
        }
        // validate 
        let colors:[Symbol.Kind] = vertices.map(\.kind)
        var relationships:[Symbol.Relationships] = try zip(colors.indices, references).map 
        {
            try .init(index: $0.0, references: $0.1, colors: colors)
        }
        // sort 
        for index:Int in relationships.indices
        {
            relationships[index].sort
            {
                (vertices[$0].path.last ?? "") < (vertices[$1].path.last ?? "")
            }
        }
        
        let symbols:Storage<Symbol> = .init(indices: indices, elements: 
            try vertices.indices.map 
            {
                try Symbol.init(modules: modules, indices: indices,
                    vertex:         vertices[$0],
                    edges:          references[$0], 
                    relationships:  relationships[$0])
            })
        self.init(packages: packages, modules: modules, symbols: symbols)
    }
    private 
    init(packages:Storage<Package>, modules:Storage<Module>, symbols:Storage<Symbol>)
    {
        // symbols 
        self.packages   = packages
        self.modules    = modules 
        self.symbols    = symbols 
        
        // gather toplevels 
        for module:Int in self.modules.indices 
        {
            for symbol:Int in self.modules[module].symbols.core 
            {
                guard case nil = symbols[symbol].parent
                else 
                {
                    continue 
                }
                self.modules[module].toplevel.append(symbol)
            }
            // sort 
            self.modules[module].toplevel.sort
            {
                self.symbols[$0].title < self.symbols[$1].title
            }
        }
    }
    
    func comments(backing symbols:[Int]) -> [Int]
    {
        symbols.map 
        {
            self.symbols[$0].sponsor ?? $0
        }
    }
    func partition(symbols:[Int]) -> [Bool: [Int]]
    {
        .init(grouping: symbols)
        {
            if let availability:UnconditionalAvailability = self.symbols[$0].availability.unconditional
            {
                if availability.unavailable || availability.deprecated
                {
                    return true 
                }
            }
            if let availability:SwiftAvailability = self.symbols[$0].availability.swift
            {
                if case _? = availability.deprecated
                {
                    return true 
                }
                if case _? = availability.obsoleted 
                {
                    return true 
                }
            }
            return false
        }
    }
    func organize(symbols:[Int], in scope:Int?) -> [(heading:Documentation.Topic, symbols:[(witness:Int, victim:Int?)])]
    {
        let topics:[Documentation.Topic.Automatic: [Int]] = .init(grouping: symbols)
        {
            self.symbols[$0].kind.topic
        }
        return Documentation.Topic.Automatic.allCases.compactMap
        {
            if  let indices:[Int] = topics[$0]
            {
                let indices:[(witness:Int, victim:Int?)] = indices.map 
                {
                    if  let scope:Int = scope, 
                        let parent:Int = self.symbols[$0].parent, parent != scope 
                    {
                        return (witness: $0, victim: scope)
                    }
                    else 
                    {
                        return (witness: $0, victim: nil)
                    }
                }
                return (.automatic($0), indices)
            }
            else 
            {
                return nil 
            }
        }
    }
    
    /// returns a package index.
    /* private 
    func packageCitizenship(symbol:Int) -> Int? 
    {
        guard let module:Int = self.symbols[symbol].module
        else 
        {
            // mythical symbols are not citizens of any package 
            return nil
        }
        let package:Int = self.modules[module].package
        switch self.symbols[symbol].bystander 
        {
        case nil:
            // symbols that live in the same namespace as the modules that vend 
            // them are always package citizens 
            return package 
        case let bystander?: 
            return self.modules[bystander].package == package ? package : nil
        }
    }
    private 
    func packageCitizenship(symbol:Int, specialization scope:Int) -> Int? 
    {
        if  let package:Int = self.packageCitizenship(symbol: symbol), 
            case package?   = self.packageCitizenship(symbol: scope)
        {
            return package 
        }
        else 
        {
            return nil 
        }
    } */
}
