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
    static 
    func extends(_ origin:Target?, with comment:String?) -> Self?
    {
        switch (origin, comment)
        {
        case (nil, nil): 
            return nil 
        case (let origin?, nil):
            return .inherits(origin)
        case (let origin?, let comment?):
            return comment.isEmpty ? .inherits(origin) : .extends(origin, with: comment)
        case (nil, let comment?):
            return comment.isEmpty ? nil : .extends(nil, with: comment)
        }
    }
}