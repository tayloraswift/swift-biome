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

        @inlinable public 
        func find(by less:(Value) throws -> Bool?) rethrows -> Index?
        {
            if case (let index, nil)? = try self.walk(by: less)
            {
                return index 
            }
            else 
            {
                return nil
            }
        }
        @inlinable public 
        func walk(by less:(Value) throws -> Bool?) rethrows -> (index:Index, side:Node.Side?)?
        {
            guard var current:Index = self.head?.index
            else 
            {
                return nil
            }

            switch try less(self.forest[current].value)
            {
            case false?:
                // head can never have a left-child. we return `nil` and not `(current, .left)`
                // to reflect the fact that any such insertion would also change ``head``.
                return nil 
            case nil: 
                return (current, nil) 
            case true?: 
                break 
            }
            ascending:
            while let parent:Index = self.forest.parent(of: current)
            {
                switch try less(self.forest[parent].value) 
                {
                case false?: 
                    break ascending 
                case nil: 
                    return (parent, nil) 
                case true?:
                    current = parent 
                }
            }
            guard var current:Index = self.forest.right(of: current)
            else 
            {
                return (current, .right)
            }
            // descend 
            while true
            {
                switch try less(self.forest[current].value)
                {
                case true?:
                    if let next:Index = self.forest.right(of: current)
                    {
                        current = next
                    }
                    else
                    {
                        return (current, .right)
                    }
                
                case nil: 
                    return (current, nil) 
                
                case false?:
                    if let next:Index = self.forest.left(of: current)
                    {
                        current = next
                    }
                    else
                    {
                        return (current, .left)
                    }
                }
            }
        }
    }
}
extension Forest.Tree where Value:Comparable 
{
    @inlinable public 
    func find(_ value:Value) -> Forest<Value>.Index?
    {
        self.find { $0 < value ? true : $0 == value ? nil : false }
    }
}
extension Forest.Tree:CustomStringConvertible 
{
    public 
    var description:String
    {
       self.head.map 
       {
            self.forest.description(head: $0, 
                root: self.forest.root(of: $0.index))
       } ?? "nil"
    }
}