public 
protocol CulturalIndex:Strideable, Hashable
{
    associatedtype Culture:Hashable
    associatedtype Bits:UnsignedInteger
    
    var culture:Culture { get }
    var bits:Bits { get }
    
    init(_ culture:Culture, bits:Bits)
}
extension CulturalIndex 
{
    init(_ culture:Culture, offset:Int)
    {
        self.init(culture, bits: .init(offset))
    }
    var offset:Int 
    {
        .init(self.bits)
    }
    // *really* weird shit happens if we don’t provide these implementations, 
    // because by default, ``Strideable`` ignores the `culture` property...
    @inlinable public static 
    func == (lhs:Self, rhs:Self) -> Bool
    {
        lhs.bits == rhs.bits && lhs.culture == rhs.culture 
    }
    @inlinable public static 
    func < (lhs:Self, rhs:Self) -> Bool
    {
        lhs.bits < rhs.bits
    }
    @inlinable public 
    func hash(into hasher:inout Hasher)
    {
        self.culture.hash(into: &hasher)
        self.bits.hash(into: &hasher)
    }
    
    @inlinable public
    func advanced(by stride:Bits.Stride) -> Self 
    {
        .init(self.culture, bits: self.bits.advanced(by: stride))
    }
    @inlinable public
    func distance(to other:Self) -> Bits.Stride
    {
        self.bits.distance(to: other.bits)
    }
}

struct CulturalBuffer<Index, Element> where Index:CulturalIndex, Element:Identifiable
{
    private 
    var storage:[Element] 
    private(set)
    var indices:[Element.ID: Index]
    
    var all:[Element]
    {
        _read 
        {
            yield self.storage
        }
    }
    
    init() 
    {
        self.storage = []
        self.indices = [:]
    }
    
    // in general we use ``count`` and not `endIndex` because cultural indices 
    // are defined in terms of offsets ...
    var count:Int 
    {
        self.storage.count
    }
    
    subscript(local index:Index) -> Element
    {
        _read 
        {
            yield  self.storage[index.offset]
        }
        _modify
        {
            yield &self.storage[index.offset]
        }
    }
    
    mutating 
    func insert(_ id:Element.ID, culture:Index.Culture, 
        _ create:(Element.ID, Index) throws -> Element) rethrows -> Index 
    {
        if let index:Index = self.indices[id]
        {
            return index 
        }
        else 
        {
            // create records for elements if they do not yet exist 
            let index:Index = .init(culture, offset: self.count)
            self.storage.append(try create(id, index))
            self.indices[id] = index
            return index 
        }
    }
}
