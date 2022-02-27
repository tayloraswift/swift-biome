extension Biome 
{
    public 
    struct Symbols:RandomAccessCollection, Sendable
    {
        public 
        typealias Index = Int
        public 
        typealias SubSequence = ArraySlice<Symbol>
        /* public 
         */
        
        private 
        var symbols:[Symbol]
        private 
        let lookup:[Symbol.ID: Int]
        
        public 
        var startIndex:Int
        {
            self.symbols.startIndex
        }
        public 
        var endIndex:Int
        {
            self.symbols.endIndex
        }
        /* public 
        var indices:Range<Index> 
        {
            self.startIndex ..< self.endIndex
        } */
        
        subscript(id:Symbol.ID) -> Symbol? 
        {
            guard let index:Int = self.lookup[id]
            else 
            {
                return nil 
            }
            return self.symbols[index]
        }
        public 
        subscript(indices:Range<Index>) -> ArraySlice<Symbol> 
        {
            self.symbols[indices]
        }
        public 
        subscript(index:Int) -> Symbol 
        {
            _read 
            {
                yield self.symbols[index]
            }
            _modify
            {
                yield &self.symbols[index]
            }
        }
        /* public 
        subscript(range:Range<Index>) -> ArraySlice<Module> 
        {
            _read 
            {
                yield self.modules[range.lowerBound.value ..< range.upperBound.value]
            }
            _modify
            {
                yield &self.modules[range.lowerBound.value ..< range.upperBound.value]
            }
        } */
        
        init(indices:[Symbol.ID: Int], symbols:[Symbol])
        {
            self.lookup = indices 
            self.symbols = symbols 
        }
        /* 
        func index(of id:Symbol.ID) throws -> Int
        {
            guard let index:Int = self.lookup[id]
            else 
            {
                throw SymbolIdentifierError.undefined(symbol: id)
            }
            return index
        } */
    }
}
