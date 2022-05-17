
struct Keyframe<Value>
{
    let value:Value
    let from:Version
    var to:Version
    var next:Int
}
extension Keyframe where Value:Equatable
{
    struct Buffer 
    {
        var storage:[Keyframe<Value>]
        
        init() 
        {
            self.storage = []
        }
        
        mutating 
        func update(head:inout Int?, with new:Value) 
        {
            fatalError("unimplemented")
        }
    }
}
