import SymbolSource

extension SymbolGraph
{
    @frozen public
    struct Culture
    {
        public
        let id:ModuleIdentifier 
        public
        let dependencies:[PackageDependency], 
            markdown:[MarkdownFile],
            sources:[SwiftFile],
            edges:[Edge<Int>]
        public
        let startIndex:Int
        public
        let endIndex:Int

        @usableFromInline
        let partitions:[ColonialPartition]
        @usableFromInline
        let identifiers:[SymbolIdentifier],
            vertices:[Vertex<Int>]

        @inlinable public
        init(partition:CulturalPartition, 
            identifiers:[SymbolIdentifier],
            vertices:[Vertex<Int>])
        {
            self.id = partition.id
            self.dependencies = partition.dependencies
            self.markdown = partition.markdown
            self.sources = partition.sources
            self.edges = partition.edges
            self.partitions = partition.colonies

            self.startIndex = partition.vertices.lowerBound
            self.endIndex = partition.vertices.upperBound

            self.identifiers = identifiers
            self.vertices = vertices
        }
    }
}
extension SymbolGraph.Culture:RandomAccessCollection
{
    @inlinable public
    subscript(index:Int) -> (id:SymbolIdentifier, vertex:SymbolGraph.Vertex<Int>)
    {
        (self.identifiers[index], self.vertices[index])
    }
}
extension SymbolGraph.Culture
{
    @inlinable public
    var colonies:Colonies
    {
        .init(self)
    }
}

extension SymbolGraph.Culture
{
    @frozen public
    struct Colonies
    {
        @usableFromInline
        let culture:SymbolGraph.Culture

        @inlinable public
        init(_ culture:SymbolGraph.Culture)
        {
            self.culture = culture
        }
    }
}
extension SymbolGraph.Culture.Colonies:RandomAccessCollection
{
    @inlinable public
    var startIndex:Int
    {
        self.culture.partitions.startIndex
    }
    @inlinable public
    var endIndex:Int
    {
        self.culture.partitions.endIndex
    }
    @inlinable public
    subscript(index:Int) -> SymbolGraph.Colony
    {
        return .init(partition: self.culture.partitions[index], 
            identifiers: self.culture.identifiers, 
            vertices: self.culture.vertices,
            culture: self.culture.id)
    }
}