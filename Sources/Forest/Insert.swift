extension Forest 
{
    @inlinable public mutating 
    func insert(_ index:Index, after predecessor:Index, root:inout Index?)
    {
        if let right:Index = self.right(of: predecessor)
        {
            let parent:Index = self.leftmost(of: right)
            self[parent].left = index
            self[index].parent = parent
        }
        else
        {
            self[predecessor].right = index
            self[index].parent = predecessor
        }

        self.balanceInsertion(at: index, root: &root)
    }
    @inlinable public mutating 
    func balanceInsertion(at node:Index, root:inout Index?)
    {
        assert(self[node].color == .red)

        guard let parent:Index = self.parent(of: node)
        else
        {
            // case 1: the node is the root. repaint the node black
            self[node].color = .black
            return
        }
        guard case .red = self[parent].color
        else 
        {
            // case 2: the node’s parent is black. the tree is already valid
            return
        }
        // from here on out, the node *must* have a grandparent because its
        // parent is red which means it cannot be the root
        let grandparent:Index = self[parent].parent
        let right:Index? = self.right(of: grandparent)
        let left:Index? = self.left(of: grandparent)

        switch (left, right) 
        {
        case    (parent?, let uncle?),
                (let uncle?, parent?):
            guard case .red = self[uncle].color 
            else 
            {
                break 
            }
            // case 3: both the parent and the uncle are red. repaint both of them
            //         black and make the grandparent red. fix the grandparent.
            self[parent].color = .black
            self[uncle].color = .black

            // recursive call
            self[grandparent].color = .red
            self.balanceInsertion(at: grandparent, root: &root)
            return

        default: 
            break 
        }

        // case 4: the node’s parent is red, its uncle is black, and the node is
        //         an inner child. perform a rotation on the node’s parent.
        //         then fallthrough to case 5.
        let pivot:Index
        if      case (node?, parent?) = (self.right(of: parent), left)
        {
            pivot = parent
            self[grandparent].left = self.rotateLeft(parent, under: grandparent)
        }
        else if case (parent?, node?) = (right, self.left(of: parent)) 
        {
            pivot = parent
            self[grandparent].right = self.rotateRight(parent, under: grandparent)
        }
        else
        {
            pivot = node
        }

        // case 5: the node’s (n)’s parent is red, its uncle is black, and the node
        //         is an outer child. rotate on the grandparent, which is known
        //         to be black, and switch its color with the former parent’s.

        // counterpart *always* exists!
        let counterpart:Index = self[pivot].parent

        self[counterpart].color = .black
        self[grandparent].color = .red
        // counterpart *always* has at least one child!
        if pivot == self[counterpart].left
        {
            if let greatgrandparent:Index = self.parent(of: grandparent)
            {
                self.rotateRight(grandparent, under: greatgrandparent)
            }
            else
            {
                root = self.rotateRight(grandparent)
            }
        }
        else
        {
            if let greatgrandparent:Index = self.parent(of: grandparent)
            {
                self.rotateLeft(grandparent, under: greatgrandparent)
            }
            else 
            {
                root = self.rotateLeft(grandparent)
            }
        }
    }
}