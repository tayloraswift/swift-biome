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
    enum Index 
    {
        case module(Int)
        case symbol(Int)
    }
    
    private(set)
    var symbols:Symbols,
        modules:Modules
    let packages:[String?: (modules:Range<Int>, hash:Resource.Version)]
    let routes:[Path: Index]
    
    subscript(_index index:Index, modules modules:[Article], symbols symbols:[Article]) -> Resource
    {
        switch index 
        {
        case .module(let index): 
            return self.page(for: index, article: modules[index], articles: symbols)
        case .symbol(let index):
            return self.page(for: index, articles: symbols)
        }
    }
    
    private static 
    func indices(for vertices:[Vertex]) throws -> [Symbol.ID: Int]
    {
        var indices:[Symbol.ID: Int] = [:]
        for (index, symbol):(Int, Vertex) in vertices.enumerated()
        {
            guard case nil = indices.updateValue(index, forKey: symbol.id)
            else
            {
                throw SymbolIdentifierError.duplicate(symbol: symbol.id)
            }
        }
        return indices
    }
    
    init(prefix:[String], vertices:[Vertex], edges:[Edge], modules:Modules, 
        packages:[String?: (modules:Range<Int>, hash:Resource.Version)])
        throws
    {
        //  build lookup table 
        let indices:[Symbol.ID: Int]        = try Self.indices(for: vertices)
        //  link 
        var references:[Edge.References]    = .init(repeating: .init(), count: vertices.count)
        for edge:Edge in _move(edges)
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
        let colors:[Symbol.Kind] = vertices.map(\.kind)
        var relationships:[Symbol.Relationships] = try zip(colors.indices, references).map 
        {
            try .init(index: $0.0, references: $0.1, colors: colors)
        }
        // sort 
        for index:Int in relationships.indices
        {
            relationships[index].sort
            {
                vertices[$0].title < vertices[$1].title
            }
        }
        // breadcrumbs
        let breadcrumbs:[Breadcrumbs] = modules.indices.flatMap
        {
            (module:Int) -> [Breadcrumbs] in
            
            var breadcrumbs:[Breadcrumbs] = modules[module].symbols.core.map 
            {
                .init(package: modules[module].package, 
                    graph: .init(module: modules[module].id, bystander: nil), 
                    module: module, 
                    bystander: nil, 
                    path:   vertices[$0].path)
            }
            for (bystander, symbols):(Int, Range<Int>) in modules[module].symbols.extensions
            {
                let graph:Graph = .init(module: modules[module].id, bystander: modules[bystander].id)
                for index:Int in symbols
                {
                    breadcrumbs.append(.init(package: modules[bystander].package, 
                        graph: graph, 
                        module: module, 
                        bystander: bystander, 
                        path: vertices[index].path))
                }
            }
            return breadcrumbs
        }
        var paths:[Path] = breadcrumbs.indices.map
        {
            switch vertices[$0].kind 
            {
            case    .associatedtype, .typealias, .enum, .struct, .class, .actor, .protocol, .var, .func, .operator:
                return .init(prefix: prefix, breadcrumbs[$0], dot: false)
            case    .case, .initializer, .deinitializer, 
                    .typeSubscript, .instanceSubscript, 
                    .typeProperty, .instanceProperty, 
                    .typeMethod, .instanceMethod:
                return .init(prefix: prefix, breadcrumbs[$0], dot: true)
            }
        }
        // parents
        let table:[String: [Int]] = .init(grouping: vertices.indices)
        {
            paths[$0].group
        }
        var parents:[Int?] = .init(repeating: nil, count: vertices.count)
        for index:Int in vertices.indices 
        {
            guard let parent:Breadcrumbs = breadcrumbs[index].parent
            else 
            {
                // is a top-level symbol  
                continue 
            }
            let path:Path = .init(prefix: prefix, parent, dot: false)
            guard   let matches:[Int] = table[path.group], 
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
                paths[overload].disambiguation = vertices[overload].id
            }
        }
        let symbols:Symbols = .init(indices: indices, 
            symbols: try vertices.indices.map 
        {
            try .init(modules:  modules, 
                path:           paths[$0], 
                breadcrumbs:    breadcrumbs[$0], 
                parent:         parents[$0], 
                relationships:  relationships[$0],
                vertex:         vertices[$0])
        })
        self.init(packages: packages, 
            modules: modules, 
            symbols: symbols)
    }
    private 
    init(
        packages:[String?: (modules:Range<Int>, hash:Resource.Version)], 
        modules:Modules, 
        symbols:Symbols)
    {
        // symbols 
        self.modules    = modules 
        self.symbols    = symbols 
        self.packages   = packages
        
        // paths (combined)
        var routes:[Path: Index] = [:]
        for module:Int in self.modules.indices
        {
            guard case nil = routes.updateValue(.module(module), forKey: self.modules[module].path)
            else 
            {
                fatalError("unreachable")
            }
        }
        for symbol:Int in self.symbols.indices
        {
            guard case nil = routes.updateValue(.symbol(symbol), forKey: self.symbols[symbol].path)
            else 
            {
                fatalError("unreachable")
            }
        }
        self.routes = routes
        
        // gather toplevels 
        for module:Int in self.modules.indices 
        {
            for symbol:Int in self.modules[module].symbols.core 
            {
                guard case nil = symbols[symbol].breadcrumbs.parent
                else 
                {
                    continue 
                }
                self.modules[module].toplevel.append(symbol)
            }
            // sort 
            self.modules[module].toplevel.sort
            {
                self.symbols[$0].title < self.symbols[$1].title
            }
        }
        
        // topics 
        for index:Int in self.modules.indices 
        {
            let groups:[Bool: [Int]] = self.partition(symbols: self.modules[index].toplevel)
            self.modules[index].topics.members.append(contentsOf: self.organize(symbols: groups[false, default: []]))
            self.modules[index].topics.removed.append(contentsOf: self.organize(symbols: groups[true,  default: []]))
        }
        for index:Int in self.symbols.indices 
        {
            if case .protocol(let abstract) = self.symbols[index].relationships 
            {
                self.symbols[index].topics.requirements.append(contentsOf: self.organize(symbols: abstract.requirements))
            }
            guard let members:[Int] = self.symbols[index].relationships.members
            else 
            {
                continue 
            }
            let groups:[Bool: [Int]] = self.partition(symbols: members)
            self.symbols[index].topics.members.append(contentsOf: self.organize(symbols: groups[false, default: []]))
            self.symbols[index].topics.removed.append(contentsOf: self.organize(symbols: groups[true,  default: []]))
        }
    }
    private 
    func partition(symbols:[Int]) -> [Bool: [Int]]
    {
        .init(grouping: symbols)
        {
            if let availability:Symbol.UnconditionalAvailability = self.symbols[$0].availability.unconditional
            {
                if availability.unavailable || availability.deprecated
                {
                    return true 
                }
            }
            if let availability:Symbol.SwiftAvailability = self.symbols[$0].availability.swift
            {
                if case _? = availability.deprecated
                {
                    return true 
                }
                if case _? = availability.obsoleted 
                {
                    return true 
                }
            }
            return false
        }
    }
    private 
    func organize(symbols:[Int]) -> [(heading:Biome.Topic, indices:[Int])]
    {
        let topics:[Topic.Automatic: [Int]] = .init(grouping: symbols)
        {
            self.symbols[$0].kind.topic
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
        let package:String?
        let graph:Graph
        let module:Int 
        let bystander:Int? 
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
                return .init(package: self.package, graph: self.graph, 
                    module:     self.module, 
                    bystander:  self.bystander, 
                    path: [String].init(path))
            }
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
