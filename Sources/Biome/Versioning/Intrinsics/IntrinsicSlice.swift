struct IntrinsicSlice<Element> where Element:BranchIntrinsic
{
    private 
    let base:IntrinsicBuffer<Element>
    let endIndex:Element.Offset

    init(_ base:IntrinsicBuffer<Element>, upTo endIndex:Element.Offset)
    {
        self.base = base 
        self.endIndex = endIndex
    }
}
extension IntrinsicSlice:PeriodAxis
{
    subscript<Value>(field:FieldAccessor<Element.Divergence, Value>) -> PeriodHead<Value>
    {
        assert(field.key.offset < self.endIndex)

        return field.key.offset < self.startIndex ?
            .alternate(self.divergences[field.key]?[keyPath: field.alternate]) :
            .original(        self.base[field.key,    field: field.original])
    }
}
extension IntrinsicSlice:RandomAccessCollection
{
    typealias Index = Element.Offset 
    typealias SubSequence = Self 
    
    var startIndex:Element.Offset
    {
        self.base.startIndex
    }
    subscript(offset:Element.Offset) -> Element 
    {
        _read 
        {
            assert(self.indices ~= offset)
            yield  self.base[offset]
        }
    }
    subscript(range:Range<Element.Offset>) -> Self
    {
        self.base[range]
    }
}
extension IntrinsicSlice
{
    struct Atoms
    {
        private 
        let base:IntrinsicBuffer<Element>.Atoms
        private 
        let indices:Range<Index>

        fileprivate
        init(base:IntrinsicBuffer<Element>.Atoms, indices:Range<Index>)
        {
            self.base = base
            self.indices = indices
        }

        subscript(id:Element.ID) -> Atom<Element>?
        {
            if  let atom:Atom<Element> = self.base[id], 
                self.indices ~= atom.offset
            {
                return atom
            }
            else 
            {
                return nil
            }
        }
    }

    subscript(contemporary atom:Atom<Element>) -> Element
    {
        _read
        {
            yield self.base[contemporary: atom]
        }
    }
    var divergences:[Atom<Element>: Element.Divergence]
    {
        self.base.divergences
    }
    var atoms:Atoms
    {
        .init(base: self.base.atoms, indices: self.indices)
    }
}