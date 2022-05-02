// import JSON 
// import Resource

enum _PackageError:Error 
{
    case duplicate(id:Package.ID)
}
enum _ModuleError:Error 
{
    case mismatchedExtension(id:Module.ID, expected:Module.ID, in:Symbol.ID)
    case mismatched(id:Module.ID)
    case duplicate(id:Module.ID)
    case undefined(id:Module.ID)
}

struct Biome 
{
    private 
    var indices:[Package.ID: Package.Index]
    private 
    var nations:[Nation]
    
    init() 
    {
        self.indices = []
        self.nations = []
    }
    subscript(package:Package.ID) -> Package?
    {
        self.indices[package].map(self.subscript(_:))
    } 
    subscript(package:Package.Index) -> Package
    {
        _read 
        {
            yield self.nations[package.offset].package
        }
        _modify 
        {
            yield &self.nations[package.offset].package
        }
    } 
    subscript(module:Module.Index) -> Module
    {
        _read 
        {
            yield self.nations[module.package.offset].package.modules[module.offset]
        }
        _modify 
        {
            yield &self.nations[module.package.offset].package.modules[module.offset]
        }
    } 
    subscript(symbol:Symbol.Index) -> Symbol
    {
        _read 
        {
            yield self.nations[symbol.module.package.offset].package.symbols[symbols.offset]
        }
        _modify 
        {
            yield &self.nations[symbol.module.package.offset].package.symbols[symbols.offset]
        }
    } 
    
    mutating 
    func append(_ package:Package.ID, graphs:[_Graph]) throws 
    {
        var supergraph:Supergraph = .init(package: (package, .init(offset: self.nations.endIndex)))
        try supergraph.linearize(graphs, given: biome)
    }
}
extension Module 
{
    struct Scope 
    {
        //  the endpoints of a graph edge can reference symbols in either this 
        //  package or one of its dependencies. since imports are module-wise, and 
        //  not package-wise, it’s possible for multiple index dictionaries to 
        //  return matches, as long as only one of them belongs to an depended-upon module.
        //  
        //  it’s also possible to prefer a dictionary result in a foreign package over 
        //  a dictionary result in the local package, if the foreign package contains 
        //  a module that shadows one of the modules in the local package (as long 
        //  as the target itself does not also depend upon the shadowed local module.)
        private 
        let filter:Set<Module.Index>
        private 
        let layers:[[Symbol.ID: Symbol.Index]]
        
        init(filter:Set<Module.Index>, layers:[[Symbol.ID: Symbol.Index]])
        {
            self.filter = filter 
            self.layers = layers 
        }
        
        func index(of symbol:Symbol.ID) throws -> Symbol.Index 
        {
            if let index:Symbol.Index = self[symbol]
            {
                return index 
            }
            else 
            {
                throw SymbolError.undefined(id: symbol)
            } 
        }
        private 
        subscript(symbol:Symbol.ID) -> Symbol.Index?
        {
            for layer:Int in self.layers.indices
            {
                guard let index:Symbol.Index = self.layers[layer][symbol], 
                    self.filter.contains(index.module)
                else 
                {
                    continue 
                }
                // sanity check: ensure none of the remaining layers contains 
                // a colliding symbol 
                for layer:[Symbol.ID: Symbol.Index] in self.layers[layer...].dropFirst()
                {
                    if case _? = layer[symbol], self.filter.contains(index.module)
                    {
                        fatalError("colliding symbol identifiers in search space")
                    }
                }
                return index
            }
        }
    }
}
struct Nation
{
    // 10B size, 12B stride. 
    struct Key:Hashable 
    {
        let leaf:UInt32 
        let stem:UInt32 
        let trunk:UInt16
        
        init(trunk:UInt16, leaf:UInt32)
        {
            self.init(trunk: trunk, stem: .max, leaf: leaf)
        }
        init(trunk:UInt16, stem:UInt32, leaf:UInt32)
        {
            self.trunk = trunk
            self.stem = stem
            self.leaf = leaf
        }
    }
    
    var package:Package 
    
    private
    var symbols:[Key: Symbol.Group], 
        articles:[Key: Int]
    private 
    let pairings:[Symbol.Pairing: Symbol.Depth]
    
    init(_ package:Package)
    {
        self.package = package 
        self.symbols = [:]
        self.articles = [:]
        self.pairings = [:]
    }
    
    func resolve(module component:LexicalPath.Component) -> Int?
    {
        if case .identifier(let string, hyphen: nil) = component
        {
            return self.trunks[Module.ID.init(string)]
        }
        else 
        {
            return nil
        }
    }
    func depth(of symbol:(orientation:LexicalPath.Orientation, index:Int), in key:Key) -> Symbol.Depth?
    {
        self.symbols[key]?.depth(of: symbol)
    }
    
    subscript(module module:Int, symbol path:LocalSelector) -> Symbol.Group?
    {
        self.symbols    [Key.init(module: module, stem: path.stem, leaf: path.leaf)]
    }
    subscript(module module:Int, article leaf:UInt32) -> Int?
    {
        self.articles   [Key.init(module: module,                  leaf:      leaf)]
    }
    subscript(path:NationalSelector) -> NationalResolution?
    {
        switch path 
        {
        case .opaque(let opaque):
            // no additional lookups necessary
            return .opaque(opaque)
        
        case .symbol(module: let module, nil): 
            // no additional lookups necessary
            return .module(module)

        case .symbol(module: let module, let path?): 
            return self[module: module, symbol: path].map { NationalResolution.group($0, path.suffix) }
        
        case .article(module: let module, let leaf): 
            return self[module: module, article: leaf].map( NationalResolution.article(_:) )
        }
    }
    
    mutating 
    func insert(_ pairing:Symbol.Pairing, _ orientation:LexicalPath.Orientation, into key:Key)
    {
        switch orientation 
        {
        case .straight: self.insert(.big(pairing), into: key)
        case .gay:   self.insert(.little(pairing), into: key)
        }
    }
    private mutating 
    func insert(_ entry:Symbol.Group, into key:Key)
    {
        if let index:Dictionary<Key, Symbol.Group>.Index = self.symbols.index(forKey: key)
        {
            self.symbols.values[index].merge(entry)
        }
        else 
        {
            self.symbols.updateValue(entry, forKey: key)
        }
    }
}

/* public 
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
    func load<Location>(catalogs:[Catalog<Location>], 
        with loader:(Location, Resource.Text) async throws -> Resource) 
        async throws -> (biome:Self, comments:[String])
    {
        let roots:[Package.ID: Int] = try Self.indices(for: catalogs, by: \.package, 
            else: _PackageError.duplicate(id:))
        var tables:[NationalTable] = try catalogs.map 
        {
            let trunks:[Module.ID: Int] = try Self.indices(for: $0.targets, by: \.core.namespace, 
                else: _ModuleError.duplicate(id:))
            let dependencies:[Int] = $0.dependencies.compactMap { roots[$0] }
            return .init(dependencies: dependencies, trunks: trunks)
        }
        for (package, catalog):(Int, Catalog<Location>) in zip(tables.indices, catalogs)
        {
            var hash:Resource.Version? = .semantic(0, 1, 2)

            
            
            
        }
        var packages:[Package]  = []
        for catalog:Documentation.Catalog<Location> in catalogs 
        {
            var hash:Resource.Version? = .semantic(0, 1, 2)
            let start:Int = modules.endIndex
            for entry:Documentation.Catalog<Location>.ModuleDescriptor in catalog.modules
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
                for bystander:Documentation.Catalog<Location>.GraphDescriptor in entry.bystanders
                {
                    guard let index:Int = moduleIndices[bystander.namespace]
                    else 
                    {
                        // a module extends a bystander module we do not have the primary symbolgraph for
                        throw _ModuleError.undefined(id: bystander.namespace)
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
                throw Symbol.LinkingError.orphaned(symbol: $0)
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
                vertices[$0].path.lexicographicallyPrecedes(vertices[$1].path)
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
            if let availability:Symbol.UnconditionalAvailability = self.symbols[$0].availability.unconditional
            {
                if availability.unavailable || availability.deprecated
                {
                    return true 
                }
            }
            if let availability:Symbol.SwiftAvailability = self.symbols[$0].availability.swift
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
} */
