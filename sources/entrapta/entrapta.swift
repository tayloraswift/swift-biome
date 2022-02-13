import JSON 

public 
enum Entrapta 
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
    struct Version 
    {
        var major:Int 
        var minor:Int?
        var patch:Int?
    }
    
    enum Topic:Hashable, CustomStringConvertible 
    {
        // case requirements 
        // case defaults
        case kind(Entrapta.Graph.Symbol.Kind)
        case custom(String)
        case cluster(String)
        
        var description:String 
        {
            switch self 
            {
            // case .requirements:         return "Requirements"
            // case .defaults:             return "Default Implementations"
            case .kind(let kind):       return kind.plural 
            case .custom(let heading):  return heading 
            case .cluster(_):           return "See Also"
            }
        }
    }
    
    public 
    struct Graph 
    {
        typealias Index = Dictionary<Symbol.ID, Symbol>.Index
        
        var symbols:[Symbol.ID: Symbol]
        let modules:[Index]
        let groups:[String: [Index]]
        
        subscript(index:Index) -> Symbol
        {
            _read
            {
                yield self.symbols.values[index]
            }
            _modify
            {
                yield &self.symbols.values[index]
            }
        }
        
        private 
        init(prefix:[String], modules:[(module:Symbol.Module, json:[JSON])]) throws 
        {
            var symbols:[Symbol.ID: Symbol] = [:]
            for (module, json):(Symbol.Module, [JSON]) in modules
            {
                let root:Symbol = .init(module: module, prefix: prefix)
                if case _? = symbols.updateValue(root, forKey: .module(module))
                {
                    print("warning: duplicate module '\(module.identifier)'")
                }
                
                for json:JSON in json 
                {
                    guard case .object(var items) = json 
                    else 
                    {
                        throw Symbol.DecodingError.init(expected: [String: JSON].self, encountered: json)
                    }
                    let id:Symbol.ID
                    switch items.removeValue(forKey: "identifier")
                    {
                    case .object(var items)?: 
                        defer 
                        {
                            items["interfaceLanguage"] = nil 
                            
                            if !items.isEmpty 
                            {
                                print("warning: unused json keys \(items) in 'identifier'")
                            }
                        }
                        switch items.removeValue(forKey: "precise")
                        {
                        case .string(let text)?:
                            id = .declaration(precise: text)
                        case let value:
                            throw Symbol.DecodingError.init(expected: String.self, in: "identifier.precise", encountered: value)
                        }
                    case let value:
                        throw Symbol.DecodingError.init(expected: [String: JSON].self, in: "identifier", encountered: value)
                    }
                    
                    let symbol:Symbol   = try .init(from: items, in: module, prefix: prefix)
                    guard case nil      = symbols.updateValue(symbol, forKey: id)
                    else 
                    {
                        print("warning: duplicate symbol id '\(id)'")
                        continue 
                    }
                }
            }
            // find all the modules in the dictionary 
            self.modules = symbols.indices.filter 
            {
                if case .module = symbols.values[$0].kind
                {
                    return true 
                }
                else 
                {
                    return false 
                }
            }
            // compute canonical paths. if paths collide, *every* symbol in 
            // the path group gets a disambiguation tag 
            self.groups = .init(grouping: symbols.indices)
            {
                symbols.values[$0].path.group
            }
            
            self.symbols = _move(symbols)
            for overloads:[Index] in self.groups.values where overloads.count > 1
            {
                for overload:Index in overloads 
                {
                    self.symbols.values[overload].path.disambiguation = self.symbols.keys[overload]
                }
            }
        }
        init(prefix:[String] = [], modules json:[JSON]) throws
        {
            var declarations:[(module:Symbol.Module, json:[JSON])] = []
                declarations.reserveCapacity(json.count)
            var edges:[(module:Symbol.Module, json:[JSON])] = []
                edges.reserveCapacity(json.count)
            
            for json:JSON in json 
            {
                guard   case .object(let graph)         = json, 
                        case .object(let json)?         = graph["module"],
                        case .array(let symbols)?       = graph["symbols"],
                        case .array(let relationships)? = graph["relationships"]
                else 
                {
                    throw Entrapta.DecodingError<JSON, Self>.init(expected: Self.self, encountered: json)
                }
                
                let module:Symbol.Module 
                switch json["name"] 
                {
                case .string("Swift")?: 
                    module = .swift 
                case .string(let name)?:
                    module = .framework(name, package: "unknown")
                default:
                    print("could not determine module name")
                    continue 
                }
                // let descriptor:Descriptor.Module = try .init(from: module)
                declarations.append((module, symbols))
                edges.append((module, relationships))
            }

            try self.init(prefix: prefix, modules: declarations)
            // link the edges 
            for (_, json):(Symbol.Module, [JSON]) in edges 
            {
                for json:JSON in json
                {
                    self.link(edge: try .init(from: json))
                }
            }
            
            let table:[Breadcrumbs: [Index]] = .init(grouping: self.symbols.indices)
            {
                self[$0].breadcrumbs
            }
            // compute the DAG 
            for index:Index in self.symbols.indices 
            {
                let breadcrumbs:Breadcrumbs = self[index].breadcrumbs
                guard let tail:String = breadcrumbs.body.last
                else 
                {
                    // is a module 
                    continue 
                }
                let parent:Breadcrumbs      = .init(body: [String].init(breadcrumbs.body.dropLast()), tail: tail)
                guard   let matches:[Index] = table[parent], 
                        let parent:Index    = matches.first
                else 
                {
                    print("warning: symbol \(self[index].title) has no parent")
                    continue 
                }
                self[index].parent = parent 
                if case .module = self[parent].kind 
                {
                    self[parent].members.append(index)
                }
                if matches.count != 1 
                {
                    print("warning: symbol \(self[index].title) has more than one parent")
                }
            }
            
            self.sort()
            self.populateTopics()
        }
        
        mutating 
        func link(edge:Edge) 
        {
            switch 
            (
                self.symbols.index(forKey: edge.source),
                is: edge.kind,
                of: self.symbols.index(forKey: edge.target)
            )
            {
            case    (let symbol?, is: .member, of: let type?): 
                if !edge.constraints.isEmpty 
                {
                    print("warning: edge constraints are not supported for member relationships")
                }
                self[type].members.append(symbol)
            
            case    (let symbol?, is: .conformer, of: let upstream?):
                if case .declaration(.protocol) = self[symbol].kind 
                {
                    // <Protocol>:<Protocol>
                    if !edge.constraints.isEmpty 
                    {
                        print("warning: protocol '\(self[upstream].title)' cannot conditionally refine an upstream protocol")
                    }
                    
                    self[symbol].upstream.append((upstream, []))
                    self[upstream].downstream.append(symbol)
                }
                else if case .declaration(.protocol) = self[upstream].kind 
                {
                    // <Non-protocol>:<Protocol>
                    self[symbol].upstream.append((upstream, edge.constraints))
                    self[upstream].conformers.append((symbol, edge.constraints))
                }
                else 
                {
                    print("warning: ignored upstream type '\(self[upstream].title)' because it is not a protocol")
                }
            case    (let symbol?, is: .subclass, of: let superclass?):
                if !edge.constraints.isEmpty 
                {
                    print("warning: edge constraints are not supported for subclass relationships")
                }
                if let incumbent:Index = self[symbol].superclass
                {
                    print("warning: symbol \(self[symbol].title) has multiple superclasses '\(self[incumbent].title)', '\(self[superclass].title)'")
                }
                if case .declaration(.class) = self[superclass].kind 
                {
                    self[symbol].superclass = superclass
                    self[superclass].subclasses.append(symbol)
                }
                else 
                {
                    print("warning: ignored superclass type '\(self[superclass].title)' because it is not a class")
                }
                
            case    (let symbol?, is: .optionalRequirement, of: let interface?),
                    (let symbol?, is: .requirement, of: let interface?):
                if !edge.constraints.isEmpty 
                {
                    print("warning: edge constraints are not supported for requirement relationships")
                }
                if let incumbent:Index = self[symbol].interface
                {
                    print("warning: symbol \(self[symbol].title) is a requirement of multiple protocols '\(self[incumbent].title)', '\(self[interface].title)'")
                }
                if case .declaration(.protocol) = self[interface].kind 
                {
                    self[symbol].interface = interface
                    self[interface].requirements.append(symbol)
                }
                else 
                {
                    print("warning: ignored interface type '\(self[interface].title)' because it is not a protocol")
                }
            
            case    (let symbol?, is: .override, of: let requirement?):
                if !edge.constraints.isEmpty 
                {
                    print("warning: edge constraints are not supported for override relationships")
                }
                if let incumbent:Index = self[symbol].overrides 
                {
                    print("warning: symbol \(self[symbol].title) overrides multiple requirements '\(self[incumbent].title)', '\(self[requirement].title)'")
                }
                self[symbol].overrides = requirement 
                
            case    (let symbol?, is: .defaultImplementation, of: let requirement?):
                if !edge.constraints.isEmpty 
                {
                    print("warning: edge constraints are not supported for default implementation relationships")
                }
                self[symbol].implements.append(requirement)
                self[requirement].defaults.append(symbol)
            
            case    (nil, is: _, of: _): 
                print("warning: undefined symbol id '\(edge.source)'")
            case    (_, is: _, of: nil): 
                print("warning: undefined symbol id '\(edge.target)'")
            }
        }
        mutating 
        func populateTopics() 
        {
            for index:Index in self.symbols.indices 
            {                
                self[index].topics.requirements.append(contentsOf: self.organize(symbols: self[index].requirements))
                self[index].topics.members.append(contentsOf: self.organize(symbols: self[index].members))
            }
        }
        func organize(symbols:[Index]) -> [(key:Entrapta.Topic, indices:[Index])]
        {
            let topics:[Symbol.Kind: [Index]] = .init(grouping: symbols)
            {
                self[$0].kind
            }
            return Entrapta.Graph.Symbol.Kind.allCases.compactMap
            {
                (kind:Symbol.Kind) in 
                guard let indices:[Index] = topics[kind]
                else 
                {
                    return nil 
                }
                return (.kind(kind), indices)
            }
        }
        mutating 
        func sort() 
        {
            for symbol:Index in self.symbols.indices 
            {
                self[symbol].members        = self[symbol].members.sorted
                {
                    self[$0].title < self[$1].title
                }
                self[symbol].implements     = self[symbol].implements.sorted
                {
                    self[$0].title < self[$1].title
                }
                self[symbol].defaults       = self[symbol].defaults.sorted
                {
                    self[$0].title < self[$1].title
                }
                self[symbol].requirements   = self[symbol].requirements.sorted
                {
                    self[$0].title < self[$1].title
                }
                self[symbol].upstream       = self[symbol].upstream.sorted
                {
                    self[$0.index].title < self[$1.index].title
                }
                self[symbol].downstream     = self[symbol].downstream.sorted
                {
                    self[$0].title < self[$1].title
                }
                self[symbol].conformers     = self[symbol].conformers.sorted
                {
                    self[$0.index].title < self[$1.index].title
                }
            }
        }
    }
}
extension Entrapta.Graph 
{
    struct Breadcrumbs:Hashable 
    {
        let body:[String], 
            tail:String
        
        var lexemes:[Language.Lexeme] 
        {
            // don’t include the module prefix, if this symbol is not the module 
            // itself 
            let body:ArraySlice<String>     = body.dropFirst()
            var lexemes:[Language.Lexeme]   = []
                lexemes.reserveCapacity(body.count * 2 + 1)
            for current:String in body 
            {
                lexemes.append(.code(current,   class: .identifier))
                lexemes.append(.code(".",       class: .punctuation))
            }
            lexemes.append(.code(self.tail,     class: .identifier))
            return lexemes
        }
    }
    struct Edge 
    {
        // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/Edge.h
        enum Kind:String
        {
            case member                     = "memberOf"
            case conformer                  = "conformsTo"
            case subclass                   = "inheritsFrom"
            case override                   = "overrides"
            case requirement                = "requirementOf"
            case optionalRequirement        = "optionalRequirementOf"
            case defaultImplementation      = "defaultImplementationOf"
        }
        // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/Edge.cpp
        var kind:Kind 
        var target:Symbol.ID
        var source:Symbol.ID 
        // if the source inherited docs 
        var origin:(id:Symbol.ID, name:String)?
        var constraints:[Language.Constraint]
    }
    public 
    struct Symbol 
    {
        typealias DecodingError = Entrapta.DecodingError<JSON, Self>
        
        public 
        enum Module:Hashable, Comparable, Sendable
        {
            case swift 
            case framework(String, package:String)
            
            public 
            var name:String 
            {
                switch self 
                {
                case .swift:                                return "Swift"
                case .framework(let module, package: _):    return module
                }
            }
            public 
            var identifier:[String] 
            {
                switch self 
                {
                case .swift:                                        return ["swift"]
                case .framework(let module, package: let package):  return [package.lowercased(), module.lowercased()]
                }
            }
        }
        public 
        enum ID:Hashable, Comparable, Sendable 
        {
            case module(Module)
            case declaration(precise:String)
        }
        public 
        enum Kind:Hashable, CaseIterable, CustomStringConvertible 
        {
            public 
            enum Declaration:String, Hashable, CaseIterable 
            {    
                case `case`             = "swift.enum.case"
                case `associatedtype`   = "swift.associatedtype"
                case `typealias`        = "swift.typealias"
                
                case initializer        = "swift.init"
                case deinitializer      = "swift.deinit"
                case typeSubscript      = "swift.type.subscript"
                case instanceSubscript  = "swift.subscript"
                case typeProperty       = "swift.type.property"
                case instanceProperty   = "swift.property"
                case typeMethod         = "swift.type.method"
                case instanceMethod     = "swift.method"
                
                case  global            = "swift.var"
                case  function          = "swift.func"
                
                case `operator`         = "swift.func.op"
                case `enum`             = "swift.enum"
                case `struct`           = "swift.struct"
                case `class`            = "swift.class"
                case  actor             = "swift.actor"
                case `protocol`         = "swift.protocol"
            }
            
            case declaration(Declaration)
            case module 
            
            public static 
            var allCases:[Self]
            {
                Declaration.allCases.map(Self.declaration(_:)) + CollectionOfOne<Self>.init(.module)
            }
            public 
            var description:String 
            {
                switch self 
                {
                case .module:                   return "Module"
                case .declaration(let kind):
                    switch kind 
                    {
                    case .case:                 return "Enumeration Case"
                    case .associatedtype:       return "Associated Type"
                    case .typealias:            return "Typealias"
                    case .initializer:          return "Initializer"
                    case .deinitializer:        return "Deinitializer"
                    case .typeSubscript:        return "Type Subscript"
                    case .instanceSubscript:    return "Instance Subscript"
                    case .typeProperty:         return "Type Property"
                    case .instanceProperty:     return "Instance Property"
                    case .typeMethod:           return "Type Method"
                    case .instanceMethod:       return "Instance Method"
                    case .global:               return "Global Variable"
                    case .function:             return "Function"
                    case .operator:             return "Operator"
                    case .enum:                 return "Enumeration"
                    case .struct:               return "Structure"
                    case .class:                return "Class"
                    case .actor:                return "Actor"
                    case .protocol:             return "Protocol"
                    }
                }
            }
            var plural:String 
            {
                switch self 
                {
                case .module:                   return "Modules"
                case .declaration(let kind):
                    switch kind 
                    {
                    case .case:                 return "Enumeration Cases"
                    case .associatedtype:       return "Associated Types"
                    case .typealias:            return "Typealiases"
                    case .initializer:          return "Initializers"
                    case .deinitializer:        return "Deinitializers"
                    case .typeSubscript:        return "Type Subscripts"
                    case .instanceSubscript:    return "Instance Subscripts"
                    case .typeProperty:         return "Type Properties"
                    case .instanceProperty:     return "Instance Properties"
                    case .typeMethod:           return "Type Methods"
                    case .instanceMethod:       return "Instance Methods"
                    case .global:               return "Global Variables"
                    case .function:             return "Functions"
                    case .operator:             return "Operators"
                    case .enum:                 return "Enumerations"
                    case .struct:               return "Structures"
                    case .class:                return "Classes"
                    case .actor:                return "Actors"
                    case .protocol:             return "Protocols"
                    }
                }
            }
        }
        public 
        struct Path:Hashable, Sendable
        {
            let group:String
            var disambiguation:ID?
            
            var canonical:String 
            {
                if case .declaration(precise: let precise)? = self.disambiguation 
                {
                    return "\(self.group)?overload=\(precise)"
                }
                else 
                {
                    return self.group
                }
            }
            init(group:String, disambiguation:ID? = nil)
            {
                self.group          = group
                self.disambiguation = disambiguation
            }
        }
        public 
        enum Access
        {
            case `private` 
            case `fileprivate`
            case `internal`
            case `public`
            case `open`
        }
        public 
        enum Domain:String, Hashable  
        {
            case swift      = "Swift"
            case wildcard   = "*"
            
            case iOS 
            case macOS
            case macCatalyst
            case tvOS
            case watchOS
            
            case openBSD    = "OpenBSD"
            
            case iOSApplicationExtension
            case macOSApplicationExtension
            case macCatalystApplicationExtension
            case tvOSApplicationExtension
            case watchOSApplicationExtension
        }
        public 
        struct Availability
        {
            // case unavailable 
            var introduced:Entrapta.Version?
            var deprecated:Entrapta.Version?
            var obsoleted:Entrapta.Version?
            var renamed:String?
            var message:String?
        }
        public 
        struct Parameter
        {
            var label:String 
            var name:String?
            var fragment:[Language.Lexeme]
        }
        public 
        struct Generic
        {
            var name:String 
            var index:Int 
            var depth:Int 
        }
        
        let module:Module
        var path:Path
        
        let breadcrumbs:Breadcrumbs
        
        let title:String 
        let kind:Kind
        let signature:[Language.Lexeme]
        let declaration:[Language.Lexeme]
        
        let extends:(module:String, where:[Language.Constraint])?
        let generic:(parameters:[Generic], constraints:[Language.Constraint])?
        let availability:[(key:Domain, value:Availability)]
        
        let comment:String
        var discussion:(head:Frontend?, body:[Frontend])
        
        var parent:Index?
        
        var members:[Index], 
        
            implements:[Index], 
            defaults:[Index], 
            
            interface:Index?,
            requirements:[Index],
            
            upstream:[(index:Index, conditions:[Language.Constraint])], // protocols this type conforms to
            downstream:[Index], // protocols that refine this type (empty if not a protocol)
            conformers:[(index:Index, conditions:[Language.Constraint])], // non-protocol types that conform to this type (empty if not a protocol)
            subclasses:[Index],
            superclass:Index?, 
            overrides:Index?
            
        var topics:
        (
            requirements:[(key:Entrapta.Topic, indices:[Index])],
            members:[(key:Entrapta.Topic, indices:[Index])]
        )
        
        init(module:Module, prefix:[String]) 
        {
            self.init(kind:    .module, 
                title:          module.name, 
                breadcrumbs:   .init(body: [], tail: module.name), 
                path:          .init(group: "/\((prefix + module.identifier).joined(separator: "/"))"), 
                in:             module)
        }
        
        init(
            kind:Kind, 
            title:String, 
            breadcrumbs:Breadcrumbs, 
            path:Path, 
            in module:Module, 
            signature:[Language.Lexeme] = [], 
            declaration:[Language.Lexeme] = [], 
            extends:(module:String, where:[Language.Constraint])? = nil,
            generic:(parameters:[Generic], constraints:[Language.Constraint])? = nil,
            availability:[(key:Domain, value:Availability)] = [],
            comment:String = "") 
        {
            // if this is a (nested) type, print its fully-qualified signature
            let keyword:String?
            switch kind 
            {
            case .declaration(.typealias):  keyword = "typealias"
            case .declaration(.enum):       keyword = "enum"
            case .declaration(.struct):     keyword = "struct"
            case .declaration(.class):      keyword = "class"
            case .declaration(.actor):      keyword = "actor"
            case .declaration(.protocol):   keyword = "protocol"
            default:                        keyword = nil 
            }
            
            self.kind           = kind
            self.title          = title 
            self.breadcrumbs    = breadcrumbs
            self.path           = path
            self.module         = module 
            if let keyword:String = keyword 
            {
                self.signature  = [.code(keyword, class: .keyword(.other)), .spaces(1)] + breadcrumbs.lexemes 
            }
            else 
            {
                self.signature  = signature
            }
            self.declaration    = declaration
            self.extends        = extends
            self.generic        = generic
            self.availability   = availability
            self.comment        = comment
            
            self.discussion     = (nil, [])
            
            self.parent         = nil
             
            self.members        = []
            
            self.implements     = []
            self.defaults       = []
            
            self.interface      = nil
            self.requirements   = []
            
            self.upstream       = []
            self.downstream     = []
            self.conformers     = []
            self.subclasses     = []
            self.superclass     = nil
            self.overrides      = nil
            
            self.topics         = ([], [])
        }
    }
}
