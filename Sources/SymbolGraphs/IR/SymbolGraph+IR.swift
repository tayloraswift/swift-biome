import JSON 

enum IR 
{
    static let culture:String = "culture"
    static let dependencies:String = "dependencies"
    static let extensions:String = "extensions"
    static let partitions:String = "partitions"
    static let identifiers:String = "identifiers"
    static let vertices:String = "vertices"
    static let edges:String = "edges"
    static let hints:String = "hints"
    static let sourcemap:String = "sourcemap"

    enum Communities 
    {
        static let community:String = "community"
        static let startIndex:String = "startIndex"
        static let endIndex:String = "endIndex"
    }
    enum Dependency 
    {
        static let package:String = "package"
        static let modules:String = "modules"
    }
    enum Extension 
    {
        static let name:String = "name"
        static let source:String = "source"
    }
    enum Partition 
    {
        static let namespace:String = "namespace"
        static let communities:String = "communities"
    }
    enum SourceFeature 
    {
        static let uri:String = "uri"
        static let symbols:String = "symbols"
    }
}

extension SymbolGraph 
{
    @inlinable public 
    init<UTF8>(utf8:UTF8) throws where UTF8:Collection<UInt8> 
    {
        try self.init(from: try Grammar.parse(utf8, as: JSON.Rule<UTF8.Index>.Root.self))
    }
    public 
    init(from json:JSON) throws 
    {
        self = try json.lint 
        {
            let partitions:[(namespace:ModuleIdentifier, communities:[(Community, Range<Int>)])] = 
                try $0.remove(IR.partitions, as: [JSON].self)
            {
                try $0.map 
                {
                    try $0.lint 
                    {
                        (
                            try $0.remove(IR.Partition.namespace, as: String.self, 
                                ModuleIdentifier.init(_:)),
                            try $0.remove(IR.Partition.communities, as: [JSON].self)
                            {
                                try $0.map 
                                {
                                    try $0.lint 
                                    {
                                        (
                                            try $0.remove(IR.Communities.community, as: String.self)
                                            {
                                                if let community:Community = .init($0)
                                                {
                                                    return community
                                                }
                                                else 
                                                {
                                                    throw JSON.PrimitiveError.matching(
                                                        variant: .string($0), 
                                                        as: Community.self)
                                                }
                                            }, 
                                            try $0.remove(IR.Communities.startIndex, as: Int.self) 
                                                ..<
                                                $0.remove(IR.Communities.endIndex,   as: Int.self)
                                        )
                                    }
                                }
                            }
                        )
                    }
                }
            }
            return .init(id: try $0.remove(IR.culture, as: String.self, ModuleIdentifier.init(_:)), 
                dependencies: try $0.remove(IR.dependencies, as: [JSON].self)
                {
                    try $0.map(Dependency.init(from:))
                }, 
                extensions: try $0.remove(IR.extensions, as: [JSON].self)
                {
                    try $0.map
                    {
                        try $0.lint 
                        {
                            (
                                name:   try $0.remove(IR.Extension.name,   as: String.self),
                                source: try $0.remove(IR.Extension.source, as: String.self)
                            )
                        }
                    }
                }, 
                partitions: partitions.compactMap 
                {
                    if  let start:Int = $0.communities.first?.1.lowerBound,
                        let end:Int = $0.communities.last?.1.upperBound
                    {
                        return ($0.namespace, start ..< end)
                    }
                    else 
                    {
                        return nil 
                    }
                }, 
                identifiers: try $0.remove(IR.identifiers, as: [JSON].self)
                {
                    try $0.map(SymbolIdentifier.init(from:))
                },
                vertices: try $0.remove(IR.vertices) 
                {
                    try .init(from: $0, communities: partitions.lazy.map(\.communities).joined())
                },
                edges: try $0.remove(IR.edges, [Edge<Int>].init(from:)), 
                hints: try $0.remove(IR.hints)
                {
                    let points:[JSON] = try $0.as([JSON].self) { $0 % 2 == 0 }
                    var hints:[Hint<Int>] = []
                        hints.reserveCapacity(points.count / 2)
                    for start:Int in stride(from: points.startIndex, to: points.endIndex, by: 2)
                    {
                        hints.append(.init(
                            source: try points.load(start), 
                            origin: try points.load(start + 1)))
                    }
                    return hints
                }, 
                sourcemap: try $0.remove(IR.sourcemap, as: [JSON].self)
                {
                    try $0.map 
                    {
                        try $0.lint 
                        {
                            (
                                try $0.remove(IR.SourceFeature.uri, as: String.self),
                                try $0.remove(IR.SourceFeature.symbols)
                                {
                                    let flattened:[JSON] = try $0.as([JSON].self) { $0 % 3 == 0 }
                                    var sourcemap:[SourceFeature<Int>] = []
                                        sourcemap.reserveCapacity(flattened.count / 3)
                                    for start:Int in stride(
                                        from: flattened.startIndex, 
                                        to: flattened.endIndex, 
                                        by: 3)
                                    {
                                        sourcemap.append(.init(line: try flattened.load(start), 
                                            character: try flattened.load(start + 1),
                                            symbol: try flattened.load(start + 2)))
                                    }
                                    return sourcemap
                                }
                            )
                        }
                    }
                })
        }
    }
    public 
    var serialized:JSON 
    {
        [
            IR.culture: .string(self.id.string),
            IR.dependencies: .array(self.dependencies.map(\.serialized)),
            IR.extensions: .array(self.extensions.map 
            {
                [ 
                    IR.Extension.name: .string($0.name), 
                    IR.Extension.source: .string($0.source) 
                ]
            }), 
            IR.partitions: .array(self.partitions.map 
            {
                [
                    IR.Partition.namespace: .string($0.namespace.string),
                    IR.Partition.communities: .array(self.vertices[$0.indices].communities),
                ]
            }),
            IR.identifiers: .array(self.identifiers.map { .string($0.string) }),
            IR.vertices: .array(self.vertices.map(\.serialized)),
            IR.edges: .object(self.edges.serialized),
            IR.hints: .array(self.hints.flatMap { [.number($0.source), .number($0.origin)] }),
            IR.sourcemap: .array(self.sourcemap.map 
            { 
                [
                    IR.SourceFeature.uri: .string($0.uri),
                    IR.SourceFeature.symbols: .array($0.symbols.flatMap 
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
    public 
    init(from json:JSON) throws 
    {
        (self.package, self.modules) = try json.lint 
        {
            (
                try $0.remove(IR.Dependency.package, as: String.self, PackageIdentifier.init(_:)),
                try $0.remove(IR.Dependency.modules, as: [JSON].self) 
                {
                    try $0.map { ModuleIdentifier.init(try $0.as(String.self)) }
                }
            )
        }
    }
    var serialized:JSON 
    {
        [
            IR.Dependency.package: .string(self.package.string),
            IR.Dependency.modules: .array(self.modules.map { .string($0.string) }),
        ]
    }
}

extension RangeReplaceableCollection<SymbolGraph.Vertex<Int>> 
{
    init(from json:JSON, communities:some Sequence<(Community, Range<Int>)>) throws 
    {
        let vertices:[JSON] = try json.as([JSON].self)
        self.init()
        self.reserveCapacity(vertices.count)
        for (community, range):(Community, Range<Int>) in communities 
        {
            for index:Int in range 
            {
                self.append(try vertices.load(index) 
                { 
                    try SymbolGraph.Vertex<Int>.init(from: $0, community: community) 
                })
            }
        }
    }
}
extension Collection<SymbolGraph.Vertex<Int>> where Index == Int 
{
    var communities:[JSON]
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
        return communities.map 
        { 
            [
                IR.Communities.community: .string($0.community.description), 
                IR.Communities.startIndex: .number($0.range.lowerBound),
                IR.Communities.endIndex: .number($0.range.upperBound),
            ] 
        }
    }
}

extension RangeReplaceableCollection<SymbolGraph.Edge<Int>> 
{
    init(from json:JSON) throws 
    {
        self.init()
        try json.lint 
        {
            try $0.pop("conformer") 
            {
                let points:[JSON] = try $0.as([JSON].self) { $0 % 3 == 0 }
                for start:Int in stride(from: points.startIndex, to: points.endIndex, by: 3)
                {
                    self.append(.init(try points.load(start), 
                        is: .conformer(try points.load(start + 2, as: [JSON].self) 
                        {
                            try $0.map(Generic.Constraint<Int>.init(from:))
                        }), 
                        of: try points.load(start + 1)))
                }
            }
            for (key, relation):(String, SymbolGraph.Edge<Int>.Relation) in 
            [
                ("feature", .feature), 
                ("member", .member), 
                ("subclass", .subclass), 
                ("override", .override), 
                ("requirement", .requirement), 
                ("optionalRequirement", .optionalRequirement), 
                ("defaultImplementation", .defaultImplementation), 
            ] 
            {
                try $0.pop(key) 
                {
                    let points:[JSON] = try $0.as([JSON].self) { $0 % 2 == 0 }
                    for start:Int in stride(from: points.startIndex, to: points.endIndex, by: 2)
                    {
                        self.append(.init(try points.load(start), is: relation, 
                            of: try points.load(start + 1)))
                    }
                }
            }
        }
    }
}
extension Sequence<SymbolGraph.Edge<Int>> 
{
    var serialized:[(key:String, value:JSON)]
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
        return items
    }
}
