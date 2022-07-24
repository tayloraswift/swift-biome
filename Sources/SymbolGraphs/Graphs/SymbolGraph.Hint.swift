extension SymbolGraph.Hint:Sendable where Source:Sendable {}
extension SymbolGraph.Hint:Hashable where Source:Hashable {}
extension SymbolGraph.Hint:Equatable where Source:Equatable {}
extension SymbolGraph.Hint:Comparable where Source:Comparable 
{
    @inlinable public static 
    func < (lhs:Self, rhs:Self) -> Bool 
    {
        (lhs.source, lhs.origin) < (rhs.source, rhs.origin)
    }
}

extension SymbolGraph 
{
    @frozen public 
    struct Hint<Source>
    {
        public 
        let source:Source 
        public 
        let origin:Source

        func forEach(_ body:(Source) throws -> ()) rethrows 
        {
            try body(self.source)
            try body(self.origin)
        }
        func map<T>(_ transform:(Source) throws -> T) rethrows -> Hint<T>
        {
            .init(source: try transform(self.source), 
                origin: try transform(self.origin))
        }
    }
}