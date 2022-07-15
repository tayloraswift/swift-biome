extension Generic.Conditional:Equatable where Target:Equatable {}
extension Generic.Conditional:Hashable where Target:Hashable {}
extension Generic.Conditional:Sendable where Target:Sendable {}
extension Generic 
{
    struct Conditional<Target>
    {
        // not a ``Set``, because of 
        // https://github.com/apple/swift/blob/main/docs/ABI/GenericSignature.md
        let conditions:[Constraint<Target>]
        let target:Target 
        
        @available(*, deprecated, renamed: "target")
        var index:Target 
        {
            self.target 
        }
        
        init(_ target:Target, where constraints:[Constraint<Target>] = [])
        {
            self.target = target 
            self.conditions = constraints
        }
        
        func map<T>(_ transform:(Target) throws -> T) rethrows -> Conditional<T>
        {
            .init(try transform(self.target), 
                where: try self.conditions.map { try $0.map(transform) })
        }
    }
}
