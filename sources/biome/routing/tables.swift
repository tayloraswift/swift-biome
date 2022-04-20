extension URI 
{
    enum Base:Hashable, Sendable 
    {
        case package
        case module
        case symbol 
        case article
    }
    private 
    enum Depth
    {
        case shallow 
        case deep
        case full
    }
    

    private 
    struct LocalPath
    {
        enum Suffix 
        {
            case kind(Symbol.Kind)
            case fnv(hash:UInt32)
        }
        
        let stem:UInt32, 
            leaf:UInt32, 
            suffix:Suffix?
    }
    private 
    enum NationalPath
    {
        case article(Int, UInt32)
        case symbol (Int, LocalPath?)
        case module (Int, UInt32)
        case package     (UInt32)
    }
    private 
    struct GlobalPath 
    {
        // guaranteed to be valid
        let package:Int
        // *not* guaranteed to be valid!
        let version:Package.Version?
        let national:NationalPath? 
    }
    /* private 
    struct GlobalContext
    {
        let dependencies:[Int: NationalContext]
    }
    private 
    struct NationalContext 
    {
        let imports:[Int: LocalContext?]
    } */
    
    struct Table 
    {
        private 
        let bases:(package:String, module:String, symbol:String, article:String),
            roots:[Package.ID: Int]
        private
        var paths:PathTable
        private
        var trees:[Tree]
        private 
        let pairings:[Symbol.Pairing: Depth]
        
        init(bases:[Base: String], biome:Biome) 
        {
            self.paths = .init()
            self.bases = 
            (
                package: bases[.package, default: "packages"],
                module:  bases[.module,  default: "modules"],
                symbol:  bases[.symbol,  default: "reference"],
                article: bases[.article, default: "learn"]
            )
            self.roots = .init(uniqueKeysWithValues: zip(biome.packages.map(\.id), biome.packages.indices))
            
            var keys:[(pairing:Symbol.Pairing, key:SymbolTable.Key)] = []
            
            var symbols:SymbolTable = .init()
            for (index, symbol):(Int, Symbol) in zip(biome.symbols.indices, biome.symbols)
            {
                // do not register mythical symbols 
                guard let namespace:Int = symbol.namespace
                else 
                {
                    continue 
                }
                
                let pairing:Symbol.Pairing = .init(index)
                let key:SymbolTable.Key = .init(module: namespace, 
                    stem: self.paths.register(stem: symbol.scope),
                    leaf: self.paths.register(leaf: symbol.title))
                keys.append((pairing, key))
                symbols.insert(symbol.kind.orientation, pairing, into: key)
                
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
                    let key:SymbolTable.Key = .init(module: namespace, 
                        stem: self.paths.register(stem: symbol.scope + CollectionOfOne<String>.init(symbol.title)),
                        leaf: self.paths.register(leaf: witness.title))
                    keys.append((pairing, key))
                    symbols.insert(witness.kind.orientation, pairing, into: key)
                }
            }
            
            self.pairings = .init(uniqueKeysWithValues: keys.map 
            {
                guard let depth:Depth = symbols[$0.key]?.depth(
                    orientation: biome.symbols[$0.pairing.witness].orientation, 
                    witness:                   $0.pairing.witness)
                else 
                {
                    fatalError("unreachable")
                }
                return ($0.pairing, depth)
            })
            let trunks:[Module.ID: Int] = .init(uniqueKeysWithValues: zip(biome.modules.map(\.id), biome.modules.indices))
            let tree:Tree = .init(trunks: _move(trunks), symbols: symbols)
            self.trees = [tree]
        }
        
        private
        func classify(absolute path:LexicalPath) -> GlobalPath?
        {
            //  '/base' '/swift' '' '/big'
            //  '/base' '/swift' '' '.little'
            //  '/base' '/swift' '/opaque/stem' '/big'
            //  '/base' '/swift' '/opaque/stem' '.little'
            
            //  '/base' 'swift-standard-library' '/swift' '/opaque/stem' '/big'
            let base:Base
            switch path.components.first
            {
            case .identifier(self.bases.symbol,  hyphen: _)?: base = .symbol
            case .identifier(self.bases.article, hyphen: _)?: base = .article
            case .identifier(self.bases.package, hyphen: _)?: base = .package
            case .identifier(self.bases.module,  hyphen: _)?: base = .module
            default: return nil 
            }
            return self.classify(base: base, global: path.components.dropFirst())
        }
        private
        func classify<Path>(base:Base, global path:Path) -> GlobalPath?
            where   Path:Collection, Path.Element == LexicalPath.Component,
                    Path.SubSequence:BidirectionalCollection
        {
            var components:Path.SubSequence
            let package:(index:Int, explicit:Bool)
            switch path.first
            {
            case nil: 
                return nil 
            case .identifier(let string, hyphen: _)?:
                if let index:Int = self.roots[Package.ID.init(string)]
                {
                    package = (index, true)
                    components = path.dropFirst()
                }
                else 
                {
                    fallthrough
                }
            case .version?:
                if let index:Int = self.roots[.swift]
                {
                    package = (index, false)
                    components = path[...]
                }
                else 
                {
                    return nil
                }
            }
            
            let version:Package.Version?
            if case .version(let explicit)? = components.first 
            {
                // semantic *path* version; version may be a toolchain version 
                // (which is not a semver.)
                version = explicit
                components.removeFirst()
            }
            else 
            {
                version = nil 
            }
            
            switch (self.classify(base: base, national: components), package.explicit)
            {
            case    ( .package(_)??, false), 
                    (         nil?,  false),
                    (         nil,       _):
                return nil 
            case    (let national?,      _):
                return .init(package: package.index, version: version, national: national)
            }
        }
        private
        func classify<Path>(base:Base, national path:Path) -> NationalPath??
            where   Path:BidirectionalCollection, Path.Element == LexicalPath.Component,
                    Path.SubSequence == Path
        {
            var path:Path = path 
            switch base
            {
            // even though the expected number of {package, module} endpoints is 
            // small, we still route them through the subpaths API to get consistent 
            // case-folding behavior.
            case .package:
                // example: 
                // /packages/swift-package-name/0.1.2/search-index (package-level endpoint)
                if  let leaf:LexicalPath.Component = path.popLast(), path.isEmpty, 
                    let leaf:UInt32 = self.paths[leaf: leaf]
                {
                    return .package(leaf)
                }
            
            case .module: 
                // example: 
                // /modules/swift-package-name/0.1.2/foomodule/diagnostics (module-level endpoint)
                if  let module:LexicalPath.Component = path.popFirst(),
                    let module:Int = self.trees[0].resolve(module: module),
                    let leaf:LexicalPath.Component = path.popLast(), path.isEmpty,
                    let leaf:UInt32 = self.paths[leaf: leaf]
                {
                    return .module(module, leaf)
                }
            
            case .symbol:
                guard let module:LexicalPath.Component = path.popFirst()
                else 
                {
                    // /reference/swift-package-name/0.1.2/
                    return .some(nil)
                }
                guard let module:Int = self.trees[0].resolve(module: module)
                else 
                {
                    break
                }
                guard let leaf:LexicalPath.Component = path.popLast()
                else 
                {
                    return .symbol(module, nil)
                }
                if  let local:LocalPath = self.paths[stem: path, leaf: leaf]
                {
                    return .symbol(module, local)
                }
            
            case .article:
                // example: 
                // /learn/swift-package-name/0.1.2/foomodule/getting-started (module-level article)
                if  let module:LexicalPath.Component = path.popFirst(),
                    let module:Int = self.trees[0].resolve(module: module),
                    let leaf:LexicalPath.Component = path.popLast(), path.isEmpty,
                    let leaf:UInt32 = self.paths[leaf: leaf]
                {
                    return .article(module, leaf)
                }
            }
            return nil
        }
        
        func resolve<Path>(symbol path:Path, given context:Never) 
            where   Path:BidirectionalCollection, Path.Element == LexicalPath.Component
        {
            fatalError("unimplemented")
        }
    }
    private 
    struct Tree
    {
        private 
        let trunks:[Module.ID: Int]
        let symbols:SymbolTable
        
        init(trunks:[Module.ID: Int], symbols:SymbolTable)
        {
            self.trunks = trunks 
            self.symbols = symbols
        }
        
        func resolve(module component:LexicalPath.Component) -> Int?
        {
            if case .identifier(let string, hyphen: nil) = component
            {
                return self.trunks[Module.ID.init(string)]
            }
            else 
            {
                return nil
            }
        }
    }
    private 
    struct SymbolTable
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
            case _deinitialized
            // case opaque           (Int)
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
                case    (.big,                          .straight), 
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
                        self = ._deinitialized
                        overlay(next,           into: &stack)
                        self =                   .deep(stack,      little)
                    case .bigDeepDoubled          (var stack,  let little):
                        self = ._deinitialized
                        overlay(next,           into: &stack)
                        self =         .bigDeepDoubled(stack,      little)
                    case .bigDeep                 (var stack):
                        self = ._deinitialized
                        overlay(next,           into: &stack)
                        self =             .littleDeep(stack)
                    case ._deinitialized:
                        fatalError("unreachable")
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
                        self = ._deinitialized
                        overlay(next,                      into: &stack)
                        self =                 .deep(big,         stack)
                    case .littleDeepDoubled     (let big,     var stack):
                        self = ._deinitialized
                        overlay(next,                      into: &stack)
                        self =    .littleDeepDoubled(big,         stack)
                    case .littleDeep                         (var stack):
                        self = ._deinitialized
                        overlay(next,                      into: &stack)
                        self =                        .littleDeep(stack)
                    case ._deinitialized:
                        fatalError("unreachable")
                    }
                default: 
                    fatalError("unsupported operation")
                }
            }
        }

        private
        var entries:[Key: Entry]
        
        init()
        {
            self.entries = [:]
        }
        
        subscript(key:Key) -> Entry? 
        {
            _read 
            {
                yield self.entries[key]
            }
        }
        /* mutating 
        func insert(opaque:Int, under key:Key)
        {
            if let incumbent:Entry = self.entries.updateValue(.opaque(opaque), forKey: key)
            {
                fatalError("cannot overload \(incumbent) with opaque entry")
            }
        } */
        mutating 
        func insert(_ orientation:LexicalPath.Orientation, _ pairing:Symbol.Pairing, into key:Key)
        {
            switch orientation 
            {
            case .straight: self.insert(.big(pairing), into: key)
            case .gay:   self.insert(.little(pairing), into: key)
            }
        }
        private mutating 
        func insert(_ entry:Entry, into key:Key)
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
    struct PathTable 
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
        
        private 
        subscript<S>(leaf component:S) -> UInt32? 
            where S:StringProtocol 
        {
            self.table[Self.subpath(component)]
        }
        // this ignores the hyphen!
        subscript(leaf component:LexicalPath.Component) -> UInt32? 
        {
            guard case .identifier(let component, hyphen: _) = component
            else 
            {
                return nil
            }
            return self.table[Self.subpath(component)]
        }
        
        private 
        subscript<Path>(stem components:Path) -> UInt32? 
            where Path:Sequence, Path.Element:StringProtocol 
        {
            self.table[Self.subpath(components)]
        }
        private 
        subscript<Path>(stem components:Path) -> UInt32? 
            where Path:Sequence, Path.Element == LexicalPath.Component 
        {
            // all remaining components must be identifier-components, and only 
            // the last component may contain a hyphen.
            var stem:[String] = []
                stem.reserveCapacity(components.underestimatedCount)
            for component:LexicalPath.Component in components 
            {
                guard case .identifier(let component, hyphen: _) = component 
                else 
                {
                    return nil 
                }
                stem.append(component)
            }
            return self.table[Self.subpath(stem)]
        }
        subscript<Path>(stem prefix:Path, leaf last:LexicalPath.Component) -> LocalPath?
            where Path:Sequence, Path.Element == LexicalPath.Component
        {
            guard  case .identifier(let last, hyphen: let hyphen) = last,
                    let stem:UInt32 = self[stem: prefix], 
                    let leaf:UInt32 = self[leaf: last.prefix(upTo: hyphen ?? last.endIndex)]
            else 
            {
                return nil 
            }
            guard   let hyphen:String.Index = hyphen 
            else 
            {
                // no disambiguation suffix 
                return .init(stem: stem, leaf: leaf, suffix: nil)
            }
            let string:String = .init(last[hyphen...].dropFirst())
            if let kind:Symbol.Kind = .init(rawValue: string)
            {
                return .init(stem: stem, leaf: leaf, suffix: .kind(kind))
            }
            // https://github.com/apple/swift-docc/blob/d94139a5e64e9ecf158214b1cded2a2880fc1b02/Sources/SwiftDocC/Utility/FoundationExtensions/String%2BHashing.swift
            else if let hash:UInt32 = .init(string, radix: 36)
            {
                return .init(stem: stem, leaf: leaf, suffix: .fnv(hash: hash))
            }
            else 
            {
                return nil
            }
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
        mutating 
        func register<S>(leaf component:S) -> UInt32
            where S:StringProtocol 
        {
            self.register(Self.subpath(component))
        }
        mutating 
        func register<S>(stem components:S) -> UInt32
            where S:Sequence, S.Element:StringProtocol 
        {
            self.register(Self.subpath(components))
        }
    }
}
