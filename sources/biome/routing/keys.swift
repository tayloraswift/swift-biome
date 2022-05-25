extension Route 
{
    struct Keys 
    {
        private 
        var counter:Stem
        private
        var table:[String: Stem]
        
        init() 
        {
            self.counter = .init()
            self.table = [:]
        }
        
        private static 
        func subpath<S>(_ component:S) -> String 
            where S:StringProtocol 
        {
            component.lowercased()
        }
        private static 
        func subpath<S>(_ components:S) -> String 
            where S:Sequence, S.Element:StringProtocol 
        {
            components.map { $0.lowercased() }.joined(separator: "\u{0}")
        }
        
        private 
        subscript(subpath:String) -> Stem? 
        {
            self.table[subpath]
        }
        
        subscript<S>(leaf component:S) -> Stem? 
            where S:StringProtocol 
        {
            self.table[Self.subpath(component)]
        }        
        subscript<Path>(stem components:Path) -> Stem? 
            where Path:Sequence, Path.Element:StringProtocol 
        {
            self.table[Self.subpath(components)]
        }
        
        private mutating 
        func register(_ string:String) -> Stem 
        {
            if let stem:Stem = self.table[string]
            {
                return stem 
            }
            else 
            {
                self.table[string] = self.counter.increment()
                return self.counter
            }
        }
        
        mutating 
        func register(complete symbol:Symbol) -> Stem 
        {
            symbol.nest.isEmpty ? symbol.route.leaf.stem : self.register(components: symbol.nest + [symbol.name])
        }
        mutating 
        func register<S>(components:S) -> Stem 
            where S:Sequence, S.Element:StringProtocol 
        {
            self.register(Self.subpath(components))
        }
        mutating 
        func register<S>(component:S) -> Stem 
            where S:StringProtocol 
        {
            self.register(Self.subpath(component))
        }
    }
}
