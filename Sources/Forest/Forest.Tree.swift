extension Forest 
{
    @inlinable public 
    subscript(tree:Tree.Head?) -> Tree 
    {
        .init(tree, forest: self)
    }

    @frozen public 
    struct Tree:Sequence
    {
        @frozen public 
        struct Head
        {
            public 
            var index:Index 

            @inlinable public 
            init(_ index:Index)
            {
                self.index = index 
            }
        }
        @frozen public 
        struct Iterator:IteratorProtocol 
        {
            public 
            var current:Index? 
            public 
            let forest:Forest<Value>

            @inlinable public 
            init(current:Index?, forest:Forest<Value>)
            {
                self.current = current 
                self.forest = forest 
            }
            @inlinable public mutating 
            func next() -> Value?
            {
                if let current:Index = self.current
                {
                    self.current = self.forest.successor(of: current) 
                    return self.forest[current].value
                }
                else 
                {
                    return nil 
                }
            }
        }

        public 
        let head:Head?
        public 
        let forest:Forest<Value>

        @inlinable public 
        func makeIterator() -> Iterator
        {
            .init(current: self.head?.index, forest: self.forest)
        }

        @inlinable public 
        init(_ head:Head?, forest:Forest<Value>)
        {
            self.head = head 
            self.forest = forest
        }
    }
}