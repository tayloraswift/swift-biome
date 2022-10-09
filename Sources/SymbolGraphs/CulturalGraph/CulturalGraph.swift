import SymbolSource

struct CulturalGraph
{
    let id:ModuleIdentifier 
    let dependencies:[PackageDependency]
    let markdown:[MarkdownFile]
    let colonies:[ColonialGraph]

    init(_ raw:RawCulturalGraph) throws
    {
        self.id = raw.id
        self.dependencies = raw.dependencies
        self.markdown = raw.markdown
        self.colonies = try raw.colonies.map 
        {
            try .init(utf8: $0.utf8, culture: $0.culture, namespace: $0.namespace)
        }
        .sorted 
        { 
            $0.namespace < $1.namespace 
        }
    }
}
