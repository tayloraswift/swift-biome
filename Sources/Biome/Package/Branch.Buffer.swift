extension Branch.Buffer.OpaqueIndex:Sendable 
    where   Element.Offset:Sendable, Element.Culture:Sendable
{
}
extension Branch.Buffer:Sendable 
    where   Element.Offset:Sendable, Element.Culture:Sendable, 
            Element:Sendable, Element.ID:Sendable
{
}
extension Branch.Buffer.OpaqueIndex where Element.Culture == Package.Index
{
    var package:Package.Index 
    {
        self.culture 
    }
}
extension Branch.Buffer.OpaqueIndex where Element.Culture == Module.Index
{
    var module:Module.Index 
    {
        self.culture 
    }
}

extension Branch 
{
    public 
    struct Buffer<Element> where Element:BranchElement
    {
        let startIndex:Element.Offset
        private 
        var storage:[Element] 
        var endIndex:Element.Offset
        {
            self.startIndex + Element.Offset.init(self.storage.count)
        }
        private(set)
        var indices:[Element.ID: OpaqueIndex]
        
        init(startIndex:Element.Offset) 
        {
            self.startIndex = startIndex
            self.storage = []
            self.indices = [:]
        }
    }
}
extension Branch.Buffer 
{
    @frozen public 
    struct OpaqueIndex:Hashable, Comparable
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

    @available(*, unavailable)
    var count:Int 
    {
        self.storage.count
    }

    subscript(offset:Element.Offset) -> Element
    {
        _read 
        {
            yield  self.storage[.init(offset - self.startIndex)]
        }
        _modify
        {
            yield &self.storage[.init(offset - self.startIndex)]
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
    subscript(prefix:PartialRangeUpTo<Element.Offset>) -> SubSequence 
    {
        .init(storage: self.storage, opaque: self.indices, 
            indices: self.startIndex ..< prefix.upperBound)
    }

    @available(*, deprecated)
    var all:[Element]
    {
        _read 
        {
            yield self.storage
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

extension Branch.Buffer 
{
    struct SubSequence:RandomAccessCollection 
    {
        typealias Index = Element.Offset 
        typealias SubSequence = Self 

        let indices:Range<Element.Offset>
        private 
        let storage:[Element], 
            opaque:[Element.ID: OpaqueIndex]
        
        var startIndex:Element.Offset
        {
            self.indices.lowerBound
        }
        var endIndex:Element.Offset
        {
            self.indices.upperBound
        }
        subscript(offset:Element.Offset) -> Element 
        {
            _read 
            {
                yield  self.storage[.init(offset - self.startIndex)]
            }
        }
        subscript(range:Range<Element.Offset>) -> Self
        {
            .init(storage: self.storage, opaque: self.opaque, indices: range)
        }

        func index(before base:Element.Offset) -> Element.Offset
        {
            base - 1
        }
        func index(after base:Element.Offset) -> Element.Offset
        {
            base + 1
        }
        // func index(_ base:Element.Offset, offsetBy distance:Int) -> Element.Offset
        // {
        //     Element.Offset.init(Int.init(base) + distance)
        // }
        
        init(storage:[Element], opaque:[Element.ID: OpaqueIndex], indices:Range<Element.Offset>)
        {
            self.storage = storage 
            self.opaque = opaque 
            self.indices = indices
        }

        func opaque(of id:Element.ID) -> OpaqueIndex? 
        {
            if let opaque:OpaqueIndex = self.opaque[id], self.indices ~= opaque.offset
            {
                return opaque
            }
            else 
            {
                return nil
            }
        }
    }
}