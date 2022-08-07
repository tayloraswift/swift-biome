extension Forest 
{
    @discardableResult
    @inlinable public mutating
    func remove(_ index:Index, from tree:inout Tree.Head?) -> Value
    {
        if let head:Tree.Head = tree, head.index == index 
        {
            tree = self.successor(of: head)
        }

        let value:Value = self[index].value 

        if let parent:Index = self.parent(of: index)
        {
            if index == self[parent].left
            {
                self.remove(index, on: (.left, of: parent))
            }
            else
            {
                self.remove(index, on: (.right, of: parent))
            }
        }
        else 
        {
            self.remove(index, on: nil)
        }
        return value 
    }

    @inlinable public mutating 
    func _replaceLink(to node:Index, with other:Index?, onParent parent:Index)
    {
        if node == self[parent].left
        {
            self[parent].left = other ?? parent
        }
        else
        {
            self[parent].right = other ?? parent
        }
    }

    @inlinable public mutating 
    func sink(_ node:Index, on position:(side:Node.Side, of:Index)?, 
        a:Index, b:Index, d:Index, e replacement:Index) -> Index?
    {
        //  there are up to 5 links that need to be updated, 
        //  which requires up to 11 memory writes. 
        //
        //  the additional write is because we must `nil`-out 
        //  the `node`’s left-child, since the replacement 
        //  will never have one.
        //
        //  note: (b) and (x) may be the same node. 
        //           ┆
        //         (node)
        //  ┌────────┴───────────────────────────┐
        // (a)                                  (b)
        //                              ┌────────┴───────┐
        //                             (d)
        //                      ┌───────┴───────┐
        //               (replacement)
        //                      └───┐
        //                         (c?)
        let _c:Index?
        if case .red = self[replacement].color 
        {
            assert(self.right(of: replacement) == nil)
            _c = nil 
        }
        else if let c:Index = self.right(of: replacement)
        {
            self[c].parent = node // 9
            self[node].right = c // 10
            assert(self[replacement].color == .black)
            assert(self[c].color == .red)
            _c = c 
        }
        else 
        {
            self[node].right = node
            _c = nil 
        }

        if case (let side, of: let parent)? = position 
        {
            self[parent][side] = replacement // 1
            self[replacement].parent = parent // 2
        }
        else 
        {
            self[replacement].parent = replacement
        }
        self[replacement].left = a // 3
        self[replacement].right = b // 4
        self[a].parent = replacement // 5
        self[b].parent = replacement // 6

        self[d].left = node // 7
        self[node].parent = d // 8
        self[node].left = node // 11

        return _c
    }
    @inlinable public mutating 
    func sink(_ node:Index, on position:(side:Node.Side, of:Index)?, 
        a:Index, b replacement:Index) -> Index?
    {
        //  there are up to 4 links that need to be updated, 
        //  which requires up to 9 memory writes. 
        //
        //  the additional write is because we must `nil`-out 
        //  the `node`’s left-child, since the replacement 
        //  will never have one.
        //
        //           ┆
        //         (node)
        //  ┌────────┴───────────────────────────┐
        // (a)                             (replacement)
        //                                       └───────┐
        //                                              (c?)
        let _c:Index?
        if case .red = self[replacement].color 
        {
            // if the destination is red, it will never have a child, 
            // because red nodes can only have 0 or 2 children.
            // we can always remove a red leaf node without needing to 
            // rebalance the tree, 
            assert(self.right(of: replacement) == nil)
            _c = nil 
        }
        else if let c:Index = self.right(of: replacement)
        {
            self[c].parent = node // 7
            self[node].right = c // 8
            assert(self[replacement].color == .black)
            assert(self[c].color == .red)
            _c = c
        }
        else 
        {
            self[node].right = node
            _c = nil 
        }

        self[replacement].left = a // 3
        self[replacement].right = node // 4
        self[node].parent = replacement // 5
        self[a].parent = replacement // 6
        self[node].left = node // 9

        if case (let side, of: let parent)? = position 
        {
            self[parent][side] = replacement // 1
            self[replacement].parent = parent // 2
        }
        else 
        {
            self[replacement].parent = replacement
        }

        return _c
    }
    @inlinable public mutating 
    func remove(_ node:Index, on position:(side:Node.Side, of:Index)?)
    {
        let left:Index?, 
            right:Index?, 
            color:Node.Color 
        switch (self.left(of: node), self.right(of: node))
        {
        case (let a?, let b?):
            let replacement:Index
            if case (left: let e, parent: let d)? = self.leftmost(of: b)
            {
                right = self.sink(node, on: position, a: a, b: b, d: d, e: e)
                replacement = e
            }
            else 
            {
                right = self.sink(node, on: position, a: a, b: b)
                replacement = b
            }
            // replacement never has a left child
            left = nil 
            color = self[replacement].color
            self[replacement].color = self[node].color
            self[node].color = color 

            if case .red = color 
            {
                assert(left  == nil)
                assert(right == nil)
                // a red node cannot be the root, so it must have a parent
                self._replaceLink(to: node, with: nil, onParent: self[node].parent)
            }
            else if let child:Index = right
            {
                // an only-child must be red 
                assert(.red == self[child].color)
                
                if let parent:Index = self.parent(of: node)
                {
                    self._replaceLink(to: node, with: child, onParent: parent)
                    self[child].parent = parent
                }
                else
                {
                    fatalError("unreachable")
                }

                self[child].color = .black
            }
            else
            {
                // the root case is checked but not handled inside the
                // balanceDeletion(phantom:root:) function
                if let parent:Index = self.parent(of: node)
                {
                    self.balance(removal: node, on: self[parent].left == node ? .left : .right, of: parent)
                    self._replaceLink(to: node, with: nil, onParent: parent)
                }
                else 
                {
                    fatalError("unreachable")
                }
            }
        
        case (let child?, nil), (nil, let child?):
            // an only-child must be red, and a red node cannot have a red parent. 
            assert(self[node].color == .black)
            assert(self[child].color == .red)
            if case (let side, of: let parent)? = position
            {
                self[parent][side] = child
                self[child].parent = parent
            }
            else
            {
                self[child].parent = child
            }
            self[child].color = .black
        
        case (nil, nil):
            switch (self[node].color, on: position)
            {
            case (.red, on: nil): 
                // a red node cannot be the root, so it must have a parent
                fatalError("unreachable")
            
            case (.red, on: (let side, of: let parent)?):
                // we can always delete a childless red node.
                self[parent][side] = parent 
            
            case (.black, on: (let side, of: let parent)?):
                self.balance(removal: node, on: side, of: parent)
                self[parent][side] = parent 
            
            case (.black, on: nil): 
                // we can always delete the root. 
                break 
            }
        }

        self[node].state = nil
    }
    @inlinable public mutating 
    func balance(removal node:Index, on side:Node.Side, of parent:Index)
    {
        // the node must have a sibling, since if it did not, the sibling subtree
        // would only contribute +1 black height compared to the node’s subtree’s
        // +2 black height.
        assert(self[parent].left  != parent)
        assert(self[parent].right != parent)

        var sibling:Index = self[parent][side.other]

        // case 2: the node’s sibling is red. (the parent must be black.)
        //         make the parent red and the sibling black. rotate on the parent.
        //         fallthrough to cases 4–6.
        if case .red = self[sibling].color
        {
            self[parent].color = .red
            self[sibling].color = .black
            if node == self[parent].left
            {
                self.rotateLeft(parent)
            }
            else
            {
                self.rotateRight(parent)
            }

            // update the sibling. the sibling must have children because it is
            // red and has a black sibling (the node we are deleting).
            sibling = node == self[parent].left ? self[parent].right : self[parent].left
        }
        // case 3: the parent and sibling are both black. on the first iteration,
        //         the sibling has no children or else the black property would ,
        //         not have been held. however later, the sibling may have children
        //         which must both be black. repaint the sibling red, then fix the
        //         parent.
        else if case .black = self[parent].color,
                self.left(of: sibling).map({ self[$0].color == .black }) ?? true,
                self.right(of: sibling).map({ self[$0].color == .black }) ?? true
        {
            self[sibling].color = .red

            // recursive call
            if let grandparent:Index = self.parent(of: parent)
            {
                self.balance(removal: parent, on: self[grandparent].left == parent ? .left : .right, of: grandparent)
            }
            return
        }

        // from this point on, the sibling is assumed black because of case 2
        assert(self[sibling].color == .black)

        // case 4: the sibling is black, but the parent is red. repaint the sibling
        //         red and the parent black.
        if case .red = self[parent].color,
                self.left(of: sibling).map({ self[$0].color == .black }) ?? true,
                self.right(of: sibling).map({ self[$0].color == .black }) ?? true
        {
            self[sibling].color = .red
            self[parent].color = .black
            return
        }
        // from this point on, the sibling is assumed to have at least one red child
        // because of cases 2–4.
        // case 5: the sibling has one red inner child. (the parent’s color does
        //         not matter.) rotate on the sibling and switch its color and that
        //         of its child so that the new sibling has a red outer child.
        //         fallthrough to case 6.
        else if node == self[parent].left,
                self.right(of: sibling).map({ self[$0].color == .black }) ?? true
        {
            self[sibling].color = .red
            self[self[sibling].left].color = .black

            // update the sibling
            sibling = self.rotateRight(sibling)
            // self[parent].right = sibling
        }
        else if node == self[parent].right,
                self.left(of: sibling).map({ self[$0].color == .black }) ?? true
        {
            self[sibling].color = .red
            self[self[sibling].right].color = .black

            // update the sibling
            sibling = rotateLeft(sibling)
            // parent.lchild = sibling
        }

        // case 6: the sibling has at least one red child on the outside. switch
        // the colors of the parent and the sibling, make the outer child black,
        // and rotate on the parent.
        self[sibling].color = self[parent].color
        self[parent].color = .black
        if node == self[parent].left
        {
            self[self[sibling].right].color = .black
            self.rotateLeft(parent)
        }
        else
        {
            self[self[sibling].left].color = .black
            self.rotateRight(parent)
        }
    }
}