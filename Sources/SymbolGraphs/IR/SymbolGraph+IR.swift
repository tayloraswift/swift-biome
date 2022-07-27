import JSON 

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
                "community": .string($0.community.description), 
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
