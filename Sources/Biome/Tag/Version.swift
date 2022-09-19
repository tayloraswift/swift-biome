typealias _Version = Version

@usableFromInline
struct Version:Hashable, Sendable
{
    /// A reference to a ``/Biome//Branch`` within a ``Tree``.
    struct Branch:Hashable, Sendable 
    {
        let index:Int 

        init(_ index:Int)
        {
            self.index = index
        }
    }
    /// A reference to a ``/Biome//Revision`` within a ``/Biome//Branch``. 
    /// 
    /// Revision numbers always start from 0, even when a branch was forked from 
    /// another branch. This makes it possible to tell if a revision has a 
    /// branch-local predecessor without needing any external information.
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

        var predecessor:Self? 
        {
            self.index < 1 ? nil : .init(self.index - 1)
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
