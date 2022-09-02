struct _Version:Hashable, Sendable 
{
    struct Branch:Hashable, Sendable 
    {
        let index:Int 

        init(_ index:Int)
        {
            self.index = index
        }
    }
    struct Revision:Hashable, Strideable, Sendable
    {
        let index:UInt16 

        static 
        let max:Self = .init(.max)

        init(_ index:UInt16)
        {
            self.index = index
        }

        static 
        func < (lhs:Self, rhs:Self) -> Bool
        {
            lhs.index < rhs.index
        }
        func advanced(by stride:Int.Stride) -> Self 
        {
            .init(self.index.advanced(by: stride))
        }
        func distance(to other:Self) -> Int.Stride
        {
            self.index.distance(to: other.index)
        }
    }

    var branch:Branch
    var revision:Revision

    init(_ branch:Branch, _ revision:Revision)
    {
        self.branch = branch 
        self.revision = revision 
    }
}

extension _Version.Branch 
{
    func pluralize<Element>(_ position:Branch.Position<Element>) -> Tree.Position<Element> 
        where Element:BranchElement 
    {
        .init(position, branch: self)
    }
    func idealize<Element>(_ position:Tree.Position<Element>) -> Branch.Position<Element>?
        where Element:BranchElement 
    {
        self == position.branch ? position.contemporary : nil 
    }
}