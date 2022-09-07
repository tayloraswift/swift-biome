extension Branch.Epoch:Sendable where Element:Sendable 
{
}
extension Branch 
{
    struct Epoch<Element>:RandomAccessCollection 
        where Element:BranchElement, Element.Divergence:Voidable
    {
        private 
        let slice:Buffer<Element>.SubSequence
        /// The index of the original branch this epoch was cut from.
        /// 
        /// This is the branch that contains the epoch, not the branch 
        /// the epoch was forked from.
        let branch:_Version.Branch
        /// The index of the last revision contained within this epoch.
        let limit:_Version.Revision 

        init(_ slice:Buffer<Element>.SubSequence, branch:_Version.Branch, limit:_Version.Revision)
        {
            self.slice = slice
            self.branch = branch
            self.limit = limit
        }

        var divergences:Divergences<Position<Element>, Element.Divergence> 
        {
            .init(self.slice.divergences, limit: self.limit)
        }

        var startIndex:Element.Offset 
        {
            self.slice.startIndex
        }
        var endIndex:Element.Offset 
        {
            self.slice.endIndex
        }
        subscript(offset:Element.Offset) -> Element 
        {
            _read 
            {
                yield   self.slice[offset]
            }
        }
        subscript(position:Position<Element>) -> Element? 
        {
            _read 
            {
                yield   self.slice.indices ~= position.offset ? 
                        self.slice[contemporary: position] : nil
            }
        }

        func position(of id:Element.ID) -> Position<Element>? 
        {
            if  let position:Position<Element> = self.slice.positions[id], 
                self.slice.indices ~= position.offset
            {
                return position
            }
            else 
            {
                return nil
            }
        }
    }
}