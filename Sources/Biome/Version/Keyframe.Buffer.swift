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
        
        func through(_ version:Version, head:Index?) -> Value?
        {
            self.at(version, head: head)?.value
        }
        func at(_ version:Version, head:Index?) -> (value:Value, extancy:Extancy)?
        {
            head.flatMap { self.at(version, head: $0) }
        }
        func find(_ version:Version, head:Index?) -> (index:Index, extancy:Extancy)?
        {
            head.flatMap { self.find(version, head: $0) }
        }
        
        private 
        func at(_ version:Version, head:Index) -> (value:Value, extancy:Extancy)?
        {
            self.find(version, head: head).map { (self[$0.index].value, $0.extancy) }
        }
        private 
        func find(_ version:Version, head:Index) -> (index:Index, extancy:Extancy)?
        {
            var current:Index = head
            while true 
            {
                let keyframe:Keyframe<Value> = self[current]
                guard version < keyframe.disappeared 
                else 
                {
                    return (current, .extinct(since: keyframe.disappeared))
                }
                guard version < keyframe.appeared
                else 
                {
                    return (current, .extant)
                }
                guard keyframe.previous < current
                else 
                {
                    // end of the line
                    return (current, .unavailable(until: keyframe.appeared))
                }
                current = keyframe.previous 
            }
        }
    }
}
extension Keyframe.Buffer where Value:Equatable 
{
    mutating 
    func push(_ version:Version, head:Index?)
    {
        if  let head:Index,
            self[head].disappeared > version
        {
            self[head].disappeared = version
        }
    }
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
            self[previous].disappeared = .max
        }
    }
}
