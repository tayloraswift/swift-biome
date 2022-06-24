extension Route 
{
    struct Keys 
    {
        private 
        var counter:Stem
        private
        var table:[String: Stem]
        
        var _count:Int 
        {
            self.table.count 
        }
        var _memoryFootprint:Int 
        {
            let direct:Int = self.table.capacity * 
                MemoryLayout<Dictionary<String, Stem>.Element>.stride
            let indirect:Int = self.table.keys.reduce(0) { $0 + $1.utf8.count }
            return direct + indirect
        }
        
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

        
        private 
        subscript(leaf component:Symbol.Link.Component) -> Stem? 
        {
            if let hyphen:String.Index = component.hyphen 
            {
                return self[leaf: component.string[..<hyphen]]
            }
            else 
            {
                return self[leaf: component.string]
            }
        }

        subscript<Path>(namespace:Module.Index, infix:Path) -> Route? 
            where Path:BidirectionalCollection, Path.Element:StringProtocol 
        {
            if  let leaf:Path.Element = infix.last,
                let leaf:Stem = self[leaf: leaf],
                let stem:Stem = self[stem: infix.dropLast()]
            {
                return .init(namespace, stem, leaf, orientation: .straight)
            }
            else 
            {
                return nil
            }
        }
        subscript(namespace:Module.Index, infix:[String], suffix:Symbol.Link) -> Route? 
        {
            if  let leaf:Symbol.Link.Component = suffix.last,
                let leaf:Stem = self[leaf: leaf],
                let stem:Stem = self[stem: suffix.prefix(prepending: infix)]
            {
                return .init(namespace, stem, leaf, orientation: suffix.orientation)
            }
            else 
            {
                return nil
            }
        }
        subscript(namespace:Module.Index, suffix:Symbol.Link) -> Route? 
        {
            self[namespace, [], suffix]
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
