import JSON 
import Resource

public 
struct Biome:Sendable 
{
    public 
    struct Version:CustomStringConvertible, Sendable
    {
        var major:Int 
        var minor:Int?
        var patch:Int?
        
        public 
        var description:String 
        {
            switch (self.minor, self.patch)
            {
            case (nil       , nil):         return "\(self.major)"
            case (let minor?, nil):         return "\(self.major).\(minor)"
            case (let minor , let patch?):  return "\(self.major).\(minor ?? 0).\(patch)"
            }
        }
    }
    
    private(set)
    var symbols:Storage<Symbol>,
        modules:Storage<Module>, 
        packages:Storage<Package>
    
    private static 
    func modules(_ packages:[Package.ID: [String]]) -> 
    (
        packages:[(id:Package.ID, targets:Range<Int>)],
        modules:[(module:Module.ID, bystanders:[Module.ID])]
    )
    {
        var modules:[(Module.ID, [Module.ID])]  = []
        let packages:[(Package.ID, Range<Int>)] = packages.sorted
        {
            $0.key < $1.key
        }
        .map 
        {
            var targets:[Module.ID: [Module.ID]] = [:]
            for name:String in $0.value
            {
                let identifiers:[Module.ID] = name.split(separator: "@").map(Module.ID.init(_:))
                guard let module:Module.ID  = identifiers.first 
                else 
                {
                    continue // name was all '@' signs
                }
                let bystanders:ArraySlice<Module.ID> = identifiers.dropFirst()
                targets[module, default: []].append(contentsOf: bystanders.prefix(1))
            }
            let start:Int   = modules.endIndex 
            modules.append(contentsOf: targets.sorted { $0.key.string < $1.key.string })
            let end:Int     = modules.endIndex 
            return ($0.key, start ..< end)
        }
        return (packages, modules)
    }
    
    private static 
    func indices<Element, ID>(for elements:[Element], by id:KeyPath<Element, ID>, else error:(ID) -> Error) 
        throws -> [ID: Int]
        where ID:Hashable
    {
        var indices:[ID: Int] = [:]
        for (index, element):(Int, Element) in elements.enumerated()
        {
            guard case nil = indices.updateValue(index, forKey: element[keyPath: id])
            else
            {
                throw error(element[keyPath: id])
            }
        }
        return indices
    }
    
    private static
    func populate(
        symbolIndices:inout [Symbol.ID: Int],
        mythical:inout [Symbol.ID: Vertex],
        vertices:inout [Vertex], 
        edges:inout [Edge],
        from json:JSON, 
        module:Module.ID, 
        prune:Bool = false) 
        throws -> Range<Int>
    {
        let descriptor:(module:Module.ID, vertices:[Vertex], edges:[Edge]) = try Self.decode(module: json)
        guard descriptor.module == module 
        else 
        {
            throw ModuleIdentifierError.mismatch(decoded: descriptor.module)
        }
        edges.append(contentsOf: descriptor.edges)
        
        let start:Int = vertices.endIndex
        //var _count:Int = 0
        for vertex:Vertex in descriptor.vertices 
        {
            //defer 
            //{
            //    _count += 1
            //}
            if vertex.isCanonical
            {
                if case _? = symbolIndices.updateValue(vertices.endIndex, forKey: vertex.id)
                {
                    throw SymbolIdentifierError.duplicate(symbol: vertex.id) 
                }
                vertices.append(vertex)
                mythical.removeValue(forKey: vertex.id)
            }
            else if let duplicate:Int = symbolIndices[vertex.id]
            {
                guard vertex ~~ vertices[duplicate]
                else 
                {
                    throw SymbolIdentifierError.duplicate(symbol: vertex.id) 
                }
            }
            else if let duplicate:Vertex = mythical.updateValue(vertex, forKey: vertex.id)
            {
                // only add the vertex to the mythical list if we don’t already 
                // have it in the normal list 
                guard vertex ~~ duplicate 
                else 
                {
                    throw SymbolIdentifierError.duplicate(symbol: vertex.id) 
                }
            }
        }
        let end:Int = vertices.endIndex
        return start ..< end
    }
    
    private static
    func load(package:Package.ID, graph name:String, hashingInto version:inout Resource.Version,
        with load:(_ package:Package.ID, _ module:String) async throws -> Resource) 
        async throws -> JSON 
    {
        let json:JSON
        switch try await load(package, name)
        {
        case    .text   (let string, type: .json, version: let component?):
            json = try Grammar.parse(string.utf8, as: JSON.Rule<String.Index>.Root.self)
            version *= component
        case    .bytes  (let bytes, type: .json, version: let component?):
            json = try Grammar.parse(bytes, as: JSON.Rule<Array<UInt8>.Index>.Root.self)
            version *= component
        case    .text   (_, type: .json, version: nil),
                .bytes  (_, type: .json, version: nil):
            throw ResourceVersionError.missing
        case    .text   (_, type: let type, version: _),
                .bytes  (_, type: let type, version: _):
            throw ResourceTypeError.init(type.description, expected: Resource.Text.json.description)
        case    .binary (_, type: let type, version: _):
            throw ResourceTypeError.init(type.description, expected: Resource.Text.json.description)
        }
        return json
    }
    static 
    func load(packages names:[Package.ID: [String]], 
        loader:(_ package:Package.ID, _ module:String) async throws -> Resource) 
        async throws -> (biome:Self, comments:[String])
    {
        let (names, targets):([(id:Package.ID, targets:Range<Int>)], [Target]) = Self.modules(names)
        
        let packageIndices:[Package.ID: Int]    = try Self.indices(for: names, by: \.id, 
            else: PackageIdentifierError.duplicate(package:))
        let moduleIndices:[Module.ID: Int]      = try Self.indices(for: targets, by: \.module, 
            else: ModuleIdentifierError.duplicate(module:))
        var symbolIndices:[Symbol.ID: Int]      = [:]
        // we need the mythical dictionary in case we run into synthesized 
        // extensions before the generic base (in which case, they would be assigned 
        // to the wrong module)
        var mythical:[Symbol.ID: Vertex]        = [:]
        var vertices:[Vertex]   = []
        var edges:[Edge]        = []
        var modules:[Module]    = []
        var packages:[Package]  = []
        for package:(id:Package.ID, targets:Range<Int>) in names 
        {
            var version:Resource.Version = .semantic(0, 1, 2)
            for target:(module:Module.ID, bystanders:[Module.ID]) in targets[package.targets]
            {
                let core:Range<Int>
                do 
                {
                    core = try Self.populate(
                        symbolIndices: &symbolIndices,
                        mythical: &mythical,
                        vertices: &vertices, 
                        edges: &edges,
                        from: try await Self.load(
                            package: package.id, 
                            graph: target.module.graphIdentifier(bystander: nil), 
                            hashingInto: &version, 
                            with: loader), 
                        module: target.module)
                }
                catch let error 
                {
                    throw GraphLoadingError.init(error, module: target.module, bystander: nil)
                }
                var extensions:[(bystander:Int, symbols:Range<Int>)] = [] 
                for bystander:Module.ID in target.bystanders
                {
                    // reconstruct the name
                    guard let index:Int = moduleIndices[bystander]
                    else 
                    {
                        // a module extends a bystander module we do not have the 
                        // primary symbolgraph for
                        throw ModuleIdentifierError.undefined(module: bystander)
                        //print("warning: ignored module extensions '\(name)'")
                        //continue 
                    }
                    do 
                    {
                        extensions.append((index, try Self.populate(
                            symbolIndices: &symbolIndices,
                            mythical: &mythical,
                            vertices: &vertices, 
                            edges: &edges,
                            from: try await Self.load(
                                package: package.id, 
                                graph: target.module.graphIdentifier(bystander: bystander), 
                                hashingInto: &version, 
                                with: loader), 
                            module: target.module, 
                            prune: true)))
                    }
                    catch let error 
                    {
                        throw GraphLoadingError.init(error, module: target.module, bystander: bystander)
                    }
                }
                let module:Module = .init(id: target.module, package: packages.endIndex, 
                    core: core, extensions: extensions)
                modules.append(module)
                
                if target.bystanders.isEmpty
                {
                    print("loaded module '\(target.module.string)' (from package '\(package.id.name)')")
                }
                else 
                {
                    print("loaded module '\(target.module.string)' (from package '\(package.id.name)', bystanders: \(target.bystanders.map{ "'\($0.string)'" }.joined(separator: ", ")))")
                }
            }
            let package:Package = .init(id: package.id, modules: package.targets, hash: version)
            packages.append(package)
        }
        // only keep mythical vertices if we don’t have the generic base available
        for (generic, vertex):(Symbol.ID, Vertex) in mythical 
        {
            guard case nil = symbolIndices.updateValue(vertices.endIndex, forKey: generic)
            else 
            {
                fatalError("unreachable")
            }
            vertices.append(vertex)
            
            print("note: inferred existence of mythical symbol '\(generic)'")
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
        
        print("loaded \(vertices.count) vertices and \(edges.count) edges from \(modules.count) module(s)")
        
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
        print("initialized biome (\(_memory >> 10) KB)")
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
    func lineages(vertices:[Vertex], modules:Storage<Module>, packages:Storage<Package>) -> [(module:Int, lineage:Lineage)]
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
    func parents(vertices:[Vertex], modules:Storage<Module>, packages:Storage<Package>) 
        throws -> [Edge.References]
    {
        // lineages. these only form a *subsequence* of all the vertices; mythical 
        // symbols do not have lineages
        let lineages:[(module:Int, lineage:Lineage)] = Self.lineages(vertices: vertices, modules: modules, packages: packages)
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
        let references:[Edge.References] = try lineages.indices.map
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
                throw LinkingError.orphaned(symbol: $0)
            }
        }
        return references + repeatElement(.init(parent: nil, module: nil, bystander: nil), 
            count: vertices.count - references.count)
    }
    private 
    init(indices:[Symbol.ID: Int], vertices:[Vertex], edges:[Edge], 
        modules:Storage<Module>, packages:Storage<Package>)
        throws
    {
        var references:[Edge.References] = try Self.parents(vertices: vertices, 
            modules: modules, packages: packages)
        //  link 
        for edge:Edge in _move(edges)
        {
            try edge.link(&references, indices: indices)
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
            self.symbols[$0].commentOrigin ?? $0
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
    private 
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
    }
}
