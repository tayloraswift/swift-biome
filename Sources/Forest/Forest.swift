extension Forest:Sendable where Value:Sendable {}
extension Forest.Node:Sendable where Value:Sendable {}
extension Forest.Node.State:Sendable where Value:Sendable {}

@frozen public 
struct Forest<Value>:RandomAccessCollection
{
    @frozen public 
    struct Index:Hashable, Strideable, Sendable 
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
    }

    @frozen public 
    struct Node 
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
    }

    public 
    var nodes:[Node]

    @inlinable public 
    init() 
    {
        self.nodes = []
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

    /// Returns the inorder successor of the node at the given index, in amortized O(1) time.
    @inlinable public 
    func successor(of index:Index) -> Index?
    {
        if let child:Index = self.right(of: index)
        {
            return self.leftmost(of: child)
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
            return self.rightmost(of: child)
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
    func leftmost(of index:Index) -> Index
    {
        var current:Index = index
        while let next:Index = self.left(of: current)
        {
            current = next 
        }
        return current
    }
    @inlinable public 
    func rightmost(of index:Index) -> Index
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
    @inlinable public mutating 
    func rotateLeft(_ pivot:Index, under parent:Index)
    {
        if pivot == self[parent].left
        {
            self.rotateLeft(pivot, on: (.left, of: parent))
        }
        else
        {
            self.rotateLeft(pivot, on: (.right, of: parent))
        }
    }
    @inlinable public mutating 
    func rotateRight(_ pivot:Index, under parent:Index)
    {
        if pivot == self[parent].left
        {
            self.rotateRight(pivot, on: (.left, of: parent))
        }
        else
        {
            self.rotateRight(pivot, on: (.right, of: parent))
        }
    }

    // performs a left rotation and returns the new vertex
    @inlinable public mutating 
    func rotateLeft(_ pivot:Index, on position:(side:Node.Side, of:Index)? = nil) 
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
    }
    // performs a right rotation and returns the new vertex
    @inlinable public mutating 
    func rotateRight(_ pivot:Index, on position:(side:Node.Side, of:Index)? = nil) 
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
    }
}

/*
struct UnsafeBalancedTree<Element>:Sequence
{
    private static
    func remove(_ node:Node, root:inout Node?)
    {
        @inline(__always)
        func _replaceLink(to node:Node, with other:Node?, onParent parent:Node)
        {
            if node == parent.lchild
            {
                parent.lchild = other
            }
            else
            {
                parent.rchild = other
            }
        }

        if let       _:Node = node.lchild,
           let  rchild:Node = node.rchild
        {
            let replacement:Node = rchild.leftmost()

            // the replacement always lives below the node, so this shouldn’t
            // disturb any links we are modifying later
            if let parent:Node = node.parent
            {
                _replaceLink(to: node, with: replacement, onParent: parent)
            }
            else
            {
                root = replacement
            }

            // if we don’t do this check, we will accidentally double flip a link
            if node == replacement.parent
            {
                // turn the links around so they get flipped correctly in the next step
                replacement.parent = replacement
                if replacement == node.lchild
                {
                    node.lchild = node
                }
                else
                {
                    node.rchild = node
                }
            }
            else
            {
                // the replacement can never be the root, so it always has a parent
                _replaceLink(to: replacement, with: node, onParent: replacement.parent!)
            }

            // swap all container information, taking care of outgoing links
            swap(&replacement.parent, &node.parent)
            swap(&replacement.lchild, &node.lchild)
            swap(&replacement.rchild, &node.rchild)
            swap(&replacement.color , &node.color)

            // fix uplink consistency
            node.lchild?.parent        = node
            node.rchild?.parent        = node
            replacement.lchild?.parent = replacement
            replacement.rchild?.parent = replacement
        }

        if      node.color == .red
        {
            assert(node.lchild == nil && node.rchild == nil)
            // a red node cannot be the root, so it must have a parent
            _replaceLink(to: node, with: nil, onParent: node.parent!)
        }
        else if let child:Node = node.lchild ?? node.rchild,
                    child.color == .red
        {
            if let parent:Node = node.parent
            {
                _replaceLink(to: node, with: child, onParent: parent)
            }
            else
            {
                root = child
            }

            child.parent = node.parent
            child.color  = .black
        }
        else
        {
            assert(node.lchild == nil && node.rchild == nil)

            balanceDeletion(phantom: node, root: &root)
            // the root case is checked but not handled inside the
            // balanceDeletion(phantom:root:) function
            if let parent:Node = node.parent
            {
                _replaceLink(to: node, with: nil, onParent: parent)
            }
            else
            {
                root = nil
            }
        }

        node.deallocate()
    }

    private static
    func balanceDeletion(phantom node:Node, root:inout Node?)
    {
        // case 1: node is the root. do nothing. don’t nil out the root because
        // we may be here on a recursive call
        guard let parent:Node = node.parent
        else
        {
            return
        }
        // the node must have a sibling, since if it did not, the sibling subtree
        // would only contribute +1 black height compared to the node’s subtree’s
        // +2 black height.
        var sibling:Node = node == parent.lchild ? parent.rchild! : parent.lchild!

        // case 2: the node’s sibling is red. (the parent must be black.)
        //         make the parent red and the sibling black. rotate on the parent.
        //         fallthrough to cases 4–6.
        if sibling.color == .red
        {
            parent.color  = .red
            sibling.color = .black
            if node == parent.lchild
            {
                rotateLeft(parent, root: &root)
            }
            else
            {
                rotateRight(parent, root: &root)
            }

            // update the sibling. the sibling must have children because it is
            // red and has a black sibling (the node we are deleting).
            sibling = node == parent.lchild ? parent.rchild! : parent.lchild!
        }
        // case 3: the parent and sibling are both black. on the first iteration,
        //         the sibling has no children or else the black property would ,
        //         not have been held. however later, the sibling may have children
        //         which must both be black. repaint the sibling red, then fix the
        //         parent.
        else if parent.color == .black,
                sibling.lchild?.color ?? .black == .black,
                sibling.rchild?.color ?? .black == .black
        {
            sibling.color = .red

            // recursive call
            balanceDeletion(phantom: parent, root: &root)
            return
        }

        // from this point on, the sibling is assumed black because of case 2
        assert(sibling.color == .black)

        // case 4: the sibling is black, but the parent is red. repaint the sibling
        //         red and the parent black.
        if      parent.color  == .red,
                sibling.lchild?.color ?? .black == .black,
                sibling.rchild?.color ?? .black == .black
        {
            sibling.color = .red
            parent.color  = .black
            return
        }
        // from this point on, the sibling is assumed to have at least one red child
        // because of cases 2–4
        // case 5: the sibling has one red inner child. (the parent’s color does
        //         not matter.) rotate on the sibling and switch its color and that
        //         of its child so that the new sibling has a red outer child.
        //         fallthrough to case 6.
        else if node == parent.lchild,
                sibling.rchild?.color ?? .black == .black
        {
            sibling.color                 = .red
            sibling.lchild!.color = .black

            // update the sibling
            sibling       = rotateRight(sibling)
            parent.rchild = sibling
        }
        else if node == parent.rchild,
                sibling.lchild?.color ?? .black == .black
        {
            sibling.color         = .red
            sibling.rchild!.color = .black

            // update the sibling
            sibling       = rotateLeft(sibling)
            parent.lchild = sibling
        }

        // case 6: the sibling has at least one red child on the outside. switch
        // the colors of the parent and the sibling, make the outer child black,
        // and rotate on the parent.
        sibling.color = parent.color
        parent.color  = .black
        if node == parent.lchild
        {
            sibling.rchild!.color = .black
            rotateLeft(parent, root: &root)
        }
        else
        {
            sibling.lchild!.color = .black
            rotateRight(parent, root: &root)
        }
    }

    // deinitializes and deallocates the node and all of its children
    private static
    func deallocateTree(_ node:Node?)
    {
        guard let node:Node = node
        else
        {
            return
        }
        deallocateTree(node.lchild)
        deallocateTree(node.rchild)
        node.deallocate()
    }
}
extension UnsafeBalancedTree where Element:Comparable
{
    // returns the inserted node


    func binarySearch(_ element:Element) -> Node?
    {
        var node:Node? = self.root
        while let current:Node = node
        {
            if element < current.element
            {
                node = current.lchild
            }
            else if element > current.element
            {
                node = current.rchild
            }
            else
            {
                return current
            }
        }

        return nil
    }
}
*/