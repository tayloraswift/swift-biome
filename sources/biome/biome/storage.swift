extension Biome 
{
    public 
    struct Storage<Element>:RandomAccessCollection, Sendable 
        where Element:Identifiable & Sendable, Element.ID:Sendable
    {
        public 
        typealias Index = Int
        public 
        typealias SubSequence = ArraySlice<Element>
        
        private 
        var elements:[Element]
        private 
        let lookup:[Element.ID: Int]
        
        public 
        var startIndex:Int 
        {
            self.elements.startIndex
        }
        public 
        var endIndex:Int 
        {
            self.elements.endIndex
        }
        
        subscript(id:Element.ID) -> Element? 
        {
            guard let index:Int = self.lookup[id]
            else 
            {
                return nil 
            }
            return self.elements[index]
        }
        public 
        subscript(index:Int) -> Element 
        {
            _read 
            {
                yield self.elements[index]
            }
            _modify
            {
                yield &self.elements[index]
            }
        }
        public 
        subscript(indices:Range<Int>) -> ArraySlice<Element> 
        {
            self.elements[indices]
        }
        
        init(indices:[Element.ID: Int], elements:[Element])
        {
            self.lookup = indices 
            self.elements = elements 
        }
        
        func index(of id:Element.ID) -> Int?
        {
            guard let index:Int = self.lookup[id]
            else 
            {
                return nil 
            }
            return index
        }
    }
}
