@usableFromInline
struct Version:Hashable, Sendable
{
    /// A reference to a ``/Biome//Branch`` within a ``Tree``.
    struct Branch:Hashable, Strideable, Sendable 
    {
        let offset:UInt16 

        init(_ offset:UInt16)
        {
            self.offset = offset
        }
        
        static 
        func < (lhs:Self, rhs:Self) -> Bool
        {
            lhs.offset < rhs.offset
        }
        func advanced(by stride:Int) -> Self 
        {
            .init(self.offset.advanced(by: stride))
        }
        func distance(to other:Self) -> Int
        {
            self.offset.distance(to: other.offset)
        }
    }
    /// A reference to a ``/Biome//Revision`` within a ``/Biome//Branch``. 
    /// 
    /// Revision numbers always start from 0, even when a branch was forked from 
    /// another branch. This makes it possible to tell if a revision has a 
    /// branch-local predecessor without needing any external information.
    struct Revision:Hashable, Strideable, Sendable
    {
        let offset:UInt16 

        static 
        let max:Self = .init(.max)

        init(_ offset:UInt16)
        {
            self.offset = offset
        }

        static 
        func < (lhs:Self, rhs:Self) -> Bool
        {
            lhs.offset < rhs.offset
        }
        func advanced(by stride:Int) -> Self 
        {
            .init(self.offset.advanced(by: stride))
        }
        func distance(to other:Self) -> Int
        {
            self.offset.distance(to: other.offset)
        }

        var predecessor:Self? 
        {
            self.offset < 1 ? nil : .init(self.offset - 1)
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
