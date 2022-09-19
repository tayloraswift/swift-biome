extension Branch.Position:Sendable where Element.Offset:Sendable, Element.Culture:Sendable
{
}
extension Branch 
{
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
}
extension Branch.Position:Hashable, Comparable 
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
extension Branch.Position 
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

extension Branch.Position where Element.Culture == Package.Index
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
extension Branch.Position where Element.Culture == Branch.Position<Module>
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
    var module:Branch.Position<Module>
    {
        self.culture 
    }
}
extension Branch 
{
    struct Diacritic:Hashable, Sendable
    {
        let host:Position<Symbol> 
        let culture:Symbol.Culture
        
        init(host:Position<Symbol>, culture:Symbol.Culture)
        {
            self.host = host 
            self.culture = culture
        }
        
        init(natural:Position<Symbol>)
        {
            self.host = natural 
            self.culture = natural.culture
        }

        var nationality:Package.Index 
        {
            self.culture.culture 
        }
    }

    // 20 B size, 24 B stride
    @usableFromInline
    struct Composite:Hashable, Sendable
    {
        //  there are up to three cultures that come into play here:
        //  1. host culture 
        //  2. witness culture 
        //  3. perpetrator culture
        let base:Position<Symbol>
        let diacritic:Diacritic 
                
        init(natural:Position<Symbol>) 
        {
            self.base = natural
            self.diacritic = .init(natural: natural)
        }
        init(_ base:Position<Symbol>, _ diacritic:Diacritic) 
        {
            self.base = base 
            self.diacritic = diacritic
        }

        var culture:Position<Module>
        {
            self.diacritic.culture
        }
        var nationality:Package.Index 
        {
            self.diacritic.nationality 
        }

        var isNatural:Bool 
        {
            self.base == self.diacritic.host
        }
        var host:Position<Symbol>? 
        {
            self.isNatural ? nil : self.diacritic.host 
        }
        var natural:Position<Symbol>? 
        {
            self.isNatural ? self.base : nil
        }
    }
}
