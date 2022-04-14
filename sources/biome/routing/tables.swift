extension URI 
{
    enum Base:Hashable, Sendable 
    {
        case reference 
        case learn 
    }
    private 
    enum Depth
    {
        case shallow 
        case deep
        case full
    }

    struct Table 
    {
        private 
        let bases:(reference:String, learn:String),
            roots:[Package.ID: Int]
        private
        var subpaths:Subpaths
        private
        var subtables:[Subtable]
        private 
        let pairings:[Symbol.Pairing: Depth]
        
        init(bases:[Base: String], biome:Biome) 
        {
            self.subpaths = .init()
            self.bases = 
            (
                reference:  bases[.reference, default: "reference"],
                learn:      bases[.learn,     default: "learn"]
            )
            self.roots = .init(uniqueKeysWithValues: zip(biome.packages.map(\.id), biome.packages.indices))
            
            var keys:[(pairing:Symbol.Pairing, key:Subtable.Key)] = []
            
            var subtable:Subtable = .init(trunks: 
                .init(uniqueKeysWithValues: zip(biome.modules.map(\.id), biome.modules.indices)))
            for (index, symbol):(Int, Symbol) in zip(biome.symbols.indices, biome.symbols)
            {
                // do not register mythical symbols 
                guard let namespace:Int = symbol.namespace
                else 
                {
                    continue 
                }
                
                let pairing:Symbol.Pairing = .init(index)
                let key:Subtable.Key = .init(module: namespace, 
                    stem: self.subpaths.register(symbol.scope),
                    leaf: self.subpaths.register(symbol.title))
                keys.append((pairing, key))
                subtable.insert(symbol.kind.orientation, pairing, forKey: key)
                
                for witness:Int in symbol.relationships.members ?? []
                {
                    guard let interface:Int = biome.symbols[witness].parent, interface != index 
                    else 
                    {
                        // not an inherited witness
                        continue 
                    }
                    
                    let pairing:Symbol.Pairing = .init(witness: witness, victim: index)
                    let witness:Symbol = biome.symbols[witness]
                    let key:Subtable.Key = .init(module: namespace, 
                        stem: self.subpaths.register(symbol.scope + CollectionOfOne<String>.init(symbol.title)),
                        leaf: self.subpaths.register(witness.title))
                    keys.append((pairing, key))
                    subtable.insert(witness.kind.orientation, pairing, forKey: key)
                }
            }
            
            self.pairings = .init(uniqueKeysWithValues: keys.map 
            {
                guard let depth:Depth = subtable.entries[$0.key]?.depth(
                    orientation: biome.symbols[$0.pairing.witness].orientation, 
                    witness:                   $0.pairing.witness)
                else 
                {
                    fatalError("unreachable")
                }
                return ($0.pairing, depth)
            })
            self.subtables = [subtable]
        }
        
        private
        func classify(lexical path:LexicalPath) -> SemanticPath?
        {
            //  '/base' '/swift' '' '/big'
            //  '/base' '/swift' '' '.little'
            //  '/base' '/swift' '/opaque/stem' '/big'
            //  '/base' '/swift' '/opaque/stem' '.little'
            
            //  '/base' 'swift-standard-library' '/swift' '/opaque/stem' '/big'
            let base:Base
            switch path.components.first
            {
            case .identifier(self.bases.reference,  hyphen: _)?: base = .reference
            case .identifier(self.bases.learn,      hyphen: _)?: base = .learn
            default: return nil 
            }
            
            var components:ArraySlice<LexicalPath.Component> = path.components.dropFirst()
            
            let package:Int
            switch components.first
            {
            case nil: 
                return nil 
            case .identifier(let string, hyphen: _)?:
                if let index:Int = self.roots[Package.ID.init(string)]
                {
                    package = index 
                    components.removeFirst()
                }
                else 
                {
                    fallthrough
                }
            case .version?:
                if let index:Int = self.roots[.swift]
                {
                    package = index 
                }
                else 
                {
                    return nil
                }
            }
            
            var semantic:SemanticPath = .init(base: base, package: package)
            
            if case .version(let explicit)? = components.first 
            {
                // semantic *path* version; version may be a toolchain version 
                // (which is not a semver.)
                semantic.version = explicit
                components.removeFirst()
            }
            
            let module:Module.ID
            switch components.popFirst()
            {
            case nil:
                return semantic 
            case .identifier(let string, hyphen: nil)?:
                module = .init(string)
            default: 
                return nil
            }
            
            // all remaining components must be identifier-components, and only 
            // the last component may contain a hyphen.
            switch components.popLast()
            {
            case nil:
                semantic.suffix = (module, nil)
            
            case .identifier(let last, hyphen: let hyphen)?:
                guard let leaf:UInt32 = self.subpaths[leaf: last.prefix(upTo: hyphen ?? last.endIndex)]
                else 
                {
                    return nil
                }
                
                let suffix:SemanticPath.Suffix?
                if  let hyphen:String.Index = hyphen 
                {
                    let string:String = .init(last[hyphen...].dropFirst())
                    if let kind:Symbol.Kind = .init(rawValue: string)
                    {
                        suffix = .kind(kind)
                    }
                    // https://github.com/apple/swift-docc/blob/d94139a5e64e9ecf158214b1cded2a2880fc1b02/Sources/SwiftDocC/Utility/FoundationExtensions/String%2BHashing.swift
                    else if let hash:UInt32 = .init(string, radix: 36)
                    {
                        suffix = .fnv(hash: hash)
                    }
                    else 
                    {
                        return nil
                    }
                }
                else 
                {
                    suffix = nil
                }
                
                var stem:[String] = []
                    stem.reserveCapacity(components.count)
                for component:LexicalPath.Component in components 
                {
                    guard case .identifier(let component, hyphen: nil) = component 
                    else 
                    {
                        return nil 
                    }
                    stem.append(component)
                }
                if let stem:UInt32 = self.subpaths[stem: stem]
                {
                    semantic.suffix = (module, (stem, leaf: leaf, suffix))
                }
                else 
                {
                    return nil
                }
                
            case .version(_)?:
                return nil
            }
            return semantic 
        }
    }
    private 
    struct Subtable 
    {
        // this is three words long, but that’s probably okay because they 
        // live in small dictionaries 
        struct Victims 
        {
            var first:Int?
            var overflow:[Int]
            
            init(_ first:Int? = nil)
            {
                self.first = first
                self.overflow = []
            }
            
            mutating 
            func insert(_ next:Int?)
            {
                guard let victim:Int = next
                else 
                {
                    return 
                }
                if case nil = self.first 
                {
                    self.first = victim
                }
                else 
                {
                    self.overflow.append(victim)
                }
            }
        }

        // 16B stride
        struct Key:Hashable 
        {
            let module:Int 
            let stem:UInt32 
            let leaf:UInt32 
        }
        // 24B stride
        enum Entry 
        {
            // `Resource` is about five words long. to avoid blowing up the 
            // table, store it as an index. 
            // TODO: re-implement `Resource` as a `ManagedBuffer`
            case opaque           (Int)
            case big              (Symbol.Pairing)
            case bigDeep          ([Int: Victims])
            case bigDeepDoubled   ([Int: Victims],   Symbol.Pairing)
            case doubled          (Symbol.Pairing,   Symbol.Pairing)
            case deep             ([Int: Victims],   [Int: Victims])
            case littleDeepDoubled(Symbol.Pairing,   [Int: Victims])
            case littleDeep                         ([Int: Victims])
            case little                             (Symbol.Pairing)
            
            func depth(orientation:LexicalPath.Orientation, witness:Int) -> Depth 
            {
                switch  (self, orientation) 
                {
                case    (.opaque, _), 
                        (.big,                          .straight), 
                        (.littleDeepDoubled,            .straight), 
                        (.doubled, _),
                        (.bigDeepDoubled,               .gay), 
                        (.little,                       .gay):
                    return .shallow
                case    (   .bigDeep(let overloads),    .straight),
                        (      .deep(let overloads, _), .straight),
                        (      .deep(_, let overloads), .gay),
                        (.littleDeep(   let overloads), .gay):
                    switch overloads[witness]?.overflow.isEmpty
                    {
                    case nil:
                        fallthrough
                    case true?: 
                        return .deep 
                    case false?:
                        // should be *extremely* rare
                        return .full 
                    }
                default: 
                    fatalError("unreachable")
                }
            }
            
            mutating 
            func merge(_ value:Self) 
            {
                func overlay(_ next:Symbol.Pairing, into stack:inout [Int: Victims])
                {
                    stack[next.witness, default: .init()].insert(next.victim)
                }
                func overlay(_ first:Symbol.Pairing, _ next:Symbol.Pairing) -> [Int: Victims]
                {
                    var stack:[Int: Victims] = [first.witness: .init(first.victim)]
                    overlay(next, into: &stack)
                    return stack
                }
                
                switch value 
                {
                case (.big(let next)):
                    switch self 
                    {
                    case .little                              (let little):
                        self =                     .doubled(next,  little)
                    case .littleDeep                          (let little):
                        self =           .littleDeepDoubled(next,  little)
                    case .littleDeepDoubled       (let big,    let little):
                        self =           .deep(overlay(big, next), little)
                    case .doubled                 (let big,    let little):
                        self = .bigDeepDoubled(overlay(big, next), little)
                    
                    case .big                     (let big):
                        self =        .bigDeep(overlay(big, next))
                    
                    case .deep                    (var stack,  let little):
                        self = .opaque(0)
                        overlay(next,           into: &stack)
                        self =                   .deep(stack,      little)
                    case .bigDeepDoubled          (var stack,  let little):
                        self = .opaque(0)
                        overlay(next,           into: &stack)
                        self =         .bigDeepDoubled(stack,      little)
                    case .bigDeep                 (var stack):
                        self = .opaque(0)
                        overlay(next,           into: &stack)
                        self =             .littleDeep(stack)
                    
                    case .opaque(_):
                        break
                    }
                case (.little(let next)):
                    switch self 
                    {
                    case .big                   (let big):
                        self =              .doubled(big,                 next)
                    case .bigDeep               (let big):
                        self =       .bigDeepDoubled(big,                 next)
                    case .bigDeepDoubled        (let big,     let little):
                        self =                 .deep(big, overlay(little, next))
                    case .doubled               (let big,     let little):
                        self =    .littleDeepDoubled(big, overlay(little, next))
                    
                    case .little                             (let little):
                        self =                .littleDeep(overlay(little, next))
                    
                    case .deep                  (let big,     var stack):
                        self = .opaque(0)
                        overlay(next,                      into: &stack)
                        self =                 .deep(big,         stack)
                    case .littleDeepDoubled     (let big,     var stack):
                        self = .opaque(0)
                        overlay(next,                      into: &stack)
                        self =    .littleDeepDoubled(big,         stack)
                    case .littleDeep                         (var stack):
                        self = .opaque(0)
                        overlay(next,                      into: &stack)
                        self =                        .littleDeep(stack)

                    case .opaque(_):
                        break
                    }
                default: 
                    fatalError("unsupported operation")
                }
            }
        }

        private(set)
        var entries:[Key: Entry]
        private 
        let trunks:[Module.ID: Int]
        
        init(trunks:[Module.ID: Int])
        {
            self.trunks = trunks 
            self.entries = [:]
        }
        
        mutating 
        func insert(_ orientation:LexicalPath.Orientation, _ pairing:Symbol.Pairing, forKey key:Key)
        {
            switch orientation 
            {
            case .straight: self.insert(.big(pairing), forKey: key)
            case .gay:   self.insert(.little(pairing), forKey: key)
            }
        }
        private mutating 
        func insert(_ entry:Entry, forKey key:Key)
        {
            if let index:Dictionary<Key, Entry>.Index = self.entries.index(forKey: key)
            {
                self.entries.values[index].merge(entry)
            }
            else 
            {
                self.entries.updateValue(entry, forKey: key)
            }
        }
    }
    private 
    struct SemanticPath 
    {
        let base:Base 
        var package:Int
        // *not* guaranteed to be valid!
        var version:Package.Version?
        var suffix:
        (
            module:Module.ID,
            key:
            (
                stem:UInt32,
                leaf:UInt32, 
                suffix:Suffix?
            )?
        )?
        
        enum Suffix 
        {
            case kind(Symbol.Kind)
            case fnv(hash:UInt32)
        }
        
        init(base:Base, package:Int)
        {
            self.base = base 
            self.package = package 
            self.version = nil 
            self.suffix = nil
        }
    }
}
extension URI.Table 
{
    private 
    struct Subpaths 
    {
        private
        var table:[String: UInt32]
        
        init() 
        {
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
        subscript(subpath:String) -> UInt32? 
        {
            self.table[subpath]
        }
        private mutating 
        func register(_ string:String) -> UInt32 
        {
            var counter:UInt32 = .init(self.table.count)
            self.table.merge(CollectionOfOne<(String, UInt32)>.init((string, counter))) 
            { 
                (current:UInt32, _:UInt32) in 
                counter = current 
                return current 
            }
            return counter
        }
        
        subscript<S>(leaf component:S) -> UInt32? 
            where S:StringProtocol 
        {
            self.table[Self.subpath(component)]
        }
        subscript<S>(stem components:S) -> UInt32? 
            where S:Sequence, S.Element:StringProtocol 
        {
            self.table[Self.subpath(components)]
        }
        
        mutating 
        func register<S>(_ component:S) -> UInt32
            where S:StringProtocol 
        {
            self.register(Self.subpath(component))
        }
        mutating 
        func register<S>(_ components:S) -> UInt32
            where S:Sequence, S.Element:StringProtocol 
        {
            self.register(Self.subpath(components))
        }
    }
}
