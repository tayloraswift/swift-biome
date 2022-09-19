@frozen public 
struct Position<Element> where Element:BranchElement
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
extension Position:Sendable where Element.Offset:Sendable, Element.Culture:Sendable
{
}
extension Position:Hashable, Comparable 
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
extension Position 
{
    func pluralized(_ branch:Version.Branch) -> PluralPosition<Element>
    {
        .init(self, branch: branch)
    }
    func pluralized(bisecting trunk:some RandomAccessCollection<Epoch<Element>>) 
        -> PluralPosition<Element>?
    {
        let epoch:Epoch<Element>? = trunk.search 
        {
            if      self.offset < $0.indices.lowerBound 
            {
                return .lower 
            }
            else if self.offset < $0.indices.upperBound 
            {
                return nil 
            }
            else 
            {
                return .upper
            }
        }
        return (epoch?.branch).map(self.pluralized(_:))
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

extension Position where Element.Culture == Package.Index
{
    var nationality:Package.Index 
    {
        self.culture 
    }

    @available(*, deprecated, renamed: "nationality")
    var package:Package.Index 
    {
        self.nationality 
    }
}
extension Position where Element.Culture == Position<Module>
{
    var nationality:Package.Index
    {
        self.culture.culture
    }

    @available(*, deprecated, renamed: "nationality")
    var package:Package.Index
    {
        self.nationality
    }
    @available(*, deprecated, renamed: "culture")
    var module:Position<Module>
    {
        self.culture 
    }
}
