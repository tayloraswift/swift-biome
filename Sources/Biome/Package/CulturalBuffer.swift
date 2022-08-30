public 
protocol Cultured<Culture, Offset>:Identifiable
{
    associatedtype Culture:Hashable 
    associatedtype Offset:UnsignedInteger
}
extension Cultured 
{
    public typealias Index = CulturalBuffer<Self>.OpaqueIndex
}

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

extension CulturalBuffer.OpaqueIndex:Sendable 
    where Element.Offset:Sendable, Element.Culture:Sendable
{
}
extension CulturalBuffer:Sendable 
    where Element:Sendable, Element.ID:Sendable, Element.Offset:Sendable, Element.Culture:Sendable
{
}
extension CulturalBuffer.OpaqueIndex where Element.Culture == Package.Index
{
    var package:Package.Index 
    {
        self.culture 
    }
}
extension CulturalBuffer.OpaqueIndex where Element.Culture == Module.Index
{
    var module:Module.Index 
    {
        self.culture 
    }
}
// have to use separate generics, which is retarded but necessary 
// because of a compiler crash (?!?!?!)
public 
struct CulturalBuffer<Element> where Element:Cultured
{
    @frozen public 
    struct OpaqueIndex:Hashable
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
    }

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

    let startIndex:Element.Offset
    private 
    var storage:[Element] 
    var endIndex:Element.Offset
    {
        self.startIndex + Element.Offset.init(self.storage.count)
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
    
    init(startIndex:Element.Offset) 
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

    subscript(index:Element.Offset) -> Element
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
    func insert(_ id:Element.ID, culture:Element.Culture, 
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
