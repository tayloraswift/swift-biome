struct Keyframe<Value>
{
    let value:Value
    var previous:Buffer.Index
    let appeared:Version
    var disappeared:Version
    
    init(_ value:Value, version:Version, previous:Buffer.Index)
    {
        self.value = value 
        self.previous = previous 
        self.appeared = version 
        self.disappeared = .max 
    }
}
extension Keyframe 
{
    @propertyWrapper 
    struct Head:Equatable
    {
        private 
        var bits:UInt32
        
        init()
        {
            self.bits = .max
        }
        var wrappedValue:Keyframe<Value>.Buffer.Index?
        {
            get 
            {
                self.bits != .max ? .init(bits: self.bits) : nil
            }
            set(value)
            {
                if let bits:UInt32 = value?.bits
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
}
