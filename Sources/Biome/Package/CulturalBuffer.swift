// only needed because the compiler starts crashing like hell
// if we try and factor this into generics
public 
protocol _CulturalIndex<Culture, Offset>:Strideable, Hashable
{
    associatedtype Culture:Hashable
    associatedtype Offset:UnsignedInteger
    
    var culture:Culture { get }
    var offset:Offset { get }
    
    init(_ culture:Culture, offset:Offset)
}

extension _CulturalIndex 
{
    // *really* weird shit happens if we don’t provide these implementations, 
    // because by default, ``Strideable`` ignores the `culture` property...
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
    
    @inlinable public
    func advanced(by stride:Offset.Stride) -> Self 
    {
        .init(self.culture, offset: self.offset.advanced(by: stride))
    }
    @inlinable public
    func distance(to other:Self) -> Offset.Stride
    {
        self.offset.distance(to: other.offset)
    }
}

extension CulturalBuffer:Sendable 
    where   Element:Sendable, Element.ID:Sendable, 
            OpaqueIndex:Sendable, OpaqueIndex.Offset:Sendable
{
}
// have to use separate generics, which is retarded but necessary 
// because of a compiler crash (?!?!?!)
public 
struct CulturalBuffer<Element, OpaqueIndex> where Element:Identifiable, OpaqueIndex:_CulturalIndex
{
    public 
    enum Origin 
    {
        case shared(OpaqueIndex)
        case founded(OpaqueIndex)

        var index:OpaqueIndex 
        {
            switch self 
            {
            case .shared(let index), .founded(let index): return index
            }
        }
    }

    let startIndex:OpaqueIndex.Offset
    private 
    var storage:[Element] 
    var endIndex:OpaqueIndex.Offset
    {
        self.startIndex + OpaqueIndex.Offset.init(self.storage.count)
    }
    private(set)
    var indices:[Element.ID: OpaqueIndex]
    
    var all:[Element]
    {
        _read 
        {
            yield self.storage
        }
    }
    
    init(startIndex:OpaqueIndex.Offset) 
    {
        self.startIndex = startIndex
        self.storage = []
        self.indices = [:]
    }

    
    @available(*, unavailable)
    var count:Int 
    {
        self.storage.count
    }

    subscript(index:OpaqueIndex.Offset) -> Element
    {
        _read 
        {
            yield  self.storage[.init(index - self.startIndex)]
        }
        _modify
        {
            yield &self.storage[.init(index - self.startIndex)]
        }
    }
    // needed to workaround a compiler crash
    subscript(_local index:OpaqueIndex) -> Element
    {
        self[index.offset]
    }
    subscript(local index:OpaqueIndex) -> Element
    {
        _read
        {
            yield self[index.offset]
        }
        _modify
        {
            yield &self[index.offset]
        }
    }
    
    mutating 
    func insert(_ id:Element.ID, culture:OpaqueIndex.Culture, 
        _ create:(Element.ID, OpaqueIndex) throws -> Element) rethrows -> OpaqueIndex
    {
        if let index:OpaqueIndex = self.indices[id]
        {
            return index 
        }
        else 
        {
            // create records for elements if they do not yet exist 
            let index:OpaqueIndex = .init(culture, offset: self.endIndex)
            self.storage.append(try create(id, index))
            self.indices[id] = index
            return index 
        }
    }
}
