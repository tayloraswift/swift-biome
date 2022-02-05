protocol CodeBuilder 
{
    associatedtype Token 
    
    init(tokens:[Token])
    var tokens:[Token] 
    {
        get
    }
}
extension CodeBuilder 
{
    static 
    var empty:Self 
    {
        .init(tokens: [])
    }
    var isEmpty:Bool
    {
        self.tokens.isEmpty
    }
    func map(_ transform:(Token) throws -> Token) rethrows -> Self
    {
        .init(tokens: try self.tokens.map(transform))
    }
    static 
    func buildOptional(_ element:Self?) -> Self 
    {
        element ?? .empty
    }
    static 
    func buildEither(first element:Self) -> Self 
    {
        element 
    }
    static 
    func buildEither(second element:Self) -> Self 
    {
        element 
    }
    static 
    func buildArray(_ elements:[Self]) -> Self 
    {
        .init(tokens: elements.flatMap(\.tokens))
    }
    static 
    func buildBlock(_ elements:Self...) -> Self 
    {
        .init(tokens: elements.flatMap(\.tokens))
    }
}
