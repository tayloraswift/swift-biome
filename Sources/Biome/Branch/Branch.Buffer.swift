extension Branch.Buffer:Sendable 
    where   Element.Offset:Sendable, Element.Culture:Sendable, 
            Element:Sendable, Element.ID:Sendable, Element.Divergence:Sendable
{
}

extension Branch 
{
    struct Buffer<Element> where Element:BranchElement, Element.Divergence:Voidable
    {
        @available(*, deprecated, renamed: "positions")
        var indices:[Element.ID: Atom<Element>] 
        {
            _read 
            {
                yield self.positions
            }
        }

        var divergences:[Atom<Element>: Element.Divergence]
        private(set)
        var positions:[Element.ID: Atom<Element>]
        private 
        var storage:[Element] 
        let startIndex:Element.Offset
        var endIndex:Element.Offset
        {
            self.startIndex + Element.Offset.init(self.storage.count)
        }
        
        init(startIndex:Element.Offset) 
        {
            self.divergences = [:]
            self.positions = [:]
            self.storage = []
            self.startIndex = startIndex
        }

        mutating 
        func insert(_ id:Element.ID, culture:Element.Culture, 
            _ create:(Element.ID, Atom<Element>) throws -> Element) 
            rethrows -> Atom<Element>
        {
            if let position:Atom<Element> = self.positions[id]
            {
                return position 
            }
            else 
            {
                // create records for elements if they do not yet exist 
                let position:Atom<Element> = .init(culture, offset: self.endIndex)
                self.storage.append(try create(id, position))
                self.positions[id] = position
                return position 
            }
        }
    }
}

extension Branch.Buffer 
{
    subscript(offset:Element.Offset) -> Element
    {
        _read 
        {
            yield self.storage[.init(offset - self.startIndex)]
        }
        _modify
        {
            yield &self.storage[.init(offset - self.startIndex)]
        }
    }
    @available(*, deprecated, renamed: "subscript(contemporary:)")
    subscript(local position:Atom<Element>) -> Element
    {
        get 
        {
            fatalError()
        }
        set 
        {
            fatalError()
        }
    }
    // needed to workaround a compiler crash: https://github.com/apple/swift/issues/60841
    subscript(_contemporary position:Atom<Element>) -> Element
    {
        self[position.offset]
    }
    subscript(contemporary position:Atom<Element>) -> Element
    {
        _read
        {
            yield  self[position.offset]
        }
        _modify
        {
            yield &self[position.offset]
        }
    }

    subscript(prefix:PartialRangeUpTo<Element.Offset>) -> SubSequence 
    {
        .init(divergences: self.divergences, 
            positions: self.positions, 
            storage: self.storage, 
            indices: self.startIndex ..< prefix.upperBound)
    }
    subscript(_:UnboundedRange) -> SubSequence 
    {
        .init(divergences: self.divergences, 
            positions: self.positions, 
            storage: self.storage, 
            indices: self.startIndex ..< self.endIndex)
    }

    @available(*, deprecated)
    var all:[Element]
    {
        _read 
        {
            yield self.storage
        }
    }
}

extension Branch.Buffer 
{
    struct SubSequence:RandomAccessCollection 
    {
        typealias Index = Element.Offset 
        typealias SubSequence = Self 

        let divergences:[Atom<Element>: Element.Divergence]
        let positions:[Element.ID: Atom<Element>]
        private 
        let storage:[Element]
        let indices:Range<Element.Offset>
        
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
                assert(self.indices ~= offset)
                yield  self.storage[.init(offset - self.startIndex)]
            }
        }
        subscript(range:Range<Element.Offset>) -> Self
        {
            .init(divergences: self.divergences,
                positions: self.positions, 
                storage: self.storage, 
                indices: range)
        }
        subscript(contemporary position:Atom<Element>) -> Element
        {
            _read
            {
                yield self[position.offset]
            }
        }
        
        init(divergences:[Atom<Element>: Element.Divergence], 
            positions:[Element.ID: Atom<Element>], 
            storage:[Element], 
            indices:Range<Element.Offset>)
        {
            self.divergences = divergences
            self.positions = positions 
            self.storage = storage 
            self.indices = indices
        }
    }
}
