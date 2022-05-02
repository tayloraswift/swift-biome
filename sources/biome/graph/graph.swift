import Highlight
import Resource
import JSON 

extension Package.Catalog
{
    func load(with loader:(Location, Resource.Text) async throws -> Resource) async throws -> [_Graph]
    {
        var graphs:[_Graph] = []
        for module:Module.Catalog<Location> in package.modules 
        {
            graphs.append(try await .init(loading: module, with: loader))
        }
        return graphs
    }
}
extension Module.Catalog 
{
    func load(with loader:(Location, Resource.Text) async throws -> Resource) async throws -> _Graph
    {
        let core:Subgraph = try await .init(loading: self.id, from: self.graphs.core, with: loader)
        var extensions:[Subgraph] = []
        for (namespace, location):(Module.ID, Location) in self.extensions 
        {
            extensions.append(try await .init(loading: self.id, extending: namespace, from: location, with: loader))
        }
        return .init(core: core, extensions: extensions, dependencies: self.dependencies)
    }
}
struct Supergraph 
{
    let package:(id:Package.ID, index:Package.Index)
    
    private(set)
    var opinions:[(symbol:Symbol.Index, has:Symbol.ExtrinsicRelationship)],
        modules:[Module] = []
    private 
    var vertices:[Vertex] = []
    private
    var indices:
    (
        modules:[Module.ID: Module.Index],
        symbols:[Symbol.ID: Symbol.Index]
    )
    
    init(package:(id:Package.ID, index:Package.Index)) 
    {
        self.package = package 
        
        self.opinions = []
        self.vertices = []
        self.modules = []
        self.indices = ([:], [:])
    }
        
    // for now, we can only call this *once*!
    // TODO: implement progressive supergraph updates 
    mutating 
    func linearize(_ graphs:[_Graph], given biome:Biome) throws 
    {
        self.modules = []
        self.indices.modules = .init(uniqueKeysWithValues: graphs.enumerated().map 
        {
            ($0.1.core.id, .init(self.package.index, offset: $0.0))
        })
        
        try self.populate(from: graphs, given: biome)
        try self.link(from: graphs, given: biome)
    }

    private mutating 
    func populate(from graphs:[_Graph], given biome:Biome) throws 
    {
        for graph:_Graph in graphs
        {
            let dependencies:[[(key:Module.ID, value:Module.Index)]] = try graph.dependencies.map 
            {
                (dependency:_Graph.Dependency) in 
                
                guard let local:[Module.ID: Module.Index] = dependency.package == self.package.id ? 
                    self.indices.modules : biome[dependency.package]?.trunks 
                else 
                {
                    throw PackageIdentityError.undefined(dependency.package)
                }
                return try dependency.modules.map 
                {
                    guard let index:Module.Index = local[$0] 
                    else 
                    {
                        throw ModuleIdentityError.undefined(dependency.package, $0)
                    }
                    return ($0, index)
                }
            }
            //  all of a module’s dependencies have unique names, so build a lookup 
            //  table for them. this lookup table enables this function to 
            //  run in quadratic time; otherwise it would be cubic!
            let bystanders:[Module.ID: Module.Index] = .init(uniqueKeysWithValues: dependencies.joined())

            let core:Range<Int> = try self.populate(graph.core.namespace, from: graph.core)
            let colonies:[Colony] = try graph.extensions.compactMap
            {
                if let bystander:Module.Index = bystanders[$0.namespace]
                {
                    return (bystander, try self.populate(graph.core.namespace, from: $0))
                }
                else 
                {
                    print("warning: module \(graph.core.namespace) extends \($0.namespace), which is not one of its dependencies")
                    print("warning: skipped subgraph \(graph.core.namespace)@\($0.namespace)")
                    return nil
                }
            }
            let module:Module = .init(id: graph.core.namespace, 
                dependencies: dependencies.map { $0.map(\.value) }, 
                core: core, colonies: colonies)
            {
                // a vertex is top-level if it has exactly one path component. 
                self.vertices[$0].path.count == 1
            }
            self.modules.append(module)
        }
    }
    private mutating 
    func populate(_ perpetrator:Module.ID, from subgraph:Subgraph) throws -> Range<Int>
    {
        // about half of the symbols in a typical symbol graph are non-canonical. 
        // (i.e., they are inherited by victims). in theory, these symbols can 
        // recieve documentation through article bindings, but it is very 
        // unlikely that the symbol graph vertices themselves contain 
        // useful information. 
        // 
        // that said, we cannot ignore non-canonical symbols altogether, because 
        // if their canonical base originates from an underscored protocol 
        // (or is implicitly private itself), then the non-canonical symbols 
        // are our only source of information about the canonical base. 
        // 
        // example: UnsafePointer.predecessor() actually originates from 
        // the witness `ss8_PointerPsE11predecessorxyF`, which is part of 
        // the underscored `_Pointer` protocol.
        let module:Module.Index = .init(self.package.index, offset: self.modules.endIndex)
        
        let start:Int = self.vertices.endIndex
        for vertex:Vertex in subgraph.vertices 
        {
            let symbol:Symbol.Index = .init(module, offset: self.vertices.endIndex)
            // FIXME: all vertices can have duplicates, even canonical ones, due to 
            // the behavior of `@_exported import`.
            if  vertex.isCanonical 
            {
                if let incumbent:Int = self.indices.updateValue(symbol, forKey: vertex.id)
                {
                    throw Symbol.CollisionError.init(vertex.id, from: perpetrator) 
                }
                self.vertices.append(vertex)
            }
            // *not* subgraph.namespace !
            else if case nil = self.indices.index(forKey: vertex.id), 
                vertex.id.isUnderscoredProtocolExtensionMember(from: perpetrator)
            {
                // if the symbol is synthetic and belongs to an underscored 
                // protocol, assume the generic base does not exist, and register 
                // it *once*.
                self.indices.updateValue(symbol, forKey: vertex.id)
                self.vertices.append(vertex)
            }
        }
        let end:Int = self.vertices.endIndex
        return start ..< end
    }
    
    private 
    subscript(vertex:Symbol.Index) -> Vertex?
    {
        self.package.index == vertex.module.package ? self.vertices[vertex.offset] : nil
    }
    
    private mutating 
    func link(from graphs:[_Graph], given biome:Biome) throws 
    {
        let scopes:[Module.Scope] = self.modules.indices.map
        {
            (offset:Int) in 
            
            let module:Module.Index = .init(self.package.index, offset: offset)
            
            // compute scope 
            let filter:Set<Module.Index> = [module].union(self.modules[offset].dependencies.joined())
            let scope:Module.Scope = .init(filter: filter, layers: 
                Set<Package.Index>.init(filter.map(\.package)).map 
            {
                $0 == module.package ? self.indices.symbols : biome[$0].indices.symbols
            })
            
            for edge:Edge in edges
            {
                let source:Symbol.ColoredIndex
                let target:Symbol.ColoredIndex
                
                source.index = try scope.index(of: edge.source)
                target.index = try scope.index(of: edge.target)
                
                source.color = self[source.index]?.color ?? biome[source.index].color
                target.color = self[target.index]?.color ?? biome[target.index].color
                
                let sponsor:Symbol.Index? = try edge.sponsor.map(scope.index(of:))
                let constraints:[SwiftConstraint<Symbol.Index>] = try edge.constraints.map
                {
                    try $0.map(scope.index(of:))
                }
                
                let relationship:(source:Symbol.Relationship?, target:Symbol.Relationship) = 
                    try edge.kind.relationships(source, target, where: constraints)
                
                try self.link(target.index, relationship.target, accordingTo: module)
                if let relationship:Symbol.Relationship = relationship.source 
                {
                    try self.link(source.index, relationship, accordingTo: module)
                }
            }
            
            return scope
        }
    }
    private mutating 
    func link(_ symbol:Symbol.Index, _ relationship:Symbol.Relationship, 
        accordingTo perpetrator:Module.Index) throws
    {
        switch relationship
        {
        case  .is(let intrinsic):
            if perpetrator == symbol.module
            {
                self.vertices[symbol.offset].relationships.append(relationship)
            }
            else 
            {
                throw Symbol.RelationshipError.miscegenation(perpetrator, says: symbol, is: intrinsic)
            }
        
        case .has(let extrinsic):
            if self.package.index == symbol.module.package
            {
                self.vertices[symbol.offset].relationships.append(relationship)
            }
            else 
            {
                self.opinions.append((symbol, has: extrinsic))
            }
        }
    }
}
struct _Graph 
{
    struct Dependency:Decodable
    {
        let package:Package.ID
        let modules:[Module.ID]
    }
    
    private(set)
    var core:Subgraph,
        extensions:[Subgraph],
        dependencies:[Dependency]
    
    var hash:Resource.Version? 
    {
        self.extensions.reduce(self.core.hash) 
        {
            $0 * $1.hash
        }
    }
}
struct Subgraph 
{
    /* struct LoadingError:Error 
    {
        let underlying:Error
        let module:Module.ID, 
            bystander:Module.ID?
        
        init(_ underlying:Error, module:Module.ID, bystander:Module.ID?)
        {
            self.underlying = underlying
            self.module     = module
            self.bystander  = bystander
        }
    } */

    /* enum SymbolError:Error 
    {
        // global errors 
        case disputed(Vertex, Vertex)
        case undefined(id:Symbol.ID)
    } */
    
    private 
    let vertices:[Vertex]
    private 
    let edges:[Edge]
    let hash:Resource.Version?
    let namespace:Module.ID
    
    init<Location>(loading perpetrator:Module.ID, extending namespace:Module.ID? = nil, 
        from location:Location, 
        with load:(Location, Resource.Text) async throws -> Resource) async throws 
    {
        let loaded:(json:JSON, hash:Resource.Version?)
        switch try await load(location, .json)
        {
        case    .text   (let string, type: _, version: let version):
            loaded.json = try Grammar.parse(string.utf8, as: JSON.Rule<String.Index>.Root.self)
            loaded.hash = version
        
        case    .binary (let bytes, type: _, version: let version):
            json = try Grammar.parse(bytes, as: JSON.Rule<Array<UInt8>.Index>.Root.self)
            loaded.hash = version
        }
        try self.init(loading: perpetrator, extending: namespace, from: loaded)
    }
    private 
    init(loading perpetrator:Module.ID, extending namespace:Module.ID? = nil, 
        from loaded:(json:JSON, hash:Resource.Version?)) throws 
    {
        self.hash = loaded.hash 
        self.namespace = namespace ?? perpetrator
        (self.vertices, self.edges) = try loaded.json.lint(["metadata"]) 
        {
            let edges:[Edge]      = try $0.remove("relationships") { try $0.map(  Edge.init(from:)) }
            let vertices:[Vertex] = try $0.remove("symbols")       { try $0.map(Vertex.init(from:)) }
            let module:Module.ID  = try $0.remove("module")
            {
                try $0.lint(["platform"]) 
                {
                    Module.ID.init(try $0.remove("name", as: String.self))
                }
            }
            guard module == perpetrator
            else 
            {
                throw _ModuleError.mismatched(id: module)
            }
            return (vertices, edges)
        }
    }
    
    func populate(_ edges:inout Set<Edge>) throws
    {
        for edge:Edge in self.edges 
        {
            guard let incumbent:Edge = edges.update(with: edge)
            else 
            {
                continue 
            }
            guard   incumbent.origin      == edge.origin, 
                    incumbent.constraints == edge.constraints 
            else 
            {
                throw EdgeError.disputed(incumbent, edge)
            }
        }
    }
}
extension SwiftConstraint where Link == Symbol.ID 
{
    init(from json:JSON) throws
    {
        self = try json.lint 
        {
            let verb:SwiftConstraintVerb = try $0.remove("kind") 
            {
                switch try $0.as(String.self) as String
                {
                case "superclass":
                    return .subclasses
                case "conformance":
                    return .implements
                case "sameType":
                    return .is
                case let kind:
                    throw SwiftConstraintError.undefined(kind: kind)
                }
            }
            return .init(
                try    $0.remove("lhs", as: String.self), verb, 
                try    $0.remove("rhs", as: String.self), 
                link: try $0.pop("rhsPrecise", Symbol.ID.init(from:)))
        }
    }
}
extension Symbol.ID 
{
    init(from json:JSON) throws 
    {
        let string:String = try json.as(String.self)
        self = try Grammar.parse(string.utf8, as: URI.Rule<String.Index, UInt8>.USR.OpaqueName.self)
    }
}
