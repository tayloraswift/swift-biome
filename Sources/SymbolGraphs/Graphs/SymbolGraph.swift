import JSON

public 
enum SymbolGraphDecodingError:Error, CustomStringConvertible 
{
    case duplicateAvailabilityDomain(Availability.Domain)
    case mismatchedCulture(ModuleIdentifier, expected:ModuleIdentifier)

    case invalidFragmentColor(String)
    case invalidEdge((USR, SymbolIdentifier), relation:String)
    
    public 
    var description:String 
    {
        switch self 
        {
        case .duplicateAvailabilityDomain(let domain):
            return "duplicate entries for availability domain '\(domain.rawValue)'"
        case .mismatchedCulture(let id, expected: let expected): 
            return "subgraph culture is '\(id)', expected '\(expected)'"
        case .invalidFragmentColor(let string): 
            return "invalid fragment color '\(string)'"
        case .invalidEdge(let edge, relation: let relation): 
            return "invalid edge '\(edge.0)' -- \(relation) -> '\(edge.1)'"
        }
    }
}

@frozen public 
struct SymbolGraph:Identifiable, Sendable 
{
    public 
    typealias Extension = (name:String, source:String)
    public 
    typealias Partition = (namespace:ModuleIdentifier, indices:Range<Int>)
    public 
    typealias Colony = (namespace:ModuleIdentifier, vertices:ArraySlice<Vertex<Int>>)

    @frozen public 
    struct Dependency:Decodable, Sendable
    {
        public
        var package:PackageIdentifier
        public
        var modules:[ModuleIdentifier]
        
        public 
        init(package:PackageIdentifier, modules:[ModuleIdentifier])
        {
            self.package = package 
            self.modules = modules 
        }
    }
    @frozen public 
    struct Colonies:RandomAccessCollection, Sendable
    {
        public 
        let partitions:[Partition]
        public 
        let vertices:[Vertex<Int>]
        
        @inlinable public 
        var startIndex:Int 
        {
            self.partitions.startIndex
        }
        @inlinable public 
        var endIndex:Int 
        {
            self.partitions.endIndex
        }
        @inlinable public 
        subscript(index:Int) -> 
        (
            namespace:ModuleIdentifier, 
            vertices:ArraySlice<Vertex<Int>>
        )
        {
            (
                self.partitions[index].namespace, 
                self.vertices[self.partitions[index].indices]
            )
        }
    }

    public 
    let id:ModuleIdentifier 
    public 
    let dependencies:[Dependency], 
        extensions:[Extension]
    private(set)
    var partitions:[Partition]
    public private(set)
    var identifiers:[SymbolIdentifier], 
        vertices:[Vertex<Int>], 
        edges:[Edge<Int>],
        hints:[Hint<Int>]
    public
    var sourcemap:[(uri:String, symbols:[SourceFeature<Int>])]
    
    public 
    var colonies:Colonies
    {
        .init(partitions: self.partitions, vertices: self.vertices)
    }
    
    public 
    init(parsing object:HLO) throws 
    {
        self.init(id: object.id, 
            dependencies: object.dependencies, 
            extensions: object.extensions, 
            subgraphs: try object.subgraphs.map(Subgraph.init(parsing:)))
    }
    public 
    init(id:ID, 
        dependencies:[Dependency] = [], 
        extensions:[Extension] = [], 
        subgraphs:[Subgraph] = [])
    {
        self.id = id
        self.extensions = extensions
        self.dependencies = dependencies 

        let subgraphs:[Subgraph] = subgraphs.sorted { $0.namespace < $1.namespace }
        // build the identifiers table. this table contains two zones: 
        //
        // -    zone 0: 
        //      all of the vertices stored in this symbolgraph, 
        //      in lexicographical order. the *i*’th identifier in this zone 
        //      is the identifier for the *i*’th vertex in the vertex array.
        //      this allows us to omit the index field from the vertex structures.
        self.partitions = []
        self.partitions.reserveCapacity(subgraphs.count)
        self.identifiers = []
        self.identifiers.reserveCapacity(subgraphs.reduce(0) { $0 + $1.vertices.count })

        var start:Int = self.identifiers.endIndex
        for subgraph:Subgraph in subgraphs 
        {
            self.identifiers.append(contentsOf: subgraph.vertices.map 
            {
                (community: $0.value.community, id: $0.key)
            }
            .sorted
            {
                $0 < $1
            }
            .lazy.map(\.id))

            self.partitions.append((subgraph.namespace, start ..< self.identifiers.endIndex))
            start = self.identifiers.endIndex 
        }
        // -    zone 1: 
        //      all remaining identifiers referenced by entities in this 
        //      symbolgraph, *in lexicographical order*. this requires 
        //      making a second pass over the symbolgraph data.
        var outlined:Set<SymbolIdentifier> = []
        var indices:[SymbolIdentifier: Int] = 
            .init(uniqueKeysWithValues: zip(self.identifiers, self.identifiers.indices))
        
        for subgraph:Subgraph in subgraphs 
        {
            for vertex:Vertex<SymbolIdentifier> in subgraph.vertices.values 
            {
                vertex.forEach
                {
                    if !indices.keys.contains($0) { outlined.insert($0) }
                }
            }
            for edge:Edge<SymbolIdentifier> in subgraph.edges 
            {
                edge.forEach 
                {
                    if !indices.keys.contains($0) { outlined.insert($0) }
                }
            }
            for hint:Hint<SymbolIdentifier> in subgraph.hints 
            {
                hint.forEach 
                {
                    if !indices.keys.contains($0) { outlined.insert($0) }
                }
            }
        }

        self.identifiers.append(contentsOf: outlined.sorted())
        let tail:ArraySlice<SymbolIdentifier> = self.identifiers[start...]

        indices.merge(zip(tail, tail.indices)) { $1 }

        // all the same keys, just rearranged
        self.vertices = []
        self.vertices.reserveCapacity(start - self.identifiers.startIndex)
        for (subgraph, partition):(Subgraph, Partition) in zip(subgraphs, self.partitions)
        {
            for id:SymbolIdentifier in self.identifiers[partition.indices]
            {
                self.vertices.append(subgraph.vertices[id]!.map { indices[$0]! })
            }
        }
        // this is only a well-defined sort within the same module!
        self.edges = subgraphs.flatMap 
        {
            $0.edges.map { $0.map { indices[$0]! } }
        }
        .sorted 
        {
            // this is not a well-defined order if there are multiple edges of different types 
            // between the same two vertices. this doesn’t affect the encoded output, since 
            // we partition by relation type.
            ($0.source, $0.target) < ($1.source, $1.target)
        }
        // uniquify hints
        var hints:Set<Hint<Int>> = []
        for subgraph:Subgraph in subgraphs 
        {
            for hint:Hint<SymbolIdentifier> in subgraph.hints
            {
                hints.insert(hint.map { indices[$0]! })
            }
        }
        self.hints = hints.sorted()

        var sourcemap:[String: [SourceFeature<Int>]] = [:]
        for subgraph:Subgraph in subgraphs 
        {
            for (uri, symbols):(String, [SourceFeature<SymbolIdentifier>]) in subgraph.sourcemap 
            {
                for symbol:SourceFeature<SymbolIdentifier> in symbols 
                {
                    sourcemap[uri, default: []].append(symbol.map { indices[$0]! })
                }
            }
        }
        self.sourcemap = sourcemap.map 
        {
            (uri: $0.key, symbols: $0.value.sorted())
        }
        .sorted
        {
            $0.uri < $1.uri
        }
    }
}

extension SymbolGraph 
{
    public 
    var serialized:JSON 
    {
        [
            "culture": .string(self.id.string),
            "dependencies": .array(self.dependencies.map(\.serialized)),
            "extensions": .array(self.extensions.map 
            {
                [ "name": .string($0.name), "source": .string($0.source) ]
            }), 
            "namespaces": .array(self.partitions.map 
            {
                [
                    "id": .string($0.namespace.string),
                    "communities": self.vertices[$0.indices].communities,
                ]
            }),
            "identifiers": .array(self.identifiers.map { .string($0.string) }),
            "vertices": .array(self.vertices.map(\.serialized)),
            "edges": self.edges.serialized,
            "hints": .array(self.hints.flatMap { [.number($0.source), .number($0.origin)] }),
            "sourcemap": .array(self.sourcemap.map 
            { 
                [
                    "uri": .string($0.uri),
                    "symbols": .array($0.symbols.flatMap 
                    { 
                        [
                            .number($0.line),
                            .number($0.character),
                            .number($0.symbol),
                        ]
                    })
                ]
            }),
        ]
    }
}
extension SymbolGraph.Dependency 
{
    var serialized:JSON 
    {
        [
            "package": .string(self.package.string),
            "modules": .array(self.modules.map { .string($0.string) }),
        ]
    }
}
extension Community 
{
    var serialized:JSON 
    {
        switch self 
        {
        case .protocol:                     return "protocol"
        case .associatedtype:               return "associatedtype"
        case .concretetype(.enum):          return "enum"
        case .concretetype(.struct):        return "struct"
        case .concretetype(.class):         return "class"
        case .concretetype(.actor):         return "actor"
        case .callable(.case):              return "case"
        case .callable(.initializer):       return "initializer"
        case .callable(.deinitializer):     return "deinitializer"
        case .callable(.typeSubscript):     return "typeSubscript"
        case .callable(.instanceSubscript): return "instanceSubscript"
        case .callable(.typeProperty):      return "typeProperty"
        case .callable(.instanceProperty):  return "instanceProperty"
        case .callable(.typeMethod):        return "typeMethod"
        case .callable(.instanceMethod):    return "instanceMethod"
        case .callable(.typeOperator):      return "typeOperator"
        case .global(.operator):            return "operator"
        case .global(.func):                return "func"
        case .global(.var):                 return "var"
        case .typealias:                    return "typealias"
        }
    }
}
extension Collection<SymbolGraph.Vertex<Int>> where Index == Int 
{
    var communities:JSON
    {
        guard var community:Community = self.first?.community 
        else 
        {
            return []
        }
        var communities:[(community:Community, range:Range<Int>)] = []
        var start:Int = self.startIndex
        for (end, vertex):(Int, SymbolGraph.Vertex<Int>) in zip(self.indices, self).dropFirst()
        {
            if vertex.community != community 
            {
                communities.append((community, start ..< end))
                community = vertex.community 
                start = end 
            }
        }
        if start < self.endIndex
        {
            communities.append((community, start ..< self.endIndex))
        }
        return .array(communities.map 
        { 
            [
                "community": $0.community.serialized, 
                "startIndex": .number($0.range.lowerBound),
                "endIndex": .number($0.range.upperBound),
            ] 
        })
    }
}
extension Sequence<SymbolGraph.Edge<Int>> 
{
    var serialized:JSON
    {
        var feature:[(Int, Int)] = []
        var member:[(Int, Int)] = []
        var subclass:[(Int, Int)] = []
        var override:[(Int, Int)] = []
        var requirement:[(Int, Int)] = []
        var optionalRequirement:[(Int, Int)] = []
        var defaultImplementation:[(Int, Int)] = []
        var conformer:[(Int, Int, [Generic.Constraint<Int>])] = []
        for edge:SymbolGraph.Edge<Int> in self 
        {
            switch edge.relation 
            {
            case .feature:                             feature.append((edge.source, edge.target))
            case .member:                               member.append((edge.source, edge.target))
            case .subclass:                           subclass.append((edge.source, edge.target))
            case .override:                           override.append((edge.source, edge.target))
            case .requirement:                     requirement.append((edge.source, edge.target))
            case .optionalRequirement:     optionalRequirement.append((edge.source, edge.target))
            case .defaultImplementation: defaultImplementation.append((edge.source, edge.target))

            case .conformer(let conditions): conformer.append((edge.source, edge.target, conditions))
            }
        }
        var items:[(key:String, value:JSON)] = conformer.isEmpty ? [] :
        [
            ("conformer", .array(conformer.flatMap 
            {
                [.number($0.0), .number($0.1), .array($0.2.map(\.serialized))]
            }))
        ]
        for (key, edges):(String, [(Int, Int)]) in 
        [
            ("feature", feature),
            ("member", member),
            ("subclass", subclass),
            ("override", override),
            ("requirement", requirement),
            ("optionalRequirement", optionalRequirement),
            ("defaultImplementation", defaultImplementation),
        ] 
            where !edges.isEmpty
        {
            items.append((key, .array(edges.flatMap { [.number($0.0), .number($0.1)] })))
        }
        return .object(items)
    }
}