import Forest 

extension History 
{
    /// A descriptor for a field of a symbol that was founded in a different 
    /// branch than the branch the descriptor lives in, whose value has diverged 
    /// from the value it held when the descriptor’s branch was forked from 
    /// its trunk.
    struct Divergent
    {
        var head:Head
        /// The first revision in which this field diverged from its parent branch.
        var start:Version.Revision
    }
    struct Keyframe
    {
        var since:Version.Revision
        let value:Value
        
        init(_ value:Value, since:Version.Revision)
        {
            self.value = value 
            self.since = since
        }
    }

    typealias Head = Forest<Keyframe>.Tree.Head 
    typealias Index = Forest<Keyframe>.Index 
    typealias Iterator = Forest<Keyframe>.Tree.Iterator 
}

struct History<Value> where Value:Equatable
{
    private 
    var forest:Forest<Keyframe>

    init() 
    {
        self.forest = .init()
    }

    subscript(head:Head?) -> Forest<Keyframe>.Tree
    {
        self.forest[head]
    }

    private(set)
    subscript(index:Index) -> Keyframe
    {
        _read 
        {
            yield  self.forest[index].value
        }
        _modify
        {
            yield &self.forest[index].value
        }
    }
}
extension History 
{
    private 
    func rewind(_ head:Head, to revision:Version.Revision) -> Index?
    {
        self.forest[head].first { $0.since <= revision }
    }
    private 
    func index(before index:Index) -> Index? 
    {
        // the front of the tree is the end of the historical timeline. 
        // so to get the precedessor of a historical index, we must 
        // get the successor of the forest index.
        self.forest.successor(of: index)
    }
}
extension History 
{
    struct DensePeriods<Trunk, Element>:Sequence, IteratorProtocol 
        where Trunk:Sequence<Epoch<Element>>
    {
        private 
        let history:History<Value>, 
            field:DenseField<Element>
        private 
        var trunk:Trunk.Iterator? 
        
        init(history:History<Value>, field:DenseField<Element>, trunk:__shared Trunk)
        {
            self.history = history
            self.field = field
            self.trunk = trunk.makeIterator()
        }

        mutating 
        func next() -> (Epoch<Element>, Index?)?
        {
            guard let epoch:Epoch<Element> = self.trunk?.next() 
            else 
            {
                return nil 
            }
            if let element:Element = epoch[self.field.element] 
            {
                // we know no prior epochs could possibly contain any information 
                // about this symbol, so we can stop iterating after this.
                self.trunk = nil 

                if  let future:Head = element[keyPath: self.field.contemporary],
                    let index:Index = self.history.rewind(future, to: epoch.limit)
                {
                    return (epoch, index) 
                }
            }
            else if let head:Head = epoch.divergences[self.field]
            {
                if  let index:Index = self.history.rewind(head, to: epoch.limit)
                {
                    return (epoch, index)
                }
                else 
                {
                    fatalError("unreachable: divergent containment check succeeded but revision was not found")
                }
            }
            return (epoch, nil)
        }
    }
    struct SparsePeriods<Trunk, Key, Divergence>:Sequence, IteratorProtocol 
        where Trunk:Sequence<Divergences<Key, Divergence>>
    {
        private 
        let history:History<Value>, 
            field:SparseField<Key, Divergence>
        private 
        var trunk:Trunk.Iterator 
        
        init(history:History<Value>, field:SparseField<Key, Divergence>, trunk:__shared Trunk)
        {
            self.history = history
            self.field = field
            self.trunk = trunk.makeIterator()
        }

        mutating 
        func next() -> (Divergences<Key, Divergence>, Index?)?
        {
            guard let divergences:Divergences<Key, Divergence> = self.trunk.next() 
            else 
            {
                return nil 
            }
            guard let head:Head = divergences[self.field] 
            else 
            {
                return (divergences, nil)
            }
            if let index:Index = self.history.rewind(head, to: divergences.limit)
            {
                return (divergences, index)
            }
            else 
            {
                fatalError("unreachable: divergent containment check succeeded but revision was not found")
            }
        }
    }
}
extension History 
{
    private 
    func backwards<Trunk, Element>(over field:DenseField<Element>, 
        in trunk:__owned Trunk) -> DensePeriods<Trunk, Element>
    {
        .init(history: self, field: field, trunk: trunk)
    }
    private 
    func backwards<Trunk, Key, Divergence>(over field:SparseField<Key, Divergence>, 
        in trunk:__owned Trunk) -> SparsePeriods<Trunk, Key, Divergence>
    {
        .init(history: self, field: field, trunk: trunk)
    }
}
extension History 
{
    /// Returns the latest version of the specified field for which the 
    /// given predicate was true, when scanning backwards through time, 
    /// if one exists.
    /// 
    /// If a keyframe spans multiple versions, the latest version among 
    /// them is returned.
    func latestVersion<Element>(of field:DenseField<Element>,
        in trunk:some Sequence<Epoch<Element>>, 
        where predicate:(Value) throws -> Bool) rethrows -> Version?
    {
        try self.latestVersion(in: self.backwards(over: field, in: trunk), where: predicate)
    }
    /// Returns the latest version of the specified field for which the 
    /// given predicate was true, when scanning backwards through time, 
    /// if one exists.
    /// 
    /// If a keyframe spans multiple versions, the latest version among 
    /// them is returned.
    func latestVersion<Key, Divergence>(of field:SparseField<Key, Divergence>,
        in trunk:some Sequence<Divergences<Key, Divergence>>, 
        where predicate:(Value) throws -> Bool) rethrows -> Version?
    {
        try self.latestVersion(in: self.backwards(over: field, in: trunk), where: predicate)
    }
    private 
    func latestVersion<Period>(in timeline:some Sequence<(Period, Index?)>,
        where predicate:(Value) throws -> Bool) rethrows -> Version?
        where Period:TrunkPeriod
    {
        var candidate:Version? = nil
        for (period, previous):(Period, Index?) in timeline 
        {
            if case nil = candidate 
            {
                candidate = period.latest
            }

            var previous:Index? = previous 
            while let current:Index = previous  
            {
                let keyframe:Keyframe = self[current]
                if try predicate(keyframe.value) 
                {
                    return candidate 
                }
                else if let version:Version = period.version(before: keyframe.since)
                {
                    candidate = version
                }
                previous = self.index(before: current)
            }
        }
        return nil 
    }
}
extension History
{
    func value<Key, Divergence>(of field:SparseField<Key, Divergence>,
        in trunk:some Sequence<Divergences<Key, Divergence>>) -> Value?
        where Key:Hashable
    {
        for (_, index):(_, Index?) in self.backwards(over: field, in: trunk) 
        {
            if let index:Index 
            {
                return self[index].value
            }
        }
        return nil 
    }
    func value<Element>(of field:DenseField<Element>,
        in trunk:some Sequence<Epoch<Element>>) -> Value?
        where Element:BranchElement
    {
        for (_, index):(_, Index?) in self.backwards(over: field, in: trunk) 
        {
            if let index:Index 
            {
                return self[index].value
            }
        }
        return nil 
    }
}
extension History 
{
    /// Unconditionally pushes the given value to the head of the given tree.
    mutating 
    func push(_ value:__owned Value, revision:Version.Revision, to tree:inout Divergent?) 
    {
        if let divergent:Divergent = tree
        {
            tree = .init(head: self.forest.insert(.init(_move value, since: revision), 
                before: divergent.head), 
                start: divergent.start)
        }
        else 
        {
            tree = .init(head: self.forest.insert(.init(_move value, since: revision)), 
                start: revision)
        }
    }
    /// Pushes the given value to the head of the given tree if it is not equivalent 
    /// to the existing min-value.
    private mutating 
    func add(_ value:__owned Value, revision:Version.Revision, to tree:inout Head?) 
    {
        guard let head:Head = tree
        else 
        {
            tree = self.forest.insert(.init(_move value, since: revision))
            return
        }
        if  self[head.index].value != value 
        {
            tree = self.forest.insert(.init(_move value, since: revision), before: head)
        }
    }
    
    mutating 
    func update<Key, Divergence>(_ divergences:inout [Key: Divergence], 
        at field:SparseField<Key, Divergence>, 
        revision:Version.Revision, 
        value:__owned Value, 
        trunk:some Sequence<Divergences<Key, Divergence>>)
        where Key:Hashable, Divergence:Voidable
    {
        if let previous:Value = divergences[field].map({ self[$0.head.index].value })
        {
            if previous == value
            {
                return 
            }
        }
        else if case value? = self.value(of: field, in: trunk)
        {
            return
        }

        self.push(_move value, revision: revision, 
           to: &divergences[field.key, default: .init()][keyPath: field.divergent])
    }
    mutating 
    func update<Element>(_ buffer:inout Branch.Buffer<Element>, 
        at field:DenseField<Element>,
        revision:Version.Revision, 
        value:__owned Value, 
        trunk:some Sequence<Epoch<Element>>)
        where Element:BranchElement, Element.Divergence:Voidable
    {
        guard field.element.offset < buffer.startIndex 
        else 
        {
            // symbol is contemporary to this branch. 
            self.add(_move value, revision: revision, 
                to: &buffer[contemporary: field.element][keyPath: field.contemporary])
            return 
        }
        if let previous:Value = buffer.divergences[field].map({ self[$0.head.index].value })
        {
            if previous == value 
            {
                // symbol is not contemporary, but has already diverged in this 
                // epoch, and its divergent value matches.
                return 
            }
        }
        else if case value? = self.value(of: field, in: trunk)
        {
            // symbol is not contemporary, has not diverged in this epoch, 
            // but its value (divergent or not) matches.
            return 
        }
        self.push(_move value, revision: revision, 
            to: &buffer.divergences[field.element, default: .init()][keyPath: field.divergent])
    }
}