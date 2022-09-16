import Forest 

struct _History<Value> where Value:Equatable
{
    typealias Head = Forest<Keyframe>.Tree.Head 
    typealias Index = Forest<Keyframe>.Index 

    struct Divergent
    {
        var head:Head
        /// The first revision in which this field diverged from its parent branch.
        var start:_Version.Revision
    }
    struct Keyframe
    {
        var since:_Version.Revision
        let value:Value
        
        init(_ value:Value, since:_Version.Revision)
        {
            self.value = value 
            self.since = since
        }
    }

    private 
    var forest:Forest<Keyframe>

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

    init() 
    {
        self.forest = .init()
    }

    private 
    func rewind(_ head:Forest<Keyframe>.Tree.Head, to revision:_Version.Revision) -> Index?
    {
        self.forest[head].first { $0.since <= revision }
    }
    private 
    func value(rewinding head:Forest<Keyframe>.Tree.Head, to revision:_Version.Revision) -> Value?
    {
        self.rewind(head, to: revision).map { self.forest[$0].value.value }
    }
    
    func value<Key, Divergence>(of key:Key, 
        field:KeyPath<Divergence, Divergent?>,
        in trunk:some Sequence<Divergences<Key, Divergence>>)
        -> Value?
        where Key:Hashable
    {
        for divergences:Divergences<Key, Divergence> in trunk
        {
            if let head:Head = divergences[key, field]
            {
                if  let previous:Value = 
                    self.value(rewinding: head, to: divergences.limit)
                {
                    return previous
                }
                else 
                {
                    fatalError("unreachable: divergent containment check succeeded but revision was not found")
                }
            }
        }
        return nil
    }
    func value<Element>(of position:Branch.Position<Element>, 
        field:
        (
            contemporary:KeyPath<Element, Head?>,
            divergent:KeyPath<Element.Divergence, Divergent?>
        ),
        in trunk:some Sequence<Epoch<Element>>) 
        -> Value?
        where Element:BranchElement
    {
        for epoch:Epoch<Element> in trunk
        {
            if let contemporary:Element = epoch[position] 
            {
                // symbol is contemporary to this epoch.
                return contemporary[keyPath: field.contemporary].flatMap 
                {
                    self.value(rewinding: $0, to: epoch.limit)
                }
            } 
            if let head:Head = epoch.divergences[position, field.divergent]
            {
                if  let previous:Value = 
                    self.value(rewinding: head, to: epoch.limit)
                {
                    return previous
                }
                else 
                {
                    fatalError("unreachable: divergent containment check succeeded but revision was not found")
                }
            }
        }
        fatalError("unreachable: incomplete timeline!")
    }
}
extension _History 
{
    /// Unconditionally pushes the given value to the head of the given tree.
    mutating 
    func push(_ value:__owned Value, revision:_Version.Revision, to tree:inout Divergent?) 
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
    func add(_ value:__owned Value, revision:_Version.Revision, to tree:inout Head?) 
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
    func update<Key, Divergence>(_ divergences:inout [Key: Divergence], key:Key, 
        with value:__owned Value, 
        revision:_Version.Revision, 
        field:WritableKeyPath<Divergence, Divergent?>,
        trunk:some Sequence<Divergences<Key, Divergence>>)
        where Key:Hashable, Divergence:Voidable
    {
        if let previous:Value = divergences[key]?[keyPath: field]
                .map({ self[$0.head.index].value })
        {
            if previous == value
            {
                return 
            }
        }
        else if case value? = self.value(of: key, field: field, in: trunk)
        {
            return
        }

        self.push(_move value, revision: revision, 
           to: &divergences[key, default: .init()][keyPath: field])
    }
    mutating 
    func update<Element>(_ buffer:inout Branch.Buffer<Element>, 
        position:Branch.Position<Element>, 
        with value:__owned Value, 
        revision:_Version.Revision, 
        field:
        (
            contemporary:WritableKeyPath<Element, _History<Value>.Head?>,
            divergent:WritableKeyPath<Element.Divergence, _History<Value>.Divergent?>
        ),
        trunk:some Sequence<Epoch<Element>>)
        where Element:BranchElement, Element.Divergence:Voidable
    {
        guard position.offset < buffer.startIndex 
        else 
        {
            // symbol is contemporary to this branch. 
            self.add(_move value, revision: revision, 
                to: &buffer[contemporary: position][keyPath: field.contemporary])
            return 
        }
        if let previous:Value = (buffer.divergences[position]?[keyPath: field.divergent])
                .map({ self[$0.head.index].value })
        {
            if previous == value 
            {
                // symbol is not contemporary, but has already diverged in this 
                // epoch, and its divergent value matches.
                return 
            }
        }
        else if case value? = self.value(of: position, field: field, in: trunk)
        {
            // symbol is not contemporary, has not diverged in this epoch, 
            // but its value (divergent or not) matches.
            return 
        }
        self.push(_move value, revision: revision, 
            to: &buffer.divergences[position, default: .init()][keyPath: field.divergent])
    }
}