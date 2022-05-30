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
        
        private 
        subscript<Component>(leaf component:Component) -> Stem? 
            where Component:StringProtocol 
        {
            self.table[Self.subpath(component)]
        }        
        private 
        subscript<Path>(stem components:Path) -> Stem? 
            where Path:Sequence, Path.Element:StringProtocol 
        {
            self.table[Self.subpath(components)]
        }
        
        subscript<Prefix, Last>(
            namespace:Module.Index, 
            prefix:Prefix, 
            last:Last, orientation:Orientation) -> Route? 
            where Prefix:Sequence, Prefix.Element:StringProtocol, Last:StringProtocol
        {
            guard   let stem:Stem = self[stem: prefix],
                    let leaf:Stem = self[leaf: last]
            else 
            {
                return nil
            }
            return .init(namespace, stem, leaf, orientation: orientation)
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
            symbol.path.prefix.isEmpty ? 
                symbol.route.leaf.stem : self.register(components: symbol.path)
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
