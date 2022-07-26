extension SymbolGraph.Hint:Sendable where Target:Sendable {}
extension SymbolGraph.Hint:Hashable where Target:Hashable {}
extension SymbolGraph.Hint:Equatable where Target:Equatable {}
extension SymbolGraph.Hint:Comparable where Target:Comparable 
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
    struct Hint<Target>
    {
        public 
        let source:Target 
        public 
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