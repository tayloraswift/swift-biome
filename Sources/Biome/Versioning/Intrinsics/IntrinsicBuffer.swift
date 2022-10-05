import Sediment

extension IntrinsicBuffer:Sendable 
    where   Element.Offset:Sendable, Element.Culture:Sendable, 
            Element:Sendable, Element.ID:Sendable, Element.Divergence:Sendable
{
}
struct IntrinsicBuffer<Element> where Element:IntrinsicElement & BranchElement
{
    var divergences:[Atom<Element>: Element.Divergence]
    fileprivate 
    var elements:[Element] 
    private(set)
    var atoms:Atoms
    let startIndex:Element.Offset
    
    private 
    init(startIndex:Element.Offset, 
        divergences:[Atom<Element>: Element.Divergence],
        elements:[Element],
        atoms:Atoms) 
    {
        self.startIndex = startIndex
        self.divergences = divergences
        self.elements = elements
        self.atoms = atoms
    }
    init(startIndex:Element.Offset) 
    {
        self.startIndex = startIndex
        self.divergences = [:]
        self.elements = []
        self.atoms = .init()
    }
}
extension IntrinsicBuffer:BranchAxis
{
    typealias Key = Atom<Element>

    subscript<Value>(field:Field<Value>) -> OriginalHead<Value>?
    {
        _read
        {
            if field.key.offset < self.startIndex 
            {
                yield  self.divergences[  field.key][keyPath: field.alternate]?.head
            }
            else
            {
                yield  self[contemporary: field.key][keyPath: field.original]
            }
        }
    }
    subscript<Value>(field:Field<Value>,
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
                yield &self.divergences[  field.key][keyPath: field.alternate][since: revision]
            }
            else 
            {
                yield &self[contemporary: field.key][keyPath: field.original]
            }
        }
    }
}
extension IntrinsicBuffer:RandomAccessCollection 
{
    var endIndex:Element.Offset
    {
        self.startIndex + Element.Offset.init(self.elements.count)
    }

    subscript(offset:Element.Offset) -> Element
    {
        _read 
        {
            yield  self.elements[.init(offset - self.startIndex)]
        }
        _modify
        {
            yield &self.elements[.init(offset - self.startIndex)]
        }
    }

    subscript(indices:Range<Element.Offset>) -> IntrinsicSlice<Element> 
    {
        .init(.init(startIndex: indices.lowerBound, 
                divergences: self.divergences,
                elements: self.elements,
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
            self.elements.append(try create(id, atom))
            self.atoms[id] = atom
            return atom 
        }
    }
    mutating 
    func remove(from end:Element.Offset)
    {
        self.elements.removeSubrange(Int.init(end)...)
        self.atoms = self.atoms.filter { $0.offset < end }
        fatalError("unimplemented")
    }
}
