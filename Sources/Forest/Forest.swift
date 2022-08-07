extension Forest:Sendable where Value:Sendable {}
extension Forest.Node:Sendable where Value:Sendable {}
extension Forest.Node.State:Sendable where Value:Sendable {}

@frozen public 
struct Forest<Value>:RandomAccessCollection, CustomStringConvertible
{
    @frozen public 
    struct Index:Hashable, Strideable, CustomStringConvertible, Sendable 
    {
        public 
        let bits:UInt32 
        
        @inlinable public
        var offset:Int
        {
            .init(self.bits)
        }
        
        @inlinable public static 
        func < (lhs:Self, rhs:Self) -> Bool 
        {
            lhs.bits < rhs.bits 
        }
        @inlinable public
        func advanced(by stride:UInt32.Stride) -> Self 
        {
            .init(bits: self.bits.advanced(by: stride))
        }
        @inlinable public
        func distance(to other:Self) -> UInt32.Stride
        {
            self.bits.distance(to: other.bits)
        }
        
        @inlinable public
        init(offset:Int)
        {
            self.init(bits: .init(offset))
        }
        @inlinable public
        init(bits:UInt32)
        {
            self.bits = bits
        }

        public 
        var description:String 
        {
            self.bits.description
        }
    }

    @frozen public 
    struct Node:CustomStringConvertible 
    {
        @frozen public 
        enum State
        {
            case red(Value)
            case black(Value)
        }
        @frozen public 
        enum Color:Sendable
        {
            case red
            case black
        }
        @frozen public 
        enum Side:Sendable
        {
            case left
            case right 

            @inlinable public 
            var other:Self 
            {
                switch self 
                {
                case .left: return .right
                case .right: return .left
                }
            }
            @inlinable public 
            var left:Bool 
            {
                switch self 
                {
                case .left:     return true
                case .right:    return false
                }
            }
            @inlinable public 
            var right:Bool 
            {
                switch self 
                {
                case .left:     return false
                case .right:    return true
                }
            }
        }

        public 
        var left:Index 
        public 
        var right:Index 
        public 
        var parent:Index
        public 
        var state:State?

        @inlinable public 
        init(_ state:State, at index:Index, parent:Index? = nil)
        {
            self.left = index 
            self.right = index 
            self.parent = parent ?? index 
            self.state = state 
        }

        @inlinable public 
        subscript(child:Side) -> Index 
        {
            _read 
            {
                switch child 
                {
                case .left:     yield  self.left 
                case .right:    yield  self.right 
                }
            }
            _modify 
            {
                switch child 
                {
                case .left:     yield &self.left 
                case .right:    yield &self.right 
                }
            }
        }
        @inlinable public 
        var color:Color 
        {
            get 
            {
                switch self.state
                {
                case nil: 
                    fatalError("read from uninitialized node")
                case .red?:
                    return .red
                case .black?:
                    return .black
                }
            }
            set(color)
            {
                switch color
                {
                case .red:
                    self.state = .red(self.value)
                case .black:
                    self.state = .black(self.value)
                }
            }
        }
        @inlinable public 
        var value:Value 
        {
            _read 
            {
                switch self.state
                {
                case nil: 
                    fatalError("read from uninitialized node")
                case .red(let value)?:
                    yield value 
                case .black(let value)?:
                    yield value
                }
            }
            _modify 
            {
                switch self.state
                {
                case nil: 
                    fatalError("read from uninitialized node")
                case .red(var value)?:
                    self.state = nil
                    yield &value 
                    self.state = .red(value)
                case .black(var value)?:
                    self.state = nil
                    yield &value
                    self.state = .black(value)
                }
            }
        }

        public 
        var description:String 
        {
            switch self.state 
            {
            case nil: 
                return "nil"
            case .red(let value):
                return "[\(self.parent)][\(self.left), \(self.right)] red(\(value))"
            case .black(let value):
                return "[\(self.parent)][\(self.left), \(self.right)] black(\(value))"
            }
        }
    }

    public 
    var nodes:[Node]

    public 
    var description:String 
    {
        self.description()
    }
    func description(head:Tree.Head? = nil, root:Index? = nil) -> String 
    {
        self.nodes.isEmpty ? "[]" :
        """
        [
        \(zip(self.indices, self.nodes).lazy.map 
        {
            (element:(index:Index, node:Node)) -> String in 

            let value:String 
            switch element.index
            {
            case head?.index:
                value = "\(element.node) <- head"
            case root:
                value = "\(element.node) <- root"
            case _: 
                value = "\(element.node)"
            }
            return 
                """
                    [\(element.index)]: \(value)
                """
        }.joined(separator: "\n"))
        ]
        """
    }

    @inlinable public 
    init() 
    {
        self.nodes = []
    }

    public 
    func _inhabitants() -> Int 
    {
        self.nodes.reduce(0) 
        {
            if case nil = $1.state 
            {
                return $0
            }
            else 
            {
                return $0 + 1
            }
        }
    }

    @inlinable public 
    var startIndex:Index 
    {
        .init(offset: self.nodes.startIndex)
    }
    @inlinable public 
    var endIndex:Index 
    {
        .init(offset: self.nodes.endIndex)
    }
    @inlinable public 
    subscript(index:Index) -> Node 
    {
        _read 
        {
            yield  self.nodes[index.offset]
        }
        _modify 
        {
            yield &self.nodes[index.offset]
        }
    }
    // “smart” subscripts, that update both ends of a link
    @inlinable public 
    subscript(side:Node.Side, of parent:Index) -> Index
    {
        _read 
        {
            yield self[parent][side]
        }
        set(child)
        {
            self[child].parent = parent 
            self[parent][side] = child
        }
    }
    @inlinable public 
    subscript(side:Node.Side, of parent:Index) -> Index?
    {
        _read 
        {
            yield self[side, of: parent] as Index 
        }
        set(child)
        {
            if let child:Index 
            {
                self[side, of: parent] = child 
            }
            else 
            {
                self[parent][side] = parent 
            }
        }
    }
    @inlinable public 
    subscript(position:(side:Node.Side, of:Index)) -> Index
    {
        _read 
        {
            yield  self[position.side, of: position.of]
        }
        _modify
        {
            yield &self[position.side, of: position.of]
        }
    }
    @inlinable public 
    subscript(position:(side:Node.Side, of:Index)) -> Index?
    {
        _read 
        {
            yield  self[position.side, of: position.of]
        }
        _modify
        {
            yield &self[position.side, of: position.of]
        }
    }
    @inlinable public 
    subscript(position:(side:Node.Side, of:Index)?) -> Index?
    {
        get 
        {
            position.map { self[ $0] }
        }
        set(child)
        {
            if case (let side, of: let parent)? = position 
            {
                self[side, of: parent] = child ?? parent
            }
            else if let child:Index 
            {
                self[child].parent = child 
            }
        }
    }

    @inlinable public 
    func left(of index:Index) -> Index?
    {
        switch self[index].left 
        {
        case index:         return nil 
        case let left:      return left 
        }
    }
    @inlinable public 
    func right(of index:Index) -> Index?
    {
        switch self[index].right 
        {
        case index:         return nil 
        case let right:     return right 
        }
    }
    @inlinable public 
    func parent(of index:Index) -> Index?
    {
        switch self[index].parent 
        {
        case index:         return nil 
        case let parent:    return parent 
        }
    }

    @inlinable public 
    func successor(of head:Tree.Head) -> Tree.Head?
    {
        if let child:Index = self.right(of: head.index)
        {
            return .init(self.leftmost(from: child))
        }
        else 
        { 
            return self.parent(of: head.index).map(Tree.Head.init(_:))
        }
    }
    /// Returns the inorder successor of the node at the given index, in amortized O(1) time.
    @inlinable public 
    func successor(of index:Index) -> Index?
    {
        if let child:Index = self.right(of: index)
        {
            return self.leftmost(from: child)
        }

        var current:Index = index
        while   let parent:Index = self.parent(of: current), 
                    current == self[parent].right
        {
            current = parent
        }
        return self.parent(of: current)
    }

    /// Returns the inorder predecessor of the node at the given index, in amortized O(1) time.
    @inlinable public 
    func predecessor(of index:Index) -> Index?
    {
        if let child:Index = self.left(of: index)
        {
            return self.rightmost(from: child)
        }

        var current:Index = index
        while   let parent:Index = self.parent(of: current),
                    current == self[parent].left
        {
            current = parent
        }
        return self.parent(of: current)
    }

    @inlinable public 
    func leftmost(of index:Index) -> (left:Index, parent:Index)?
    {
        guard var current:Index = self.left(of: index)
        else 
        {
            return nil 
        }
        var previous:Index = index 
        while let next:Index = self.left(of: current)
        {
            previous = current  
            current = next 
        }
        return (left: current, parent: previous)
    }
    @inlinable public 
    func rightmost(of index:Index) -> (parent:Index, right:Index)?
    {
        guard var current:Index = self.right(of: index)
        else 
        {
            return nil 
        }
        var previous:Index = index 
        while let next:Index = self.right(of: current)
        {
            previous = current  
            current = next 
        }
        return (parent: previous, right: current)
    }

    @inlinable public 
    func leftmost(from index:Index) -> Index
    {
        var current:Index = index
        while let next:Index = self.left(of: current)
        {
            current = next 
        }
        return current
    }
    @inlinable public 
    func rightmost(from index:Index) -> Index
    {
        var current:Index = index
        while let next:Index = self.right(of: current)
        {
            current = next 
        }
        return current
    }
    @inlinable public 
    func root(of index:Index) -> Index
    {
        var current:Index = index
        while let next:Index = self.parent(of: current)
        {
            current = next 
        }
        return current
    }
}
extension Forest 
{
    @discardableResult
    @inlinable public mutating 
    func rotateLeft(_ pivot:Index) -> Index
    {
        guard let parent:Index = self.parent(of: pivot)
        else 
        {
            return self.rotateLeft(pivot, on: nil)
        }
        if pivot == self[parent].left
        {
            return self.rotateLeft(pivot, on: (.left, of: parent))
        }
        else
        {
            return self.rotateLeft(pivot, on: (.right, of: parent))
        }
    }
    @discardableResult
    @inlinable public mutating 
    func rotateRight(_ pivot:Index) -> Index
    {
        guard let parent:Index = self.parent(of: pivot)
        else 
        {
            return self.rotateRight(pivot, on: nil)
        }
        if pivot == self[parent].left
        {
            return self.rotateRight(pivot, on: (.left, of: parent))
        }
        else
        {
            return self.rotateRight(pivot, on: (.right, of: parent))
        }
    }

    // performs a left rotation and returns the new vertex
    @discardableResult
    @inlinable public mutating 
    func rotateLeft(_ pivot:Index, on position:(side:Node.Side, of:Index)?) -> Index
    {
        let vertex:Index = self[pivot].right
        if let left:Index = self.left(of: vertex)
        {
            self[left].parent = pivot 
            self[pivot].right = left
        }
        else 
        {
            self[pivot].right = pivot
        }
        if case let (side, parent)? = position
        {
            self[vertex].parent = parent 
            self[parent][side] = vertex 
        }
        else 
        {
            self[vertex].parent = vertex
        }
        self[vertex].left = pivot
        self[pivot].parent = vertex
        return vertex
    }
    // performs a right rotation and returns the new vertex
    @discardableResult
    @inlinable public mutating 
    func rotateRight(_ pivot:Index, on position:(side:Node.Side, of:Index)?) -> Index
    {
        let vertex:Index = self[pivot].left
        if let right:Index = self.right(of: vertex) 
        {
            self[right].parent = pivot
            self[pivot].left = right
        }
        else 
        {
            self[pivot].left = pivot
        }
        if case let (side, parent)? = position
        {
            self[vertex].parent = parent 
            self[parent][side] = vertex 
        }
        else 
        {
            self[vertex].parent = vertex
        }
        self[vertex].right = pivot
        self[pivot].parent = vertex
        return vertex 
    }
}