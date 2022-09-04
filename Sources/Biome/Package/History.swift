import Forest 

struct _History<Value> where Value:Equatable
{
    typealias Index = Forest<Keyframe>.Index 

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

    func rewind(_ head:Forest<Keyframe>.Tree.Head, to revision:_Version.Revision) -> Index?
    {
        self.forest[head].first { $0.since <= revision }
    }
    func value(rewinding head:Forest<Keyframe>.Tree.Head, to revision:_Version.Revision) -> Value?
    {
        self.rewind(head, to: revision).map { self.forest[$0].value.value }
    }
    /// Unconditionally pushes the given value to the head of the given tree.
    mutating 
    func push(_ value:__owned Value, revision:_Version.Revision, 
        to tree:inout Branch.Divergence<Value>?) 
    {
        if let divergence:Branch.Divergence<Value> = tree
        {
            tree = .init(head: self.forest.insert(.init(_move value, since: revision), 
                before: divergence.head), 
                start: divergence.start)
        }
        else 
        {
            tree = .init(head: self.forest.insert(.init(_move value, since: revision)), 
                start: revision)
        }
    }
    /// Pushes the given value to the head of the given tree if it is not equivalent 
    /// to the existing min-value.
    mutating 
    func add(_ value:__owned Value, revision:_Version.Revision, 
        to tree:inout Branch.Head<Value>?) 
    {
        guard let head:Branch.Head<Value> = tree
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
}

struct History<Value> where Value:Equatable
{
    typealias Index = Forest<Keyframe>.Index 

    struct Keyframe
    {
        var versions:ClosedRange<Version>
        let value:Value
        
        init(_ value:Value, version:Version)
        {
            self.value = value 
            self.versions = version ... version  
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

    mutating 
    func push(_ value:Value, version:Version, into tree:inout Branch.Head?) 
    {
        guard let head:Index = tree?.index  
        else 
        {
            tree = self.forest.insert(root: .init(value, version: version))
            return
        }
        let previous:Keyframe = self[head]
        if  previous.versions ~= version._predecessor, 
            previous.value == value 
        {
            self[head].versions = previous.versions.lowerBound ... version 
        }
        else
        {
            self.forest.push(min: .init(value, version: version), into: &tree)
        }
    }
}
extension History 
{
    subscript(branch:Branch.Head?) -> Branch 
    {
        .init(self.forest[branch])
    }

    struct Branch 
    {
        typealias Head = Forest<Keyframe>.Tree.Head

        @propertyWrapper
        struct Optional:Hashable, Sendable
        {
            private 
            var bits:UInt32
            
            init()
            {
                self.bits = .max
            }
            
            var wrappedValue:Head?
            {
                get 
                {
                    self.bits != .max ? .init(.init(bits: self.bits)) : nil
                }
                set(value)
                {
                    if let bits:UInt32 = value?.index.bits
                    {
                        precondition(bits != .max)
                        self.bits = bits 
                    }
                    else 
                    {
                        self.bits = .max
                    }
                }
            }
        }
        
        private 
        let tree:Forest<Keyframe>.Tree

        fileprivate 
        init(_ tree:Forest<Keyframe>.Tree)
        {
            self.tree = tree
        }

        func contains(_ version:Version) -> Bool 
        {
            if case _? = self.find(version) 
            {
                return true 
            }
            else 
            {
                return false 
            }
        }
        func at(_ version:Version) -> Value?
        {
            self.find(version).map { self.tree.forest[$0].value.value }
        }
        func find(_ version:Version) -> Index?
        {
            self.tree.find 
            {
                if      $0.versions.upperBound < version 
                {
                    return false 
                }
                else if $0.versions.lowerBound > version
                {
                    return true 
                }
                else 
                {
                    return nil 
                }
            }
        }
    }
}