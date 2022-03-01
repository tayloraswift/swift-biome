import JSON 
import Resource

public 
struct Biome:Sendable 
{
    public 
    struct DecodingError<Descriptor, Model>:Error 
    {
        let expected:Any.Type, 
            path:String, 
            encountered:Descriptor?
        
        init(expected:Any.Type, in path:String = "", encountered:Descriptor?)
        {
            self.expected       = expected 
            self.path           = path 
            self.encountered    = encountered
        }
    }
    
    /* public 
    enum Complexity:Sendable 
    {
        case constant
        case linear
        case logLinear
    } */
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
    public 
    enum Topic:Hashable, Sendable, CustomStringConvertible 
    {
        // case requirements 
        // case defaults
        case custom(String)
        case automatic(Automatic)
        case cluster(String)
        
        public
        var description:String 
        {
            switch self 
            {
            // case .requirements:         return "Requirements"
            // case .defaults:             return "Default Implementations"
            case .custom(let heading):      return heading 
            case .automatic(let automatic): return automatic.heading 
            case .cluster(_):               return "See Also"
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
            modules.append(contentsOf: targets.sorted { $0.key.identifier < $1.key.identifier })
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
    
    static 
    func load(packages names:[Package.ID: [String]], prefix:[String], 
        loader load:(_ package:Package.ID, _ module:String) async throws -> Resource) 
        async throws -> (biome:Self, comments:[String])
    {
        let (names, targets):([(id:Package.ID, targets:Range<Int>)], [Target]) = Self.modules(names)
        
        let packageIndices:[Package.ID: Int]    = try Self.indices(for: names, by: \.id, 
            else: PackageIdentifierError.duplicate(package:))
        let moduleIndices:[Module.ID: Int]      = try Self.indices(for: targets, by: \.module, 
            else: ModuleIdentifierError.duplicate(module:))
        var symbolIndices:[Symbol.ID: Int]      = [:]
        var edges:[Edge]        = []
        var vertices:[Vertex]   = []
        var modules:[Module]    = []
        var packages:[Package]  = []
        for package:(id:Package.ID, targets:Range<Int>) in names 
        {
            var version:Resource.Version = .semantic(0, 1, 1)
            for target:(module:Module.ID, bystanders:[Module.ID]) in targets[package.targets]
            {
                func graph(_ module:Module.ID, bystander:Module.ID?) async throws -> Range<Int>
                {
                    let name:String = bystander.map { "\(module.identifier)@\($0.identifier)" } ?? module.identifier
                    let json:JSON
                    switch try await load(package.id, name)
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
                    let descriptor:(module:Module.ID, vertices:[Vertex], edges:[Edge]) = try Biome.decode(module: json)
                    guard descriptor.module == target.module 
                    else 
                    {
                        throw ModuleIdentifierError.mismatch(decoded: descriptor.module, expected: target.module)
                    }
                    
                    var blacklisted:Set<Symbol.ID> = []
                    let start:Int   = vertices.endIndex
                    for vertex:Vertex in descriptor.vertices 
                    {
                        if case nil = symbolIndices.index(forKey: vertex.id)
                        {
                            symbolIndices.updateValue(vertices.endIndex, forKey: vertex.id)
                            vertices.append(vertex)
                        }
                        else 
                        {
                            // duplicate symbol id. 
                            // if the symbol is synthetic, and extends a different module, 
                            // ignore and blacklist. otherwise, throw an error immediately
                            guard case (_?, .synthesized) = (bystander, vertex.id)
                            else 
                            {
                                throw SymbolIdentifierError.duplicate(symbol: vertex.id, in: module, bystander: bystander) 
                            }
                            blacklisted.insert(vertex.id)
                        }
                    }
                    let end:Int     = vertices.endIndex
                    
                    if blacklisted.count != 0 
                    {
                        print("blacklisted \(blacklisted.count) duplicate vert(ex/icies) in '\(name)'")
                    }
                    
                    var pruned:Int = 0
                    for edge:Edge in descriptor.edges 
                    {
                        switch (blacklisted.contains(edge.source), blacklisted.contains(edge.target))
                        {
                        case (false, false):
                            edges.append(edge)
                        case (true,  false):
                            guard   case .member = edge.kind,
                                    case .natural(let scope) = edge.target, 
                                    case .synthesized(_, for: scope) = edge.source
                            else 
                            {
                                fallthrough 
                            }
                            // allow recovery
                            pruned += 1
                        case (true, true): 
                            // if we didn’t throw an error before, throw it now 
                            throw SymbolIdentifierError.duplicate(symbol: edge.source, in: module, bystander: bystander) 
                        case (false, true): 
                            // if we didn’t throw an error before, throw it now 
                            throw SymbolIdentifierError.duplicate(symbol: edge.target, in: module, bystander: bystander) 
                        }
                    }
                    
                    if pruned != 0 
                    {
                        print("pruned \(pruned) duplicate edge(s) with blacklisted endpoints in '\(name)'")
                    }
                    
                    return start ..< end
                }
                let core:Range<Int> = try await graph(target.module, bystander: nil)
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
                    extensions.append((index, try await graph(target.module, bystander: bystander)))
                }
                let path:Path       = .init(prefix: prefix, package: package.id, namespace: target.module)
                let module:Module   = .init(id: target.module, package: packages.endIndex, 
                    path: path, core: core, extensions: extensions)
                modules.append(module)
                
                if target.bystanders.isEmpty
                {
                    print("loaded module '\(target.module.identifier)' (from package '\(package.id.name)')")
                }
                else 
                {
                    print("loaded module '\(target.module.identifier)' (from package '\(package.id.name)', bystanders: \(target.bystanders.map{ "'\($0.identifier)'" }.joined(separator: ", ")))")
                }
            }
            let path:Path       = .init(prefix: prefix, package: package.id)
            let package:Package = .init(id: package.id, path: path, modules: package.targets, hash: version)
            packages.append(package)
        }
        
        print("loaded \(vertices.count) vertices and \(edges.count) edges from \(modules.count) module(s)")
        
        let biome:Biome = try .init(prefix: prefix, 
            indices:    symbolIndices, 
            vertices:   vertices, 
            edges:      edges, 
            modules:   .init(indices: _move(moduleIndices),  elements: modules), 
            packages:  .init(indices: _move(packageIndices), elements: packages))
        
        var _memory:Int 
        {
            MemoryLayout<Module>.stride * biome.modules.count + MemoryLayout<Symbol>.stride * biome.symbols.count
        }
        print("initialized biome (\(_memory >> 10) KB)")
        return (biome, vertices.map(\.comment))
    }
    private 
    init(prefix:[String], indices:[Symbol.ID: Int], vertices:[Vertex], edges:[Edge], 
        modules:Storage<Module>, packages:Storage<Package>)
        throws
    {
        //  link 
        var references:[Edge.References]    = .init(repeating: .init(), count: vertices.count)
        for edge:Edge in _move(edges)
        {
            guard   let source:Int = indices[edge.source], 
                    let target:Int = indices[edge.target]
            else 
            {
                print("warning: undefined symbol id in edge '\(edge.source)' -> '\(edge.target)'")
                continue 
            } 
            try edge.link(source, to: target, in: &references)
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
                vertices[$0].title < vertices[$1].title
            }
        }
        // breadcrumbs
        let breadcrumbs:[Breadcrumbs] = modules.indices.flatMap
        {
            (module:Int) -> [Breadcrumbs] in
            
            let packageID:Package.ID        = packages[modules[module].package].id, 
                moduleID:Module.ID          = modules[module].id
            var breadcrumbs:[Breadcrumbs]   = modules[module].symbols.core.map 
            {
                .init(package:  packageID, 
                    graph:     .init(module: moduleID, bystander: nil), 
                    module:     module, 
                    bystander:  nil, 
                    path:       vertices[$0].path)
            }
            for (bystander, symbols):(Int, Range<Int>) in modules[module].symbols.extensions
            {
                let packageID:Package.ID    = packages[modules[bystander].package].id,
                    bystanderID:Module.ID   = modules[bystander].id
                for index:Int in symbols
                {
                    breadcrumbs.append(.init(package: packageID, 
                        graph:     .init(module: moduleID, bystander: bystanderID), 
                        module:     module, 
                        bystander:  bystander, 
                        path:       vertices[index].path))
                }
            }
            return breadcrumbs
        }
        var paths:[Path] = breadcrumbs.indices.map
        {
            switch vertices[$0].kind 
            {
            case    .associatedtype, .typealias, .enum, .struct, .class, .actor, .protocol, .var, .func, .operator:
                return .init(prefix: prefix, breadcrumbs[$0], dot: false)
            case    .case, .initializer, .deinitializer, 
                    .typeSubscript, .instanceSubscript, 
                    .typeProperty, .instanceProperty, 
                    .typeMethod, .instanceMethod:
                return .init(prefix: prefix, breadcrumbs[$0], dot: true)
            }
        }
        // parents
        let table:[String: [Int]] = .init(grouping: vertices.indices)
        {
            paths[$0].group
        }
        var parents:[Int?] = .init(repeating: nil, count: vertices.count)
        for index:Int in vertices.indices 
        {
            guard let parent:Breadcrumbs = breadcrumbs[index].parent
            else 
            {
                // is a top-level symbol  
                continue 
            }
            let path:Path = .init(prefix: prefix, parent, dot: false)
            guard   let matches:[Int] = table[path.group], 
                    let parent:Int = matches.first
            else 
            {
                throw LinkingError.orphaned(symbol: index)
            }
            guard matches.count == 1
            else 
            {
                throw LinkingError.junction(symbol: index)
            }
            parents[index] = parent 
        }
        // canonical paths. if paths collide, *every* symbol in 
        // the path group gets a disambiguation tag 
        for overloads:[Int] in table.values where overloads.count > 1
        {
            for overload:Int in overloads 
            {
                paths[overload].disambiguation = vertices[overload].id
            }
        }
        let symbols:Storage<Symbol> = .init(indices: indices, elements: 
            try vertices.indices.map 
        {
            try .init(modules:  modules, 
                path:           paths[$0], 
                breadcrumbs:    breadcrumbs[$0], 
                parent:         parents[$0], 
                relationships:  relationships[$0],
                vertex:         vertices[$0])
        })
        self.init(packages: packages, 
            modules: modules, 
            symbols: symbols)
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
                guard case nil = symbols[symbol].breadcrumbs.parent
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
        
        // topics 
        for index:Int in self.modules.indices 
        {
            let groups:[Bool: [Int]] = self.partition(symbols: self.modules[index].toplevel)
            self.modules[index].topics.members.append(contentsOf: self.organize(symbols: groups[false, default: []]))
            self.modules[index].topics.removed.append(contentsOf: self.organize(symbols: groups[true,  default: []]))
        }
        for index:Int in self.symbols.indices 
        {
            if case .protocol(let abstract) = self.symbols[index].relationships 
            {
                self.symbols[index].topics.requirements.append(contentsOf: self.organize(symbols: abstract.requirements))
            }
            guard let members:[Int] = self.symbols[index].relationships.members
            else 
            {
                continue 
            }
            let groups:[Bool: [Int]] = self.partition(symbols: members)
            self.symbols[index].topics.members.append(contentsOf: self.organize(symbols: groups[false, default: []]))
            self.symbols[index].topics.removed.append(contentsOf: self.organize(symbols: groups[true,  default: []]))
        }
    }
    private 
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
    private 
    func organize(symbols:[Int]) -> [(heading:Biome.Topic, indices:[Int])]
    {
        let topics:[Topic.Automatic: [Int]] = .init(grouping: symbols)
        {
            self.symbols[$0].kind.topic
        }
        return Topic.Automatic.allCases.compactMap
        {
            (topic:Topic.Automatic) in 
            guard let indices:[Int] = topics[topic]
            else 
            {
                return nil 
            }
            return (.automatic(topic), indices)
        }
    }
}
extension Biome.Topic 
{
    public 
    enum Automatic:String, Sendable, Hashable, CaseIterable
    {
        case module             = "Modules"
        case `case`             = "Enumeration Cases"
        case `associatedtype`   = "Associated Types"
        case `typealias`        = "Typealiases"
        case initializer        = "Initializers"
        case deinitializer      = "Deinitializers"
        case typeSubscript      = "Type Subscripts"
        case instanceSubscript  = "Instance Subscripts"
        case typeProperty       = "Type Properties"
        case instanceProperty   = "Instance Properties"
        case typeMethod         = "Type Methods"
        case instanceMethod     = "Instance Methods"
        case global             = "Global Variables"
        case function           = "Functions"
        case `operator`         = "Operators"
        case `enum`             = "Enumerations"
        case `struct`           = "Structures"
        case `class`            = "Classes"
        case actor              = "Actors"
        case `protocol`         = "Protocols"
        
        var heading:String 
        {
            self.rawValue
        }
    }
}

extension Biome 
{
    struct Breadcrumbs:Hashable 
    {
        let package:Package.ID
        let graph:Graph
        let module:Int 
        let bystander:Int? 
        let path:[String]
        
        var last:String 
        {
            guard let last:String = path.last 
            else 
            {
                fatalError("unreachable")
            }
            return last 
        }
        
        var parent:Self? 
        {
            let path:ArraySlice = self.path.dropLast()
            if path.isEmpty 
            {
                return nil 
            }
            else 
            {
                return .init(package: self.package, graph: self.graph, 
                    module:     self.module, 
                    bystander:  self.bystander, 
                    path: [String].init(path))
            }
        }
        
        var lexemes:[Language.Lexeme] 
        {
            var lexemes:[Language.Lexeme]   = []
                lexemes.reserveCapacity(self.path.count * 2 - 1)
            for current:String in self.path.dropLast() 
            {
                lexemes.append(.code(current,   class: .identifier))
                lexemes.append(.code(".",       class: .punctuation))
            }
            lexemes.append(.code(self.last,     class: .identifier))
            return lexemes
        }
    }

}
