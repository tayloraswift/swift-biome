extension Symbol.Kind
{
    var orientation:URI.LexicalPath.Orientation 
    {
        switch self
        {
        case    .associatedtype, .typealias, .enum, .struct, .class, .actor, .protocol:
            return .straight
        case    .case, .initializer, .deinitializer, 
                .typeSubscript, .instanceSubscript, 
                .typeProperty, .instanceProperty, 
                .typeMethod, .instanceMethod, 
                .var, .func, .operator:
            return .gay
        }
    }
}
extension Symbol 
{
    var orientation:URI.LexicalPath.Orientation 
    {
        self.kind.orientation
    }
    struct Pairing:Hashable
    {
        private 
        let _witness:UInt32
        private 
        let _victim:UInt32
        
        var witness:Int 
        {
            .init(self._witness)
        }
        var victim:Int?
        {
            self._victim == .max ? nil : .init(self._victim)
        }
        
        init(_ index:Int) 
        {
            self._witness = .init(index)
            self._victim = .max
        }
        init(witness:Int, victim:Int)
        {
            self._witness = .init(witness)
            self._victim = .init(victim)
            precondition(self._victim != .max)
        }
    }
}
