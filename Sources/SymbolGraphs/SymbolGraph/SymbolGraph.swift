import SymbolSource 

public 
enum SymbolGraphDecodingError:Error, CustomStringConvertible 
{
    case mismatchedCulture(ModuleIdentifier, expected:ModuleIdentifier)

    case unknownDeclarationKind(String) 
    case unknownFragmentKind(String)
    case unknownRelationshipKind(String)
    case invalidRelationshipKind(USR, is:String)
    
    public 
    var description:String 
    {
        switch self 
        {
        case .mismatchedCulture(let id, expected: let expected): 
            return "subgraph culture is '\(id)', expected '\(expected)'"
        case .unknownDeclarationKind(let string): 
            return "unknown declaration kind '\(string)'"
        case .unknownFragmentKind(let string): 
            return "unknown fragment kind '\(string)'"
        case .unknownRelationshipKind(let string): 
            return "unknown relationship kind '\(string)'"
        case .invalidRelationshipKind(let source, is: let string): 
            return "symbol '\(source)' cannot be the source of a relationship of kind '\(string)'"
        }
    }
}
public
enum SymbolGraphValidationError:Error
{
    case cyclicModuleDependency
    case cyclicDocumentationCommentDependency(SymbolIdentifier)
}

@frozen public
struct SymbolGraph
{
    public
    let id:PackageIdentifier

    public private(set)
    var identifiers:[SymbolIdentifier]
    public private(set)
    var vertices:[Vertex<Int>]
    public
    let snippets:[SnippetFile]
    @usableFromInline private(set) 
    var partitions:[CulturalPartition]

    init(id:PackageIdentifier, identifiers:[SymbolIdentifier],
        vertices:[Vertex<Int>],
        snippets:[SnippetFile],
        partitions:[CulturalPartition])
    {
        self.id = id
        self.identifiers = identifiers
        self.vertices = vertices
        self.snippets = snippets
        self.partitions = partitions
    }
}

extension SymbolGraph
{
    init(id:PackageIdentifier, compiling targets:[RawCulturalGraph], 
        snippets:[SnippetFile]) throws
    {
        let targets:[RawCulturalGraph] = try (_move targets).topologicallySorted(for: id)
        try self.init(id: id, compiling: try (_move targets).map(CulturalGraph.init(_:)),
            snippets: snippets)
    }

    init(id:PackageIdentifier, compiling targets:[CulturalGraph], 
        snippets:[SnippetFile]) throws
    {
        self.id = id
        self.snippets = snippets

        let capacity:Int = targets.reduce(0)
        {
            $0 + $1.colonies.reduce(0) { $0 + $1.vertices.count }
        }

        self.identifiers = []
        self.identifiers.reserveCapacity(capacity)

        // build the identifiers table. this table contains two zones: 
        //
        // -    zone 0: 
        //      all of the vertices stored in this symbolgraph, 
        //      in lexicographical order. the *i*’th identifier in this zone 
        //      is the identifier for the *i*’th (cumulative) vertex in the vertex arrays.
        //      this allows us to omit the index field from the vertex structures.
        var cultures:[[ColonialPartition]] = []
            cultures.reserveCapacity(targets.count)
        var start:Int = self.identifiers.endIndex
        for culture:CulturalGraph in targets
        {
            var colonies:[ColonialPartition] = []
                colonies.reserveCapacity(culture.colonies.count)
            
            for colony:ColonialGraph in culture.colonies 
            {
                self.identifiers.append(contentsOf: colony.vertices.map 
                {
                    (shape: $0.value.shape, id: $0.key)
                }
                .sorted
                {
                    $0 < $1
                }
                .lazy.map(\.id))

                let end:Int = self.identifiers.endIndex
                colonies.append(.init(namespace: colony.namespace, vertices: start ..< end))
                start = end
            }
            cultures.append(colonies)
        }
        // -    zone 1: 
        //      all remaining identifiers referenced by entities in this 
        //      symbolgraph, *in lexicographical order*. this requires 
        //      making a second pass over the symbolgraph data.
        var outlined:Set<SymbolIdentifier> = []
        var indices:[SymbolIdentifier: Int] = 
            .init(uniqueKeysWithValues: zip(self.identifiers, self.identifiers.indices))
        
        for culture:CulturalGraph in targets
        {
            for colony:ColonialGraph in culture.colonies
            {
                for vertex:Vertex<SymbolIdentifier> in colony.vertices.values 
                {
                    vertex.forEach
                    {
                        if !indices.keys.contains($0) { outlined.insert($0) }
                    }
                }
                for edge:Edge<SymbolIdentifier> in colony.edges 
                {
                    edge.forEach 
                    {
                        if !indices.keys.contains($0) { outlined.insert($0) }
                    }
                }
                for hint:Hint<SymbolIdentifier> in colony.hints 
                {
                    hint.forEach 
                    {
                        if !indices.keys.contains($0) { outlined.insert($0) }
                    }
                }
            }
        }

        self.identifiers.append(contentsOf: outlined.sorted())
        let tail:ArraySlice<SymbolIdentifier> = self.identifiers[start...]

        indices.merge(zip(tail, tail.indices)) { $1 }

        self.vertices = []
        self.partitions = []
        self.vertices.reserveCapacity(capacity)
        self.partitions.reserveCapacity(targets.count)
        for (culture, colonies):(CulturalGraph, [ColonialPartition]) in 
            zip(targets, _move cultures)
        {
            let vertices:Range<Int> = 
                (colonies.first?.vertices.lowerBound ?? self.vertices.endIndex) ..<
                (colonies.last?.vertices.upperBound ?? self.vertices.endIndex)
            
            assert(self.vertices.endIndex == vertices.lowerBound)

            // all the same keys, just rearranged
            for (colony, partition):(ColonialGraph, ColonialPartition) in 
                zip(culture.colonies, colonies)
            {
                for id:SymbolIdentifier in self.identifiers[partition.vertices]
                {
                    self.vertices.append(colony.vertices[id]!.map { indices[$0]! })
                }
            }

            assert(self.vertices.endIndex == vertices.upperBound)


            var sourcemap:[String: [SwiftFile.Feature]] = [:]
            for colony:ColonialGraph in culture.colonies
            {
                for (uri, symbols):(String, [ColonialGraph.SourceFeature]) in 
                    colony.sourcemap 
                {
                    for symbol:ColonialGraph.SourceFeature in symbols 
                    {
                        sourcemap[uri, default: []].append(.init(line: symbol.line,
                            character: symbol.character,
                            vertex: indices[symbol.id]!))
                    }
                }
            }

            self.partitions.append(.init(id: culture.id, 
                dependencies: culture.dependencies, 
                markdown: culture.markdown,
                sources: sourcemap.map 
                {
                    .init(uri: $0.key, features: $0.value.sorted())
                }
                .sorted
                {
                    $0.uri < $1.uri
                },
                colonies: colonies, 
                vertices: vertices, 
                edges: culture.colonies.flatMap 
                {
                    $0.edges.map { $0.map { indices[$0]! } }
                }
                .sorted 
                {
                    // this is only a well-defined sort within the same module!
                    // this is not a well-defined sort if there are multiple edges of different types 
                    // between the same two vertices. this doesn’t affect the encoded output, since 
                    // we partition by relation type.
                    ($0.source, $0.target) < ($1.source, $1.target)
                }))
        }

        // uniquify hints
        var uptree:[Int: Int] = [:]
        for culture:CulturalGraph in _move targets
        {
            for colony:ColonialGraph in culture.colonies
            {
                // synthetics generate hints that make sense to lib/SymbolGraphGen, 
                // but look like loopbacks to us. so we need to explicitly look for 
                // and ignore these self-hints.
                for hint:Hint<SymbolIdentifier> in colony.hints
                    where hint.source != hint.origin
                {
                    let hint:Hint<Int> = hint.map { indices[$0]! } 
                    if  hint.source < self.vertices.endIndex 
                    {
                        uptree[hint.source] = hint.origin
                    }
                }
            }
        }
        try self.apply(hints: uptree)
    }

    private mutating 
    func apply(hints:[Int: Int]) throws
    {
        for (source, origin):(Int, Int) in hints 
        {
            if case nil = self.vertices[source].comment.extends 
            {
                self.vertices[source].comment.extends = origin
            }
        }
        // delete comments if a hint indicates it is duplicated. 
        // this does not preclude the need to prune again when documentation 
        // from multiple modules in the same package are combined (yet)
        // var pruned:Int = 0
        for index:Int in self.vertices.indices
        {
            let comment:Vertex<Int>.Comment = self.vertices[index].comment 
            if  let string:String = comment.string, 
                let origin:Int = comment.extends, 
                    origin < self.vertices.endIndex, 
                case string? = self.vertices[origin].comment.string
            {
                self.vertices[index].comment.string = nil
                // pruned += 1
            }
        }
        // print("pruned \(pruned) duplicate comments")

        // fast-forward inheritance chains until we either reach a package 
        // boundary, or a local symbol that has documentation. 
        for index:Int in self.vertices.indices
        {
            let comment:Vertex<Int>.Comment = self.vertices[index].comment 

            guard   case nil = comment.string,
                    var origin:Int = comment.extends, 
                        origin < self.vertices.endIndex
            else
            {
                continue 
            }

            var visited:Set<Int> = []
            fastforwarding:
            while true
            {
                guard case nil = visited.update(with: origin)
                else
                {
                    throw SymbolGraphValidationError
                        .cyclicDocumentationCommentDependency(self.identifiers[index])
                }

                let original:Vertex<Int>.Comment = self.vertices[origin].comment
                switch (original.extends, original.string)
                {
                case (let next?, nil): 
                    if next < self.vertices.endIndex
                    {
                        origin = next 
                        // skipped += 1
                        continue fastforwarding
                    }
                    
                    self.vertices[index].comment.extends = origin
                
                case (_,          _?): 
                    self.vertices[index].comment.extends = origin
                
                case (nil,       nil): 
                    self.vertices[index].comment.extends = nil 
                    // dropped += 1
                }

                break fastforwarding
            }
        }
    }
}
extension SymbolGraph:RandomAccessCollection
{
    @inlinable public
    var startIndex:Int
    {
        self.vertices.startIndex
    }
    @inlinable public
    var endIndex:Int
    {
        self.vertices.endIndex
    }
    @inlinable public
    subscript(index:Int) -> (id:SymbolIdentifier, vertex:SymbolGraph.Vertex<Int>)
    {
        (self.identifiers[index], self.vertices[index])
    }
}

extension SymbolGraph
{
    @inlinable public
    var cultures:Cultures
    {
        .init(self)
    }

    @frozen public
    struct Cultures
    {
        @usableFromInline
        let graph:SymbolGraph

        @inlinable public
        init(_ graph:SymbolGraph)
        {
            self.graph = graph
        }
    }
}
extension SymbolGraph.Cultures:RandomAccessCollection
{
    @inlinable public
    var startIndex:Int
    {
        self.graph.partitions.startIndex
    }
    @inlinable public
    var endIndex:Int
    {
        self.graph.partitions.endIndex
    }
    @inlinable public
    subscript(index:Int) -> SymbolGraph.Culture
    {
        return .init(partition: self.graph.partitions[index], 
            identifiers: self.graph.identifiers, 
            vertices: self.graph.vertices)
    }
}
