import Notebook

extension SymbolGraph.Vertex:Sendable where Target:Sendable {}
extension SymbolGraph.Vertex:Equatable where Target:Equatable {}

extension SymbolGraph 
{
    @frozen public
    struct Vertex<Target>
    {
        public 
        var path:Path
        public 
        var community:Community 
        public 
        var declaration:Declaration<Target>
        public 
        var comment:String

        @inlinable public 
        init(path:Path,
            community:Community, 
            declaration:Declaration<Target>, 
            comment:String)
        {
            self.path = path
            self.community = community
            self.declaration = declaration
            self.comment = comment
        }

        func forEach(_ body:(Target) throws -> ()) rethrows 
        {
            try self.declaration.forEach(body)
        }
        @inlinable public 
        func map<T>(_ transform:(Target) throws -> T) rethrows -> Vertex<T>
        {
            .init(path: self.path, 
                community: self.community, 
                declaration: try self.declaration.map(transform), 
                comment: self.comment)
        }
    }
}
extension SymbolGraph.Vertex 
{
    static 
    func `protocol`(named name:String) -> Self 
    {
        let fragments:[Notebook<Highlight, Target>.Fragment] = 
        [
            .init("protocol",   color: .keywordText),
            .init(" ",          color: .text),
            .init(name,         color: .identifier),
        ]
        return .init(path: .init(last: name), 
            community: .protocol, 
            declaration: .init(
                fragments: .init(fragments), 
                signature: .init(fragments)), 
            comment: "")
    }
}