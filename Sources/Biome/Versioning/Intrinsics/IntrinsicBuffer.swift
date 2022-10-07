extension IntrinsicBuffer:Sendable 
    where   Element:Sendable, 
            Element.Offset:Sendable, 
            Element.Culture:Sendable, 
            Element.ID:Sendable, 
            Divergence:Sendable, 
            Divergence.Base:Sendable
{
}

extension IntrinsicBuffer
{
    struct Intrinsics
    {
        private 
        var storage:[(element:Element, base:Divergence.Base)] 
        let startIndex:Element.Offset

        private
        init(startIndex:Element.Offset, storage:[(element:Element, base:Divergence.Base)])
        {
            self.storage = storage
            self.startIndex = startIndex
        }
        init(startIndex:Element.Offset)
        {
            self.init(startIndex: startIndex, storage: [])
        }
    }
}
extension IntrinsicBuffer.Intrinsics
{
    mutating 
    func append(id:Element.ID, culture:Element.Culture, 
        creator create:(Element.ID, Atom<Element>) throws -> Element) rethrows -> Atom<Element>
    {
        let atom:Atom<Element> = .init(culture, offset: self.endIndex)
        self.storage.append((try create(id, atom), .init()))
        return atom 
    }
    mutating 
    func remove(from index:Element.Offset)
    {
        self.storage.removeSubrange(Int.init(index - self.startIndex)...)
    }
    mutating 
    func removeAll()
    {
        self.storage = []
    }
}
extension IntrinsicBuffer.Intrinsics
{
    func suffix(from index:Element.Offset) -> Self
    {
        .init(startIndex: indices.lowerBound, storage: self.storage)
    }
}
extension IntrinsicBuffer.Intrinsics:RandomAccessCollection
{
    var endIndex:Element.Offset
    {
        self.startIndex + Element.Offset.init(self.storage.count)
    }
    subscript(index:Element.Offset) -> (element:Element, base:Element.Divergence.Base)
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
}

struct IntrinsicBuffer<Element> where Element:BranchIntrinsic
{
    private(set)
    var atoms:Atoms
    private(set)
    var divergences:[Atom<Element>: Divergence]
    private 
    var intrinsics:Intrinsics
    
    private 
    init(divergences:[Atom<Element>: Element.Divergence],
        intrinsics:Intrinsics,
        atoms:Atoms) 
    {
        self.divergences = divergences
        self.intrinsics = intrinsics
        self.atoms = atoms
    }
    init(startIndex:Element.Offset) 
    {
        self.divergences = [:]
        self.intrinsics = .init(startIndex: startIndex)
        self.atoms = .init()
    }
}
extension IntrinsicBuffer
{
    mutating 
    func insert(_ id:Element.ID, culture:Element.Culture, 
        creator create:(Element.ID, Atom<Element>) throws -> Element) 
        rethrows -> Atom<Element>
    {
        if let atom:Atom<Element> = self.atoms[id]
        {
            return atom 
        }
        else 
        {
            // create records for elements if they do not yet exist 
            let atom:Atom<Element> = try self.intrinsics.append(id: id, culture: culture, 
                creator: create)
            self.atoms[id] = atom
            return atom 
        }
    }
    mutating 
    func revert(to rollbacks:History.Rollbacks, through end:Element.Offset)
    {
        self.intrinsics.remove(from: end)
        for index:Element.Offset in self.intrinsics.indices
        {
            self.intrinsics[index].base.revert(to: rollbacks)
        }
        self.divergences.revert(to: rollbacks)
        self.atoms = self.atoms.filter { $0.offset < end }
    }
    mutating 
    func revert()
    {
        self.intrinsics.removeAll()
        self.divergences = [:]
        self.atoms = .init()
    }
}
extension IntrinsicBuffer:BranchAxis
{
    private(set)
    subscript<Value>(key:Atom<Element>, 
        field field:WritableKeyPath<Divergence.Base, Value>) -> Value
    {
        _read
        {
            yield  self.intrinsics[key.offset].base[keyPath: field]
        }
        _modify
        {
            yield &self.intrinsics[key.offset].base[keyPath: field]
        }
    }

    subscript<Value>(field:FieldAccessor<Element.Divergence, Value>) -> OriginalHead<Value>?
    {
        _read
        {
            if field.key.offset < self.startIndex 
            {
                yield  self.divergences[field.key]?[keyPath: field.alternate]?.head
            }
            else
            {
                yield  self[field.key, field: field.original]
            }
        }
    }
    subscript<Value>(field:FieldAccessor<Element.Divergence, Value>,
        since revision:Version.Revision) -> OriginalHead<Value>?
    {
        _read
        {
            yield self[field]
        }
        _modify
        {
            if field.key.offset < self.startIndex
            {
                yield &self.divergences[field.key, default: .init()][keyPath: field.alternate][since: revision]
            }
            else 
            {
                yield &self[field.key, field: field.original]
            }
        }
    }
}
extension IntrinsicBuffer:RandomAccessCollection 
{
    var startIndex:Element.Offset
    {
        self.intrinsics.startIndex
    }
    var endIndex:Element.Offset
    {
        self.intrinsics.endIndex
    }

    subscript(index:Element.Offset) -> Element
    {
        _read
        {
            yield  self.intrinsics[index].element
        }
        _modify
        {
            yield &self.intrinsics[index].element
        }
    }
    
    subscript(indices:Range<Element.Offset>) -> IntrinsicSlice<Element> 
    {
        .init(.init(divergences: self.divergences,
                intrinsics: self.intrinsics.suffix(from: indices.lowerBound),
                atoms: self.atoms),
            upTo: indices.upperBound)
    }
    subscript(prefix:PartialRangeUpTo<Element.Offset>) -> IntrinsicSlice<Element> 
    {
        .init(self, upTo: prefix.upperBound)
    }
    subscript(_:UnboundedRange) -> IntrinsicSlice<Element> 
    {
        .init(self, upTo: self.endIndex)
    }
}
extension IntrinsicBuffer
{
    struct Atoms
    {
        private 
        var table:[Element.ID: Atom<Element>]

        private 
        init(_ table:[Element.ID: Atom<Element>])
        {
            self.table = table
        }
        init()
        {
            self.init([:])
        }

        subscript(id:Element.ID) -> Atom<Element>?
        {
            _read
            {
                yield  self.table[id]
            }
            _modify
            {
                yield &self.table[id]
            }
        }

        func filter(where predicate:(Atom<Element>) throws -> Bool) rethrows -> Self
        {
            .init(try self.table.filter { try predicate($0.value) })
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
}
