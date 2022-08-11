extension Documentation:Sendable where Comment:Sendable, Target:Sendable {}
extension Documentation:Equatable where Comment:Equatable, Target:Equatable {}

@frozen public 
enum Documentation<Comment, Target>
{
    case inherits(Target)
    case extends(Target?, with:Comment)

    func forEach(_ body:(Target) throws -> ()) rethrows 
    {
        switch self 
        {
        case .inherits(let origin), .extends(let origin?, with: _): 
            try body(origin)
        case .extends(nil, with: _): 
            break 
        }
    }
    @inlinable public
    func map<T>(_ transform:(Target) throws -> T) rethrows -> Documentation<Comment, T>
    {
        switch self  
        {
        case .inherits(let origin): 
            return .inherits(try transform(origin))
        case .extends(let origin, with: let comment):
            return .extends(try origin.map(transform), with: comment)
        }
    }
    @inlinable public
    func flatMap<T>(_ transform:(Target) throws -> T?) rethrows -> Documentation<Comment, T>?
    {
        switch self
        {
        case .inherits(let origin): 
            return try transform(origin).map(Documentation<Comment, T>.inherits(_:))
        case .extends(let origin, with: let comment):
            return .extends(try origin.flatMap(transform), with: comment)
        }
    }
}
extension Documentation where Comment == String 
{
    init?(_ comment:String?, from origin:Target?)
    {
        switch (comment, origin)
        {
        case (nil, nil): 
            return nil 
        case (nil, let origin?):
            self = .inherits(origin)
        case (let comment?, let origin?):
            self = comment.isEmpty ? .inherits(origin) : .extends(origin, with: comment)
        case (let comment?, nil):
            if comment.isEmpty 
            {
                return nil 
            }
            self = .extends(nil, with: comment)
        }
    }
}