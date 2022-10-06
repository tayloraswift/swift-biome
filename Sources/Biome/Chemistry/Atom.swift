@frozen public 
struct Atom<Element> where Element:Intrinsic
{
    public 
    let culture:Element.Culture
    public 
    let offset:Element.Offset
    
    @inlinable public 
    init(_ culture:Element.Culture, offset:Element.Offset)
    {
        self.culture = culture
        self.offset = offset
    }
}
extension Atom:Sendable where Element.Offset:Sendable, Element.Culture:Sendable
{
}
extension Atom:Hashable, Comparable 
{
    @inlinable public static 
    func == (lhs:Self, rhs:Self) -> Bool
    {
        lhs.offset == rhs.offset && lhs.culture == rhs.culture 
    }
    @inlinable public static 
    func < (lhs:Self, rhs:Self) -> Bool
    {
        lhs.offset < rhs.offset
    }
    @inlinable public 
    func hash(into hasher:inout Hasher)
    {
        self.culture.hash(into: &hasher)
        self.offset.hash(into: &hasher)
    }
    // @inlinable public
    // func advanced(by stride:Offset.Stride) -> Self 
    // {
    //     .init(self.culture, offset: self.offset.advanced(by: stride))
    // }
    // @inlinable public
    // func distance(to other:Self) -> Offset.Stride
    // {
    //     self.offset.distance(to: other.offset)
    // }
}
extension Atom 
{
    func positioned(_ branch:Version.Branch) -> Atom<Element>.Position
    {
        .init(self, branch: branch)
    }
    func positioned(
        bisecting trunk:some RandomAccessCollection<Period<IntrinsicSlice<Element>>>) 
        -> Atom<Element>.Position?
    {
        let period:Period<IntrinsicSlice<Element>>? = trunk.search 
        {
            if      self.offset < $0.axis.indices.lowerBound 
            {
                return .lower 
            }
            else if self.offset < $0.axis.indices.upperBound 
            {
                return nil 
            }
            else 
            {
                return .upper
            }
        }
        return (period?.branch).map(self.positioned(_:))
    }
}
private
enum BinarySearchPartition 
{
    case lower 
    case upper
}
private 
extension RandomAccessCollection 
{
    func search(by partition:(Element) throws -> BinarySearchPartition?) rethrows -> Element?
    {
        var count:Int = self.count
        var current:Index = self.startIndex
        
        while 0 < count
        {
            let half:Int = count >> 1
            let median:Index = self.index(current, offsetBy: half)

            let element:Element = self[median]
            switch try partition(element)
            {
            case .lower?:
                count = half
            case nil: 
                return element
            case .upper?:
                current = self.index(after: median)
                count -= half + 1
            }
        }
        return nil
    }
}

extension Atom where Element.Culture == Packages.Index
{
    var nationality:Packages.Index 
    {
        self.culture 
    }
}
extension Atom where Element.Culture == Atom<Module>
{
    var nationality:Packages.Index
    {
        self.culture.culture
    }
}