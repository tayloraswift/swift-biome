extension Epoch:Sendable where Element:Sendable 
{
}
struct Epoch<Element>:RandomAccessCollection 
    where Element:BranchElement, Element.Divergence:Voidable
{
    private 
    let slice:Branch.Buffer<Element>.SubSequence
    /// The index of the original branch this epoch was cut from.
    /// 
    /// This is the branch that contains the epoch, not the branch 
    /// the epoch was forked from.
    let branch:Version.Branch
    /// The index of the last revision contained within this epoch.
    let limit:Version.Revision 

    init(_ slice:Branch.Buffer<Element>.SubSequence, 
        branch:Version.Branch, 
        limit:Version.Revision)
    {
        self.slice = slice
        self.branch = branch
        self.limit = limit
    }

    var divergences:Divergences<Branch.Position<Element>, Element.Divergence> 
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
    subscript(position:Branch.Position<Element>) -> Element? 
    {
        _read 
        {
            yield   self.slice.indices ~= position.offset ? 
                    self.slice[contemporary: position] : nil
        }
    }

    func position(of id:Element.ID) -> Branch.Position<Element>? 
    {
        if  let position:Branch.Position<Element> = self.slice.positions[id], 
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