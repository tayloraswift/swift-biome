import Sediment

extension IntrinsicBuffer:Sendable 
    where   Element:Sendable, 
            Element.Offset:Sendable, 
            Element.Culture:Sendable, 
            Element.ID:Sendable, 
            Divergence:Sendable, 
            Divergence.Base:Sendable
{
}

struct IntrinsicBuffer<Element> where Element:BranchIntrinsic
{
    var divergences:[Atom<Element>: Divergence]
    private 
    var intrinsics:[(element:Element, base:Divergence.Base)] 
    private(set)
    var atoms:Atoms
    let startIndex:Element.Offset
    
    private 
    init(startIndex:Element.Offset, 
        divergences:[Atom<Element>: Element.Divergence],
        intrinsics:[(element:Element, base:Divergence.Base)],
        atoms:Atoms) 
    {
        self.startIndex = startIndex
        self.divergences = divergences
        self.intrinsics = intrinsics
        self.atoms = atoms
    }
    init(startIndex:Element.Offset) 
    {
        self.startIndex = startIndex
        self.divergences = [:]
        self.intrinsics = []
        self.atoms = .init()
    }
}
extension IntrinsicBuffer
{
    private
    subscript(offset offset:Element.Offset) -> (element:Element, base:Divergence.Base)
    {
        _read 
        {
            yield  self.intrinsics[.init(offset - self.startIndex)]
        }
        _modify
        {
            yield &self.intrinsics[.init(offset - self.startIndex)]
        }
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
            self.intrinsics.append((try create(id, atom), .init()))
            self.atoms[id] = atom
            return atom 
        }
    }
    mutating 
    func remove(from end:Element.Offset)
    {
        self.intrinsics.removeSubrange(Int.init(end - self.startIndex)...)
        self.atoms = self.atoms.filter { $0.offset < end }
        fatalError("unimplemented")
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
            yield  self[offset: key.offset].base[keyPath: field]
        }
        _modify
        {
            yield &self[offset: key.offset].base[keyPath: field]
        }
    }

    subscript<Value>(field:FieldAccessor<Element.Divergence, Value>) -> OriginalHead<Value>?
    {
        _read
        {
            if field.key.offset < self.startIndex 
            {
                yield  self.divergences[field.key][keyPath: field.alternate]?.head
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
                yield &self.divergences[field.key][keyPath: field.alternate][since: revision]
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
    var endIndex:Element.Offset
    {
        self.startIndex + Element.Offset.init(self.intrinsics.count)
    }

    subscript(offset:Element.Offset) -> Element
    {
        _read
        {
            yield  self[offset: offset].element
        }
        _modify
        {
            yield &self[offset: offset].element
        }
    }
    
    subscript(indices:Range<Element.Offset>) -> IntrinsicSlice<Element> 
    {
        .init(.init(startIndex: indices.lowerBound, 
                divergences: self.divergences,
                intrinsics: self.intrinsics,
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
