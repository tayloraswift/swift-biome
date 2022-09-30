import JSON
import Notebook
import SymbolSource

extension SymbolGraph.Vertex:Sendable where Target:Sendable {}
extension SymbolGraph.Vertex:Equatable where Target:Equatable {}

extension SymbolGraph.Vertex.Comment:Sendable where Target:Sendable {}
extension SymbolGraph.Vertex.Comment:Equatable where Target:Equatable {}

extension SymbolGraph 
{
    @frozen public
    struct Vertex<Target>
    {
        @frozen public 
        struct Comment
        {
            public 
            var string:String?
            public 
            var extends:Target?

            @inlinable public 
            init(string:String?, extends:Target?)
            {
                self.string = string 
                self.extends = extends
            }
            @inlinable public 
            init(_ string:String? = nil, extends:Target? = nil)
            {
                self.init(string: string.flatMap { $0.isEmpty ? nil : $0 }, extends: extends)
            }
            @inlinable public 
            func forEach(_ body:(Target) throws -> ()) rethrows 
            {
                try self.extends.map(body)
            }
            @inlinable public 
            func map<T>(_ transform:(Target) throws -> T) rethrows -> Vertex<T>.Comment
            {
                .init(string: self.string, extends: try self.extends.map(transform))
            }
        }

        public 
        var path:Path
        public 
        var shape:Shape 
        public 
        var declaration:Declaration<Target>
        public 
        var comment:Comment

        @inlinable public 
        init(path:Path,
            shape:Shape, 
            declaration:Declaration<Target>, 
            comment:Comment = .init())
        {
            self.path = path
            self.shape = shape
            self.declaration = declaration
            self.comment = comment
        }

        func forEach(_ body:(Target) throws -> ()) rethrows 
        {
            try self.declaration.forEach(body)
            try self.comment.forEach(body)
        }
        @inlinable public 
        func map<T>(_ transform:(Target) throws -> T) rethrows -> Vertex<T>
        {
            .init(path: self.path, shape: self.shape, 
                declaration: try self.declaration.map(transform), 
                comment: try self.comment.map(transform))
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
        return .init(path: .init(last: name), shape: .protocol, 
            declaration: .init(
                fragments: .init(fragments), 
                signature: .init(fragments)))
    }
}
