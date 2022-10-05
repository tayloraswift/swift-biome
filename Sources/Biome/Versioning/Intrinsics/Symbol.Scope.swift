extension Symbol 
{
    // should have stride of 16 B, as well as `Scope?` and `Scope??`
    enum Scope:Sendable
    {
        case member(of:Atom<Symbol>.Position)
        case requirement(of:Atom<Symbol>.Position)
        
        var role:Role<Atom<Symbol>.Position>
        {
            switch self 
            {
            case .member(of: let target):       return .member(of: target)
            case .requirement(of: let target):  return .requirement(of: target)
            }
        }
        var target:Atom<Symbol>.Position 
        {
            switch self 
            {
            case .member(let target), .requirement(let target): 
                return target
            }
        }
    }
}
