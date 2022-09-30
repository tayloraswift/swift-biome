extension Route 
{
    struct Stems 
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
        func subpath(_ component:some StringProtocol) -> String 
        {
            component.lowercased()
        }
        private static 
        func subpath<Component>(_ components:some Sequence<Component>) -> String 
            where Component:StringProtocol 
        {
            components.map { $0.lowercased() }.joined(separator: "\u{0}")
        }
        
        private 
        subscript(subpath:String) -> Stem? 
        {
            self.table[subpath]
        }
        
        // https://github.com/apple/swift/issues/61387
        subscript<Component>(leaf component:Component) -> Stem? 
            where Component:StringProtocol
        {
            self.table[Self.subpath(component)]
        }
        private 
        subscript<Component>(stem components:some Sequence<Component>) -> Stem? 
            where Component:StringProtocol
        {
            self.table[Self.subpath(components)]
        }

        private 
        subscript(leaf component:_SymbolLink.Component) -> Stem? 
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

        subscript<Component>(namespace:Module.Index, 
            straight infix:some BidirectionalCollection<Component>) -> Route? 
            where Component:StringProtocol
        {
            if  let leaf:Component = infix.last,
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
        subscript<Component>(namespace:Module.Index, 
            infix:some BidirectionalCollection<Component>, 
            suffix:_SymbolLink) -> Route? 
            where Component:StringProtocol
        {
            guard let leaf:Stem = self[leaf: suffix.path.last]
            else 
            {
                return nil 
            }
            let slice:_SymbolLink.SubSequence = suffix.dropLast()
            let stem:Stem? 
            if  slice.isEmpty
            {
                stem = self[stem: infix]
            }
            else if infix.isEmpty
            {
                stem = self[stem: slice]
            }
            else 
            {
                stem = self[stem: infix.map(String.init(_:)) + slice]
            }
            return stem.map 
            {
                .init(namespace, $0, leaf, orientation: suffix.path.orientation)
            }
        }
        subscript(namespace:Module.Index, suffix:_SymbolLink) -> Route? 
        {
            self[namespace, EmptyCollection<String>.init(), suffix]
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
        func register<Component>(components:some Sequence<Component>) -> Stem 
            where Component:StringProtocol 
        {
            self.register(Self.subpath(components))
        }
        mutating 
        func register(component:some StringProtocol) -> Stem 
        {
            self.register(Self.subpath(component))
        }
    }
}