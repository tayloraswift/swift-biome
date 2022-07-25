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
    public private(set)
    var identifiers:[SymbolIdentifier], 
        vertices:[Vertex<Int>], 
        edges:[Edge<Int>],
        hints:[Hint<Int>]
    private(set)
    var partitions:[Partition]
    
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
            self.identifiers.append(contentsOf: subgraph.vertices.keys.sorted())
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
            $0.bounds < $1.bounds
        }
        self.hints = subgraphs.flatMap 
        {
            $0.hints.map { $0.map { indices[$0]! } }
        }
        .sorted()
    }
}