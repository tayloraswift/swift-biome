
struct Keyframe<Value>
{
    let value:Value
    var next:Buffer.Index
    let first:Version
    var last:Version
    
    init(_ value:Value, version:Version, position:Buffer.Index)
    {
        self.value = value 
        self.next = position
        self.first = version 
        self.last = version 
    }
}
extension Keyframe 
{
    struct Buffer 
    {
        struct Index:Hashable 
        {
            let bits:UInt32 
            
            var offset:Int
            {
                .init(self.bits)
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
    }
}
extension Keyframe.Buffer where Value:Equatable 
{
    mutating 
    func update(head:inout Index?, to version:Version, with new:Value) 
    {
        if let old:Index = head 
        {
            if  self[old].value == new 
            {
                self[old].last = version
                return 
            }
            else
            {
                self[old].next = self.endIndex
            }
        }
        let keyframe:Keyframe<Value> = .init(new, version: version, 
            position: self.endIndex)
        self.storage.append(keyframe)
        head = keyframe.next
    }
}
