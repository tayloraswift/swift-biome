extension Symbol 
{
    @propertyWrapper 
    struct Head<Value>:Equatable
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
    struct Heads 
    {
        @Head<Declaration>
        var declaration:Keyframe<Declaration>.Buffer.Index?
        @Head<Relationships>
        var relationships:Keyframe<Relationships>.Buffer.Index?
        
        init() 
        {
            self._declaration = .init()
            self._relationships = .init()
        }
    }
}
