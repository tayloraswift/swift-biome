extension SymbolGraph.SourceFeature:Sendable where Target:Sendable {}
extension SymbolGraph.SourceFeature:Hashable where Target:Hashable {}
extension SymbolGraph.SourceFeature:Equatable where Target:Equatable {}
extension SymbolGraph.SourceFeature:Comparable where Target:Comparable 
{
    @inlinable public static 
    func < (lhs:Self, rhs:Self) -> Bool 
    {
        (lhs.line, lhs.character, lhs.symbol) < (rhs.line, rhs.character, rhs.symbol)
    }
}

extension SymbolGraph 
{
    @frozen public 
    struct SourceFeature<Target>
    {
        public 
        let line:Int, 
            character:Int, 
            symbol:Target 

        func forEach(_ body:(Target) throws -> ()) rethrows 
        {
            try body(self.symbol)
        }
        func map<T>(_ transform:(Target) throws -> T) rethrows -> SourceFeature<T>
        {
            .init(line: self.line,
                character: self.character, 
                symbol: try transform(self.symbol))
        }
    }
}