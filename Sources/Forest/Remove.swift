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
    func sink(_ node:Index, on position:(side:Node.Side, of:Index)?, left a:Index, right b:Index) 
        -> Index 
    {
        if case (left: let replacement, parent: let c)? = self.leftmost(of: b)
        {
            let d:Index? = self.right(of: replacement)
            //  there are up to 5 links that need to be updated, 
            //  which requires up to 11 memory writes. 
            //
            //  the additional write is because we must `nil`-out 
            //  the `node`’s left-child, since the replacement 
            //  will never have one.
            //
            //  note: (b) and (c) may be the same node. 
            //           ┆
            //         (node)
            //  ┌────────┴───────────────────────────┐
            // (a)                                  (b)
            //                              ┌────────┴───────┐
            //                             (c)
            //                      ┌───────┴───────┐
            //               (replacement)
            //                      └───┐
            //                         (d?)
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

            self[c].left = node // 7
            self[node].parent = c // 8
            if let d:Index
            {
                self[d].parent = node // 9
                self[node].right = d // 10
            }
            else 
            {
                self[node].right = node
            }
            self[node].left = node // 11
            return replacement
        }
        else 
        {
            let replacement:Index = b
            let d:Index? = self.right(of: replacement)
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
            //                                              (d?)
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
            self[replacement].right = node // 4
            self[node].parent = replacement // 5
            self[a].parent = replacement // 6
            if let d:Index
            {
                self[d].parent = node // 7
                self[node].right = d // 8
            }
            else 
            {
                self[node].right = node
            }
            self[node].left = node // 9
            return replacement
        }
    }
    @inlinable public mutating 
    func remove(_ node:Index, on position:(side:Node.Side, of:Index)?)
    {
        let color:Node.Color 
        if  let a:Index = self.left(of: node),
            let b:Index = self.right(of: node)
        {
            let replacement:Index = self.sink(node, on: position, left: a, right: b)
            color = self[replacement].color
            self[replacement].color = self[node].color
            self[node].color = color 
        }
        else 
        {
            color = self[node].color
        }

        if case .red = color 
        {
            assert(self[node].left == node && self[node].right == node)
            // a red node cannot be the root, so it must have a parent
            self._replaceLink(to: node, with: nil, onParent: self[node].parent)
        }
        else if let child:Index = self.left(of: node) ?? self.right(of: node),
                case .red = self[child].color
        {
            if let parent:Index = self.parent(of: node)
            {
                self._replaceLink(to: node, with: child, onParent: parent)
                self[child].parent = parent
            }
            else
            {
                self[child].parent = child
                // root = child
            }

            self[child].color = .black
        }
        else
        {
            self.balance(removal: node)
            // the root case is checked but not handled inside the
            // balanceDeletion(phantom:root:) function
            if let parent:Index = self.parent(of: node)
            {
                self._replaceLink(to: node, with: nil, onParent: parent)
            }
            // else
            // {
            //     root = nil
            // }
        }

        self[node].state = nil
    }
    @inlinable public mutating 
    func balance(removal node:Index)
    {
        // case 1: node is the root. do nothing. don’t nil out the root because
        // we may be here on a recursive call
        guard let parent:Index = self.parent(of: node)
        else
        {
            return
        }
        // the node must have a sibling, since if it did not, the sibling subtree
        // would only contribute +1 black height compared to the node’s subtree’s
        // +2 black height.
        assert(self[parent].left  != parent)
        assert(self[parent].right != parent)
        var sibling:Index = node == self[parent].left ? self[parent].right : self[parent].left

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
            self.balance(removal: parent)
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