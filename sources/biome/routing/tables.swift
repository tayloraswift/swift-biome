extension URI 
{
    enum Base:Hashable, Sendable 
    {
        case package
        case module
        case symbol 
        case article
    }
    enum Opaque
    {
        case lunr
        case sitemap 
        
        var module:Int? 
        {
            nil
        }
    }
    
    private
    struct LocalPath
    {
        let stem:UInt32, 
            leaf:UInt32, 
            suffix:LexicalPath.Suffix?
    }
    private 
    enum NationalPath
    {
        case opaque (Opaque)
        case symbol (module:Int, LocalPath?)
        case article(module:Int, UInt32)
        
        var module:Int? 
        {
            switch self 
            {
            case    .opaque(let opaque):
                return opaque.module
            case    .symbol(module: let module, _), 
                    .article(module: let module, _):
                return module 
            }
        }
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
    
    struct GlobalContext
    {
        let nationalities:[NationalContext]
        let locality:LocalContext?
    }
    struct NationalContext 
    {
        let package:Int 
        let imports:[Int]
    } 
    struct LocalContext 
    {
        let package:Int 
        let module:Int 
        let scope:[String]
    }
    
    enum NationalResolution 
    {
        case opaque (Opaque)
        
        case group  (Symbol.Group, LexicalPath.Suffix?)
        case module (Int)
        case article(Int)
    }
    struct GlobalResolution 
    {
        let package:Int 
        let national:NationalResolution?
    }
    
    struct GlobalTable 
    {
        private 
        let bases:
        (
            package:String, 
            module:String, 
            symbol:String, 
            article:String
        )
        private 
        let roots:[Package.ID: Int]
        private
        var paths:PathTable
        private 
        let keyword:
        (
            package:UInt32, 
            module:UInt32, 
            symbol:UInt32, 
            article:UInt32,
            
            sitemap:UInt32,
            lunr:UInt32
        )
        
        private
        var _packages:[NationalTable]
        private 
        let pairings:[Symbol.Pairing: Symbol.Depth]
        
        init(bases:[Base: String], biome:Biome) 
        {
            self.roots = .init(uniqueKeysWithValues: zip(biome.packages.map(\.id), biome.packages.indices))
            self.paths = .init()
            self.bases = 
            (
                package: bases[.package, default: "packages"],
                module:  bases[.module,  default: "modules"],
                symbol:  bases[.symbol,  default: "reference"],
                article: bases[.article, default: "learn"]
            )
            self.keyword = 
            (
                package:    self.paths.register(leaf: self.bases.package),
                module:     self.paths.register(leaf: self.bases.module),
                symbol:     self.paths.register(leaf: self.bases.symbol),
                article:    self.paths.register(leaf: self.bases.article),
                
                sitemap:    self.paths.register(leaf: "sitemap"),
                lunr:       self.paths.register(leaf: "lunr")
            )
            
            var keys:[(pairing:Symbol.Pairing, key:NationalTable.Key)] = []
            
            var _table:NationalTable = .init(
                trunks: .init(uniqueKeysWithValues: zip(biome.modules.map(\.id), biome.modules.indices)))
            
            for (index, symbol):(Int, Symbol) in zip(biome.symbols.indices, biome.symbols)
            {
                // do not register mythical symbols 
                guard let namespace:Int = symbol.namespace
                else 
                {
                    continue 
                }
                
                let pairing:Symbol.Pairing = .init(index)
                let key:NationalTable.Key = .init(module: namespace, 
                    stem: self.paths.register(stem: symbol.scope),
                    leaf: self.paths.register(leaf: symbol.title))
                keys.append((pairing, key))
                
                _table.insert(pairing, symbol.kind.orientation, into: key)
                
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
                    let key:NationalTable.Key = .init(module: namespace, 
                        stem: self.paths.register(stem: symbol.scope + CollectionOfOne<String>.init(symbol.title)),
                        leaf: self.paths.register(leaf: witness.title))
                    keys.append((pairing, key))
                    
                    _table.insert(pairing, witness.kind.orientation, into: key)
                }
            }
            
            self.pairings = .init(uniqueKeysWithValues: keys.map 
            {
                let symbol:(LexicalPath.Orientation, Int) = 
                (
                    biome.symbols[$0.pairing.witness].orientation, 
                    $0.pairing.witness
                )
                if let depth:Symbol.Depth = _table.depth(of: symbol, in: $0.key)
                {
                    return ($0.pairing, depth)
                }
                else 
                {
                    fatalError("unreachable")
                }
            })
            
            self._packages = [_table]
        }
        
        private
        func classify(absolute path:LexicalPath) -> GlobalPath?
        {
            //  '/base' '/swift' '' '/big'
            //  '/base' '/swift' '' '.little'
            //  '/base' '/swift' '/opaque/stem' '/big'
            //  '/base' '/swift' '/opaque/stem' '.little'
            
            //  '/base' 'swift-standard-library' '/swift' '/opaque/stem' '/big'
            guard let first:LexicalPath.Component = path.components.first 
            else 
            {
                return nil 
            }
            let base:Base
            switch self.paths[leaf: first]
            {
            case self.keyword.symbol?:  base = .symbol
            case self.keyword.article?: base = .article
            case self.keyword.package?: base = .package
            case self.keyword.module?:  base = .module
            default: return nil 
            }
            return self.classify(base: base, path.components.dropFirst())
        }
        private
        func classify<Path>(base:Base, _ path:Path) -> GlobalPath?
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
            
            switch 
            (
                self.classify(base: base, package: package.index, components), 
                package.explicit
            )
            {
            case    ( .opaque(_)??, false), 
                    (         nil?, false),
                    (         nil,      _):
                return nil 
            case    (let national?,     _):
                return .init(package: package.index, version: version, national: national)
            }
        }
        // note: this will return `.some(nil)` if the path is empty
        private
        func classify<Path>(base:Base, package _:Int, _ path:Path) -> NationalPath??
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
                guard   let leaf:LexicalPath.Component = path.popLast(), path.isEmpty
                else 
                {
                    return nil 
                }
                switch self.paths[leaf: leaf] 
                {
                case self.keyword.lunr?: 
                    return .opaque(.lunr)
                case self.keyword.sitemap?: 
                    return .opaque(.sitemap)
                default: 
                    return nil
                }
            
            case .module: 
                // example: 
                // /modules/swift-package-name/0.1.2/foomodule/diagnostics (module-level endpoint)
                guard   let module:LexicalPath.Component = path.popFirst(),
                        let module:Int = self._packages[0].resolve(module: module),
                        let leaf:LexicalPath.Component = path.popLast(), path.isEmpty 
                else 
                {
                    return nil 
                }
                // none yet
                switch self.paths[leaf: leaf]
                {
                default: 
                    return nil 
                }
            
            case .symbol:
                guard   let module:LexicalPath.Component = path.popFirst()
                else 
                {
                    // /reference/swift-package-name/0.1.2/
                    return .some(nil)
                }
                guard   let module:Int = self._packages[0].resolve(module: module)
                else 
                {
                    return nil
                }
                guard   let last:LexicalPath.Component = path.popLast()
                else 
                {
                    return .symbol(module: module, nil)
                }
                guard   let path:LocalPath = self.paths[stem: path, last]
                else 
                {
                    return nil
                }
                return .symbol(module: module, path)
            
            case .article:
                // example: 
                // /learn/swift-package-name/0.1.2/foomodule/getting-started (module-level article)
                guard   let module:LexicalPath.Component = path.popFirst(),
                        let module:Int = self._packages[0].resolve(module: module),
                        let leaf:LexicalPath.Component = path.popLast(), path.isEmpty,
                        let leaf:UInt32 = self.paths[leaf: leaf]
                else 
                {
                    return nil 
                }
                return .article(module: module, leaf)
            }
        }
        
        /* func find(absolute path:LexicalPath) -> ResolutionCandidates?
        {
            guard let global:GlobalPath = self.classify(absolute: path)
            else 
            {
                return nil
            }
        } */

        //  assume link is national. (fully qualified, including module name) 
        //  if return value is non-nil, it is always non-empty
        private 
        func find<Path>(national path:Path, given context:GlobalContext) -> GlobalResolution?
            where   Path:BidirectionalCollection, Path.Element == LexicalPath.Component
        {
            //  all imported modules in a given context have equal precedence, 
            //  regardless of their package of origin. in other words, symbols 
            //  are either visible or they are not. 
            for context:NationalContext in context.nationalities 
            {
                if case let national?? = self.classify(base: .symbol, package: context.package, path[...]),
                        let module:Int = national.module, context.imports.contains(module),
                        let resolution:NationalResolution = self._packages[0][national]
                {
                    return .init(package: context.package, national: resolution)
                }
            }
            return nil
        }
        //  assume link is local and toplevel. 
        private 
        func find<Path>(local path:Path, given context:GlobalContext) -> GlobalResolution?
            where   Path:BidirectionalCollection, Path.Element == LexicalPath.Component
        {
            guard   let last:LexicalPath.Component = path.last, 
                    let path:LocalPath = self.paths[stem: path.dropLast(), last]
            else 
            {
                return nil 
            }
            for context:NationalContext in context.nationalities 
            {
                var groups:[Symbol.Group] = []
                for module:Int in context.imports 
                {
                    if let group:Symbol.Group = self._packages[0][module: module, symbol: path]
                    {
                        groups.append(group)
                    }
                }
                guard let group:Symbol.Group = groups.first 
                else 
                {
                    continue 
                }
                if groups.count > 1 
                {
                    // inter-module name collision
                    return nil 
                }
                return .init(package: context.package, national: .group(group, path.suffix))
            }
            return nil
        }
        //  assume link is local and relative. only applies if the context specifies
        //  a local resolution base. 
        private 
        func find<Path>(relative path:Path, given context:GlobalContext) -> GlobalResolution?
            where   Path:BidirectionalCollection, Path.Element == LexicalPath.Component
        {
            guard let local:LocalContext = context.locality 
            else 
            {
                return nil 
            }
            var scope:[LexicalPath.Component] = local.scope.map { .identifier($0, hyphen: nil) }
            while !scope.isEmpty 
            {
                defer 
                {
                    scope.removeLast()
                }
                
                let path:[LexicalPath.Component] = scope + path 
                
                if  let last:LexicalPath.Component = path.last, 
                    let path:LocalPath = self.paths[stem: path.dropLast(), last],
                    let group:Symbol.Group = self._packages[0][module: local.module, symbol: path]
                {
                    return .init(package: local.package, national: .group(group, path.suffix))
                }
            }
            return nil
        }
        private 
        func find<Path>(symbol path:Path, given context:GlobalContext) -> GlobalResolution?
            where   Path:BidirectionalCollection, Path.Element == LexicalPath.Component
        {
            //  checking this first allows us to reference a module like 
            //  `Foo` as `Foo`, and its type of the same name as `Foo/Foo`.
            //  this matches the behavior of DocC.
            self.find(national: path, given: context) ?? 
            self.find(relative: path, given: context) ??
            self.find(local:    path, given: context)
        }
        
        /* private 
        func resolve(symbol string:String, given context:GlobalContext) 
        {
            let path:LexicalPath
            if      let relative:[LexicalPath.Vector?] = 
                try? Grammar.parse(string, as: Rule<String.Index, UInt8>.RelativeVectors.self)
            {
                path = .init(normalizing: relative)
            }
            else if let absolute:[LexicalPath.Vector?] = 
                try? Grammar.parse(string, as: Rule<String.Index, UInt8>.AbsoluteVectors.self)
            {
                path = .init(normalizing: absolute)
            }
        } */
    }
    
    private 
    struct NationalTable
    {
        // 16B stride. no space savings from omitting `self.stem`
        struct Key:Hashable 
        {
            let module:Int 
            let stem:UInt32 
            let leaf:UInt32 
            
            init(module:Int, leaf:UInt32)
            {
                self.init(module: module, stem: .max, leaf: leaf)
            }
            init(module:Int, stem:UInt32, leaf:UInt32)
            {
                self.module = module
                self.stem = stem
                self.leaf = leaf
            }
        }
        
        private 
        let trunks:[Module.ID: Int]
        private
        var symbols:[Key: Symbol.Group], 
            articles:[Key: Int]
        
        init(trunks:[Module.ID: Int])
        {
            self.trunks = trunks 
            self.symbols = [:]
            self.articles = [:]
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
        func depth(of symbol:(orientation:LexicalPath.Orientation, index:Int), in key:Key) -> Symbol.Depth?
        {
            self.symbols[key]?.depth(of: symbol)
        }
        
        subscript(module module:Int, symbol path:LocalPath) -> Symbol.Group?
        {
            self.symbols    [Key.init(module: module, stem: path.stem, leaf: path.leaf)]
        }
        subscript(module module:Int, article leaf:UInt32) -> Int?
        {
            self.articles   [Key.init(module: module,                  leaf:      leaf)]
        }
        subscript(path:NationalPath) -> NationalResolution?
        {
            switch path 
            {
            case .opaque(let opaque):
                // no additional lookups necessary
                return .opaque(opaque)
            
            case .symbol(module: let module, nil): 
                // no additional lookups necessary
                return .module(module)
    
            case .symbol(module: let module, let path?): 
                return self[module: module, symbol: path].map { NationalResolution.group($0, path.suffix) }
            
            case .article(module: let module, let leaf): 
                return self[module: module, article: leaf].map( NationalResolution.article(_:) )
            }
        }
        
        mutating 
        func insert(_ pairing:Symbol.Pairing, _ orientation:LexicalPath.Orientation, into key:Key)
        {
            switch orientation 
            {
            case .straight: self.insert(.big(pairing), into: key)
            case .gay:   self.insert(.little(pairing), into: key)
            }
        }
        private mutating 
        func insert(_ entry:Symbol.Group, into key:Key)
        {
            if let index:Dictionary<Key, Symbol.Group>.Index = self.symbols.index(forKey: key)
            {
                self.symbols.values[index].merge(entry)
            }
            else 
            {
                self.symbols.updateValue(entry, forKey: key)
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
        subscript<Path>(stem stem:Path, last:LexicalPath.Component) -> LocalPath?
            where Path:Sequence, Path.Element == LexicalPath.Component
        {
            if case let (leaf, suffix)? = last.leaf, 
                    let leaf:UInt32 = self[leaf: leaf], 
                    let stem:UInt32 = self[stem: stem]
            {
                return .init(stem: stem, leaf: leaf, suffix: suffix)
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
