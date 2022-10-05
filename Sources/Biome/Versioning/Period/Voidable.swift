protocol Voidable 
{
    init()
    
    var isEmpty:Bool
    {
        get
    }
}

extension Optional where Wrapped:Voidable
{
    subscript<Value>(keyPath path:WritableKeyPath<Wrapped, Value?>) -> Value?
    {
        _read
        {
            // slightly more efficient than the `_modify`, since we do not construct any 
            // instances of `Wrapped` if `nil`
            yield self?[keyPath: path]
        }
        _modify
        {
            var wrapped:Wrapped = self ?? .init()
            yield &wrapped[keyPath: path]
            self = wrapped.isEmpty ? nil : wrapped
        }
    }
}