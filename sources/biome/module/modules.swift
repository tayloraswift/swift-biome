extension Biome.Module 
{
    public 
    struct Index:Hashable, Comparable, Strideable, Sendable 
    {
        public 
        typealias Stride = Int 
        
        let value:Int 
        
        public static 
        func < (lhs:Self, rhs:Self) -> Bool 
        {
            lhs.value < rhs.value
        }
        
        init(_ value:Int)
        {
            self.value = value
        }
        
        public 
        func advanced(by distance:Int) -> Self 
        {
            .init(self.value + distance)
        }
        public 
        func distance(to index:Self) -> Int
        {
            index.value - self.value
        }
    }
}
extension Biome 
{
    public 
    struct Modules:RandomAccessCollection, Sendable
    {
        public 
        typealias Index = Int
        public 
        typealias SubSequence = ArraySlice<Module>
        
        private 
        var modules:[Module]
        private 
        let lookup:[Module.ID: Int]
        
        public 
        var startIndex:Int 
        {
            self.modules.startIndex
        }
        public 
        var endIndex:Int 
        {
            self.modules.endIndex
        }
        /* public 
        var indices:Range<Index> 
        {
            self.startIndex ..< self.endIndex
        } */
        
        public 
        subscript(index:Int) -> Module 
        {
            _read 
            {
                yield self.modules[index]
            }
            _modify
            {
                yield &self.modules[index]
            }
        }
        public 
        subscript(indices:Range<Index>) -> ArraySlice<Module> 
        {
            self.modules[indices]
        }
        
        init(indices:[Module.ID: Int], modules:[Module])
        {
            self.lookup = indices 
            self.modules = modules 
        }
        
        func index(of id:Module.ID) throws -> Int
        {
            guard let index:Int = self.lookup[id]
            else 
            {
                throw ModuleIdentifierError.undefined(module: id)
            }
            return index
        }
    }
}
