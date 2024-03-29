import Forest 

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