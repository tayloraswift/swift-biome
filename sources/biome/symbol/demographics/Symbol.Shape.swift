extension Symbol.Shape:Equatable where Target:Equatable {}
extension Symbol.Shape:Hashable where Target:Hashable {}
extension Symbol.Shape:Sendable where Target:Sendable {}
extension Symbol 
{
    // should have stride of 16 B, as well as `Shape?` and `Shape??`
    enum Shape<Target>
    {
        case member(of:Target)
        case requirement(of:Target)
        
        var role:Role<Target>
        {
            switch self 
            {
            case .member(of: let target):       return .member(of: target)
            case .requirement(of: let target):  return .requirement(of: target)
            }
        }
        var target:Target 
        {
            switch self 
            {
            case .member(let index), .requirement(let index): 
                return index
            }
        }
        
        func map<T>(_ transform:(Target) throws -> T) rethrows -> Shape<T>
        {
            switch self 
            {
            case .member(of: let target): 
                return .member(of: try transform(target))
            case .requirement(of: let target): 
                return .requirement(of: try transform(target))
            }
        }
    }
}
