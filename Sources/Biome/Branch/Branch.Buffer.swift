extension Branch.Buffer:Sendable 
    where   Element.Offset:Sendable, Element.Culture:Sendable, 
            Element:Sendable, Element.ID:Sendable, Element.Divergence:Sendable
{
}

extension Branch 
{
    struct Buffer<Element> where Element:BranchElement, Element.Divergence:Voidable
    {
        @available(*, deprecated, renamed: "atoms")
        var indices:[Element.ID: Atom<Element>] 
        {
            _read 
            {
                yield self.atoms
            }
        }
        @available(*, deprecated, renamed: "atoms")
        var positions:[Element.ID: Atom<Element>] 
        {
            _read 
            {
                yield self.atoms
            }
        }

        var divergences:[Atom<Element>: Element.Divergence]
        private(set)
        var atoms:[Element.ID: Atom<Element>]
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
            self.atoms = [:]
            self.storage = []
            self.startIndex = startIndex
        }

        mutating 
        func insert(_ id:Element.ID, culture:Element.Culture, 
            _ create:(Element.ID, Atom<Element>) throws -> Element) 
            rethrows -> Atom<Element>
        {
            if let atom:Atom<Element> = self.atoms[id]
            {
                return atom 
            }
            else 
            {
                // create records for elements if they do not yet exist 
                let atom:Atom<Element> = .init(culture, offset: self.endIndex)
                self.storage.append(try create(id, atom))
                self.atoms[id] = atom
                return atom 
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
    subscript(local atom:Atom<Element>) -> Element
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
    subscript(_contemporary atom:Atom<Element>) -> Element
    {
        self[atom.offset]
    }
    subscript(contemporary atom:Atom<Element>) -> Element
    {
        _read
        {
            yield  self[atom.offset]
        }
        _modify
        {
            yield &self[atom.offset]
        }
    }

    subscript(prefix:PartialRangeUpTo<Element.Offset>) -> SubSequence 
    {
        .init(divergences: self.divergences, 
            indices: self.startIndex ..< prefix.upperBound,
            storage: self.storage, 
            atoms: self.atoms)
    }
    subscript(_:UnboundedRange) -> SubSequence 
    {
        .init(divergences: self.divergences, 
            indices: self.startIndex ..< self.endIndex,
            storage: self.storage, 
            atoms: self.atoms)
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
        private 
        let storage:[Element]
        let atoms:[Element.ID: Atom<Element>]
        let indices:Range<Element.Offset>

        @available(*, deprecated, renamed: "atoms")
        var positions:[Element.ID: Atom<Element>] 
        {
            _read 
            {
                yield self.atoms
            }
        }
        
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
            .init(divergences: self.divergences, indices: range,
                storage: self.storage, 
                atoms: self.atoms)
        }
        subscript(contemporary atom:Atom<Element>) -> Element
        {
            _read
            {
                yield self[atom.offset]
            }
        }
        
        init(divergences:[Atom<Element>: Element.Divergence], 
            indices:Range<Element.Offset>,
            storage:[Element], 
            atoms:[Element.ID: Atom<Element>])
        {
            self.divergences = divergences
            self.indices = indices
            self.storage = storage 
            self.atoms = atoms 
        }
    }
}
