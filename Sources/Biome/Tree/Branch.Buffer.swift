extension Branch.Buffer:Sendable 
    where   Element.Offset:Sendable, Element.Culture:Sendable, 
            Element:Sendable, Element.ID:Sendable
{
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
        @available(*, deprecated, renamed: "positions")
        var indices:[Element.ID: Position<Element>] 
        {
            _read 
            {
                yield self.positions
            }
        }

        private(set)
        var positions:[Element.ID: Position<Element>]
        
        init(startIndex:Element.Offset) 
        {
            self.startIndex = startIndex
            self.positions = [:]
            self.storage = []
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
        .init(positions: self.positions, storage: self.storage, 
            indices: self.startIndex ..< prefix.upperBound)
    }
    subscript(_:UnboundedRange) -> SubSequence 
    {
        .init(positions: self.positions, storage: self.storage, 
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

        let indices:Range<Element.Offset>
        private 
        let storage:[Element], 
            positions:[Element.ID: Branch.Position<Element>]
        
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
            .init(positions: self.positions, storage: self.storage, indices: range)
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
        
        init(positions:[Element.ID: Branch.Position<Element>], 
            storage:[Element], 
            indices:Range<Element.Offset>)
        {
            self.positions = positions 
            self.storage = storage 
            self.indices = indices
        }

        func position(of id:Element.ID) -> Branch.Position<Element>? 
        {
            if  let position:Branch.Position<Element> = self.positions[id], 
                self.indices ~= position.offset
            {
                return position
            }
            else 
            {
                return nil
            }
        }
    }
}
