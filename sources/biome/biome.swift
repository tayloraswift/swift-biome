import JSON 
import Resource

public 
struct Biome:Sendable 
{
    public 
    struct DecodingError<Descriptor, Model>:Error 
    {
        let expected:Any.Type, 
            path:String, 
            encountered:Descriptor?
        
        init(expected:Any.Type, in path:String = "", encountered:Descriptor?)
        {
            self.expected       = expected 
            self.path           = path 
            self.encountered    = encountered
        }
    }
    
    public 
    enum SymbolIdentifierError:Error 
    {
        case duplicate(id:Symbol.ID)
    }
    public 
    enum ModuleIdentifierError:Error 
    {
        case mismatch(decoded:Module.ID, expected:String)
        case duplicate(module:Module.ID, in:(String?, String?))
        case undefined(module:Module.ID)
    }
    
    public 
    enum Complexity:Sendable 
    {
        case constant
        case linear
        case logLinear
    }
    public 
    struct Version:CustomStringConvertible, Sendable
    {
        var major:Int 
        var minor:Int?
        var patch:Int?
        
        public 
        var description:String 
        {
            switch (self.minor, self.patch)
            {
            case (nil       , nil):         return "\(self.major)"
            case (let minor?, nil):         return "\(self.major).\(minor)"
            case (let minor , let patch?):  return "\(self.major).\(minor ?? 0).\(patch)"
            }
        }
    }
    public 
    enum Topic:Hashable, Sendable, CustomStringConvertible 
    {
        // case requirements 
        // case defaults
        case custom(String)
        case automatic(Automatic)
        case cluster(String)
        
        public
        var description:String 
        {
            switch self 
            {
            // case .requirements:         return "Requirements"
            // case .defaults:             return "Default Implementations"
            case .custom(let heading):      return heading 
            case .automatic(let automatic): return automatic.heading 
            case .cluster(_):               return "See Also"
            }
        }
    }
    

    let indices:[Symbol.ID: Int]
    var symbols:[Symbol]
    let modules:[Module.ID: _Module]
    let packages:[String?: (modules:[Module.ID], hash:Resource.Version)]
    
    subscript(index:Int) -> Symbol
    {
        _read
        {
            yield self.symbols[index]
        }
        _modify
        {
            yield &self.symbols[index]
        }
    }
    subscript(id id:Symbol.ID) -> Symbol? 
    {
        guard let index:Int = self.indices[id]
        else 
        {
            return nil 
        }
        return self.symbols[index]
    }
    
    private static 
    func modules(_ packages:[String?: (modules:[Module.ID: [Range<Int>]], hash:Resource.Version)])
        throws -> [Module.ID: _Module]
    {
        var modules:[Module.ID: _Module] = [:]
        for (package, ranges):(String?, [Module.ID: [Range<Int>]]) in packages.mapValues(\.modules) 
        {
            for (id, ranges):(Module.ID, [Range<Int>]) in ranges 
            {
                let module:_Module = .init(id: id, package: package, symbols: ranges)
                if let incumbent:_Module = modules.updateValue(module, forKey: id)
                {
                    throw ModuleIdentifierError.duplicate(module: id, in: (incumbent.package, package))
                }
            }
        }
    }
    private static 
    func indices(for symbols:[SymbolDescriptor]) throws -> [Symbol.ID: Int]
    {
        var indices:[Symbol.ID: Int] = [:]
        for (index, symbol):(Int, SymbolDescriptor) in symbols.enumerated()
        {
            guard case nil = indices.updateValue(index, forKey: symbol.id)
            else
            {
                throw SymbolIdentifierError.duplicate(id: symbol.id)
            }
        }
    }
    
    init(prefix:[String], symbols:[SymbolDescriptor],
        graphs:[(graph:Graph, symbols:Range<Int>, edges:[Edge])],
        packages:[String?: (modules:[Module.ID: [Range<Int>]], hash:Resource.Version)])
        throws
    {
        let modules:[Module.ID: _Module]    = try Self.modules(packages)
        //  build lookup table 
        let indices:[Symbol.ID: Int]        = try Self.indices(for: symbols)
        //  link 
        var references:[Edge.References]    = .init(repeating: .init(), count: symbols.count)
        for edge:Edge in graphs.map(\.edges).joined()
        {
            guard   let source:Int = indices[edge.source], 
                    let target:Int = indices[edge.target]
            else 
            {
                print("warning: undefined symbol id in edge '\(edge.source)' -> '\(edge.target)'")
                continue 
            } 
            try edge.link(source, to: target, in: &references)
        }
        // validate 
        let colors:[Symbol.Kind] = symbols.map(\.kind)
        var relationships:[Symbol.Relationships] = try zip(colors.indices, references).map 
        {
            try .init(index: $0.0, references: $0.1, colors: colors)
        }
        // sort 
        for index:Int in relationships.indices
        {
            relationships[index].sort
            {
                symbols[$0].title < symbols[$1].title
            }
        }
        // breadcrumbs
        let breadcrumbs:[Breadcrumbs] = graphs.flatMap
        {
            (range:(graph:Graph, symbols:Range<Int>, edges:[Edge])) in
            range.symbols.map 
            {
                .init(graph: range.graph, path: symbols[$0].path)
            }
        }
        var paths:[Symbol.Path] = try breadcrumbs.indices.map
        {
            let breadcrumbs:Breadcrumbs = breadcrumbs[$0]
            guard let module:_Module    = modules[breadcrumbs.graph.namespace]
            else 
            {
                // a module extends a bystander module we do not have the 
                // primary symbolgraph for
                throw ModuleIdentifierError.undefined(module: breadcrumbs.graph.namespace)
            }
            return breadcrumbs.path(prefix: prefix, package: module.package, kind: symbols[$0].kind)
        }
        // parents
        let table:[String: [Int]] = .init(grouping: symbols.indices)
        {
            paths[$0].group
        }
        var parents:[Int?] = .init(repeating: nil, count: symbols.count)
        for index:Int in symbols.indices 
        {
            guard let parent:Breadcrumbs = breadcrumbs[index].parent
            else 
            {
                // is a top-level symbol  
                continue 
            }
            guard   let matches:[Int] = table[parent.path.group], 
                    let parent:Int = matches.first
            else 
            {
                throw LinkingError.orphaned(symbol: index)
            }
            guard matches.count == 1
            else 
            {
                throw LinkingError.junction(symbol: index)
            }
            parents[index] = parent 
        }
        // canonical paths. if paths collide, *every* symbol in 
        // the path group gets a disambiguation tag 
        for overloads:[Int] in table.values where overloads.count > 1
        {
            for overload:Int in overloads 
            {
                paths[overload].disambiguation = symbols[overload].id
            }
        }
        
        self.init(prefix: prefix, packages: packages, modules: modules, indices: indices, 
            symbols: symbols.indices.map 
        {
            .init(
                path:           paths[$0], 
                breadcrumbs:    breadcrumbs[$0], 
                parent:         parents[$0], 
                relationships:  relationships[$0],
                descriptor:     symbols[$0])
        })
    }
    private 
    init(prefix:[String], 
        packages:[String?: (modules:[Module.ID: [Range<Int>]], hash:Resource.Version)], 
        modules:[Module.ID: _Module], 
        indices:[Symbol.ID: Int], 
        symbols:[Symbol])
    {
        self.indices = indices 
        self.symbols = symbols 
        
        var modules:[Module.ID: _Module] = _move(modules)
        // toplevels 
        for module:_Module in modules.values 
        {
            for symbol:Int in module.symbols.joined() 
            {
                guard case nil = symbols[symbol].breadcrumbs.parent
                else 
                {
                    continue 
                }
                guard let index:Dictionary<Module.ID, _Module>.Index = modules.index(forKey: symbols[symbol].namespace)
                else 
                {
                    print("warning: ignored bystander symbol '\(symbols[symbol].title)' in module '\(symbols[symbol].namespace)'")
                    continue 
                }
                modules.values[index].toplevel.append(symbol)
            }
        }
        self.modules = modules 
        self.packages = packages.mapValues 
        {
            ([Module.ID].init($0.modules.keys), $0.hash)
        }
        
        for index:Int in self.symbols.indices 
        {
            if case .protocol(let abstract) = self[index].relationships 
            {
                self[index].topics.requirements.append(contentsOf: self.organize(symbols: abstract.requirements))
            }
            if let members:[Int] = self[index].relationships.members
            {
                self[index].topics.members.append(contentsOf: self.organize(symbols: members))
            }
        }
    }
    
    func organize(symbols:[Int]) -> [(heading:Biome.Topic, indices:[Int])]
    {
        let topics:[Topic.Automatic: [Int]] = .init(grouping: symbols)
        {
            self[$0].kind.topic
        }
        return Topic.Automatic.allCases.compactMap
        {
            (topic:Topic.Automatic) in 
            guard let indices:[Int] = topics[topic]
            else 
            {
                return nil 
            }
            return (.automatic(topic), indices)
        }
    }
}
extension Biome.Topic 
{
    public 
    enum Automatic:String, Sendable, Hashable, CaseIterable
    {
        case module             = "Modules"
        case `case`             = "Enumeration Cases"
        case `associatedtype`   = "Associated Types"
        case `typealias`        = "Typealiases"
        case initializer        = "Initializers"
        case deinitializer      = "Deinitializers"
        case typeSubscript      = "Type Subscripts"
        case instanceSubscript  = "Instance Subscripts"
        case typeProperty       = "Type Properties"
        case instanceProperty   = "Instance Properties"
        case typeMethod         = "Type Methods"
        case instanceMethod     = "Instance Methods"
        case global             = "Global Variables"
        case function           = "Functions"
        case `operator`         = "Operators"
        case `enum`             = "Enumerations"
        case `struct`           = "Structures"
        case `class`            = "Classes"
        case actor              = "Actors"
        case `protocol`         = "Protocols"
        
        var heading:String 
        {
            self.rawValue
        }
    }
}

extension Biome 
{
    struct Breadcrumbs:Hashable 
    {
        let graph:Graph
        let path:[String]
        
        var last:String 
        {
            guard let last:String = path.last 
            else 
            {
                fatalError("unreachable")
            }
            return last 
        }
        
        var parent:Self? 
        {
            let path:ArraySlice = self.path.dropLast()
            if path.isEmpty 
            {
                return nil 
            }
            else 
            {
                return .init(graph: self.graph, path: [String].init(path))
            }
        }
        
        func path(prefix:[String], package:String?, kind:Symbol.Kind) -> Symbol.Path
        {
            // to reduce the need for disambiguation suffixes, nested types and members 
            // use different syntax: 
            // Foo.Bar.baz(qux:) -> 'foo/bar.baz(qux:)' ["foo", "bar.baz(qux:)"]
            // 
            // global variables, functions, and operators (including scoped operators) 
            // start with a slash. so it’s 'prefix/swift/withunsafepointer(to:)', 
            // not `prefix/swift.withunsafepointer(to:)`
            
            var unescaped:[String]  = prefix 
            if let package:String   = package 
            {
                unescaped.append(package)
            }
            unescaped.append(self.graph.namespace.title)
            switch kind 
            {
            case    .associatedtype, .typealias, .enum, .struct, .class, .actor, .protocol, .var, .func, .operator:
                unescaped.append(contentsOf: self.path)
            case    .case, .initializer, .deinitializer, 
                    .typeSubscript, .instanceSubscript, 
                    .typeProperty, .instanceProperty, 
                    .typeMethod, .instanceMethod:
                guard let scope:String = self.path.dropLast().last 
                else 
                {
                    print("warning: member '\(self.path)' has no outer scope")
                    unescaped.append(contentsOf: self.path)
                    break 
                }
                unescaped.append(contentsOf: self.path.dropLast(2))
                unescaped.append("\(scope).\(self.last)")
            }
            
            return .init(group: Biome.normalize(path: unescaped))
        }
        
        var lexemes:[Language.Lexeme] 
        {
            var lexemes:[Language.Lexeme]   = []
                lexemes.reserveCapacity(self.path.count * 2 - 1)
            for current:String in self.path.dropLast() 
            {
                lexemes.append(.code(current,   class: .identifier))
                lexemes.append(.code(".",       class: .punctuation))
            }
            lexemes.append(.code(self.last,     class: .identifier))
            return lexemes
        }
    }

}
