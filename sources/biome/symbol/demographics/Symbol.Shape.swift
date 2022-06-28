extension Symbol 
{
    // should have stride of 16 B, as well as `Shape?` and `Shape??`
    enum Shape:Sendable, Hashable, CustomStringConvertible
    {
        case member(of:Index)
        case requirement(of:Index)
        
        var index:Index 
        {
            switch self 
            {
            case .member(let index), .requirement(let index): 
                return index
            }
        }
        var description:String 
        {
            switch self 
            {
            case .member:       return "member"
            case .requirement:  return "requirement"
            }
        }
    }
}
