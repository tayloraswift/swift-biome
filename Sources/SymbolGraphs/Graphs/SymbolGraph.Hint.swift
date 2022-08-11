extension SymbolGraph.Hint:Sendable where Target:Sendable {}
extension SymbolGraph.Hint:Hashable where Target:Hashable {}
extension SymbolGraph.Hint:Equatable where Target:Equatable {}

extension SymbolGraph 
{
    struct Hint<Target>
    {
        let source:Target 
        let origin:Target

        func forEach(_ body:(Target) throws -> ()) rethrows 
        {
            try body(self.source)
            try body(self.origin)
        }
        func map<T>(_ transform:(Target) throws -> T) rethrows -> Hint<T>
        {
            .init(source: try transform(self.source), 
                origin: try transform(self.origin))
        }
    }
}