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
        var indices:[Element.ID: Position<Element>] 
        {
            _read 
            {
                yield self.positions
            }
        }

        var divergences:[Position<Element>: Element.Divergence]
        private(set)
        var positions:[Element.ID: Position<Element>]
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
        func update<Value>(_ position:Position<Element>, with value:__owned Value, 
            revision:_Version.Revision, 
            trunk:some Sequence<Epoch<Element>>,
            field:
            (
                contemporary:WritableKeyPath<Element, _History<Value>.Head?>,
                divergent:WritableKeyPath<Element.Divergence, _History<Value>.Divergent?>
            ),
            in history:inout _History<Value>)
            where Value:Equatable
        {
            guard position.offset < self.startIndex 
            else 
            {
                // symbol is contemporary to this branch. 
                history.add(_move value, revision: revision, 
                    to: &self[contemporary: position][keyPath: field.contemporary])
                return 
            }
            if let previous:Value = (self.divergences[position]?[keyPath: field.divergent])
                    .map({ history[$0.head.index].value })
            {
                if previous == value 
                {
                    // symbol is not contemporary, but has already diverged in this 
                    // epoch, and its divergent value matches.
                    return 
                }
            }
            else if case value? = history.value(of: position, field: field, in: trunk)
            {
                // symbol is not contemporary, has not diverged in this epoch, 
                // but its value (divergent or not) matches.
                return 
            }
            history.push(_move value, revision: revision, 
                to: &self.divergences[position, default: .init()][keyPath: field.divergent])
        }
    }
}

extension Branch.Buffer 
{
    @available(*, deprecated, renamed: "Branch.Position")
    typealias OpaqueIndex = Branch.Position<Element>

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
    @available(*, deprecated, renamed: "subscript(contemporary:)")
    subscript(local position:Branch.Position<Element>) -> Element
    {
        _read
        {
            yield self[position.offset]
        }
        _modify
        {
            yield &self[position.offset]
        }
    }
    subscript(contemporary position:Branch.Position<Element>) -> Element
    {
        _read
        {
            yield self[position.offset]
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
    
    mutating 
    func insert(_ id:Element.ID, culture:Element.Culture, 
        _ create:(Element.ID, Branch.Position<Element>) throws -> Element) 
        rethrows -> Branch.Position<Element>
    {
        if let position:Branch.Position<Element> = self.positions[id]
        {
            return position 
        }
        else 
        {
            // create records for elements if they do not yet exist 
            let position:Branch.Position<Element> = .init(culture, offset: self.endIndex)
            self.storage.append(try create(id, position))
            self.positions[id] = position
            return position 
        }
    }
}

extension Branch.Buffer 
{
    struct SubSequence:RandomAccessCollection 
    {
        typealias Index = Element.Offset 
        typealias SubSequence = Self 

        let divergences:[Branch.Position<Element>: Element.Divergence]
        let positions:[Element.ID: Branch.Position<Element>]
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
        subscript(contemporary position:Branch.Position<Element>) -> Element
        {
            _read
            {
                yield self[position.offset]
            }
        }

        // func index(before base:Element.Offset) -> Element.Offset
        // {
        //     base - 1
        // }
        // func index(after base:Element.Offset) -> Element.Offset
        // {
        //     base + 1
        // }
        // func index(_ base:Element.Offset, offsetBy distance:Int) -> Element.Offset
        // {
        //     Element.Offset.init(Int.init(base) + distance)
        // }
        
        init(divergences:[Branch.Position<Element>: Element.Divergence], 
            positions:[Element.ID: Branch.Position<Element>], 
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
