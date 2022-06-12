extension Keyframe 
{
    struct Buffer 
    {
        struct Index:Hashable, Comparable, Sendable 
        {
            let bits:UInt32 
            
            var offset:Int
            {
                .init(self.bits)
            }
            
            static 
            func < (lhs:Self, rhs:Self) -> Bool 
            {
                lhs.bits < rhs.bits 
            }
            
            init(offset:Int)
            {
                self.init(bits: .init(offset))
            }
            init(bits:UInt32)
            {
                self.bits = bits
            }
        }
        
        private 
        var storage:[Keyframe<Value>]
        
        var startIndex:Index 
        {
            .init(offset: self.storage.startIndex)
        }
        var endIndex:Index 
        {
            .init(offset: self.storage.endIndex)
        }
        
        private(set)
        subscript(index:Index) -> Keyframe<Value>
        {
            _read 
            {
                yield  self.storage[index.offset]
            }
            _modify
            {
                yield &self.storage[index.offset]
            }
        }
        
        init() 
        {
            self.storage = []
        }
        
        func at(_ version:Version, head:Index?) -> Value?
        {
            guard let head:Index = head 
            else 
            {
                return nil
            }
            return self.at(version, head: head)
        }
        func find(_ version:Version, head:Index?) -> Index?
        {
            guard let head:Index = head 
            else 
            {
                return nil
            }
            return self.find(version, head: head)
        }
        
        private 
        func at(_ version:Version, head:Index) -> Value?
        {
            if let index:Index = self.find(version, head: head)
            {
                return self[index].value
            }
            else 
            {
                return nil
            }
        }
        private 
        func find(_ version:Version, head:Index) -> Index?
        {
            var current:Index = head
            while true 
            {
                let keyframe:Keyframe<Value> = self[current]
                guard version <= keyframe.last 
                else 
                {
                    return nil
                }
                guard version < keyframe.first
                else 
                {
                    return current
                }
                guard keyframe.previous < current
                else 
                {
                    // end of the line
                    return nil
                }
                current = keyframe.previous 
            }
        }
    }
}
extension Keyframe.Buffer where Value:Equatable 
{
    mutating 
    func update(head:inout Index?, to version:Version, with new:Value) 
    {
        guard let previous:Index = head 
        else 
        {
            let current:Index = self.endIndex
            self.storage.append(.init(new, version: version, previous: current))
            head = current 
            return
        }
        if  self[previous].value != new 
        {
            let current:Index = self.endIndex
            self.storage.append(.init(new, version: version, previous: previous))
            head = current 
        }
        else 
        {
            self[previous].last = .latest
        }
    }
}
