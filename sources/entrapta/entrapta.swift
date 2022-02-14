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
    enum Complexity 
    {
        case constant
        case linear
        case logLinear
    }
    public 
    struct Version 
    {
        var major:Int 
        var minor:Int?
        var patch:Int?
    }
    public 
    enum Topic:Hashable, CustomStringConvertible 
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
    
    public 
    struct Graph 
    {
        public 
        enum Module:Hashable, Comparable, Sendable
        {
            case swift 
            case concurrency
            case community(module:String, package:String)
            
            var name:String 
            {
                switch self 
                {
                case .swift:
                    return "Swift"
                case .concurrency:
                    return "_Concurrency"
                case .community(module: let module, package: _):
                    return module
                }
            }
            var title:String 
            {
                switch self 
                {
                case .swift:
                    return "Swift"
                case .concurrency:
                    return "Concurrency"
                case .community(module: let module, package: _):
                    return module
                }
            }
            var identifier:[String] 
            {
                switch self 
                {
                case .swift:
                    return ["swift"]
                case .concurrency:
                    return ["concurrency"]
                case .community(module: let module, package: let package):  
                    return [package.lowercased(), module.lowercased()]
                }
            }
            var declaration:[Language.Lexeme]
            {
                [
                    .code("import", class: .keyword(.other)),
                    .spaces(1),
                    .code(self.name, class: .identifier)
                ]
            }
        }
        
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
        
        init(modules json:[Module: JSON], prefix:[String] = []) throws
        {
            let destructured:[Module: (symbols:[JSON], edges:[JSON])] = try json.mapValues
            {
                guard   case .object(let graph)     = $0, 
                        case .object(_)?            = graph["module"],
                        case .array(let symbols)?   = graph["symbols"],
                        case .array(let edges)?     = graph["relationships"]
                else 
                {
                    throw Entrapta.DecodingError<JSON, Self>.init(expected: Self.self, encountered: $0)
                }
                
                return (symbols: symbols, edges: edges)
            }

            try self.init(symbols: destructured.mapValues(\.symbols), prefix: prefix)
            // link the edges 
            for json:[JSON] in destructured.values.map(\.edges) 
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
        
        private 
        init(symbols modules:[Module: [JSON]], prefix:[String]) throws 
        {
            var symbols:[Symbol.ID: Symbol] = [:]
            for (module, json):(Module, [JSON]) in modules
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
                if case .protocol = self[symbol].kind 
                {
                    // <Protocol>:<Protocol>
                    if !edge.constraints.isEmpty 
                    {
                        print("warning: protocol '\(self[upstream].title)' cannot conditionally refine an upstream protocol")
                    }
                    
                    self[symbol].upstream.append((upstream, []))
                    self[upstream].downstream.append(symbol)
                }
                else if case .protocol = self[upstream].kind 
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
                if case .class = self[superclass].kind 
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
                if case .protocol = self[interface].kind 
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
        func organize(symbols:[Index]) -> [(heading:Entrapta.Topic, indices:[Index])]
        {
            let topics:[Topic.Automatic: [Index]] = .init(grouping: symbols)
            {
                self[$0].kind.topic
            }
            return Topic.Automatic.allCases.compactMap
            {
                (topic:Topic.Automatic) in 
                guard let indices:[Index] = topics[topic]
                else 
                {
                    return nil 
                }
                return (.automatic(topic), indices)
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
extension Entrapta.Topic 
{
    public 
    enum Automatic:String, Hashable, CaseIterable
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
extension Entrapta.Graph.Symbol 
{
    public 
    enum Kind 
    {
        typealias Descriptor = (identifier:String, function:(parameters:[Parameter], returns:[Language.Lexeme])?)
        
        case module 
        
        case `case`
        case `associatedtype`
        case `typealias`
        
        case initializer
        case deinitializer
        case typeSubscript
        case instanceSubscript
        case typeProperty
        case instanceProperty
        case typeMethod         (parameters:[Parameter], returns:[Language.Lexeme])
        case instanceMethod     (parameters:[Parameter], returns:[Language.Lexeme])
        
        case  global
        case  function          (parameters:[Parameter], returns:[Language.Lexeme])
        case `operator`         (parameters:[Parameter], returns:[Language.Lexeme])
        case `enum`
        case `struct`
        case `class`
        case  actor 
        case `protocol`
        
        public 
        var topic:Entrapta.Topic.Automatic
        {
            switch self 
            {
            case .module:               return .module
            case .case:                 return .case
            case .associatedtype:       return .associatedtype
            case .typealias:            return .typealias
            case .initializer:          return .initializer
            case .deinitializer:        return .deinitializer
            case .typeSubscript:        return .typeSubscript
            case .instanceSubscript:    return .instanceSubscript
            case .typeProperty:         return .typeProperty
            case .instanceProperty:     return .instanceProperty
            case .typeMethod:           return .typeMethod
            case .instanceMethod:       return .instanceMethod
            case .global:               return .global
            case .function:             return .function
            case .operator:             return .operator
            case .enum:                 return .enum
            case .struct:               return .struct
            case .class:                return .class
            case .actor:                return .actor
            case .protocol:             return .protocol
            }
        }
        
        init(_ identifier:String, function:(parameters:[Parameter], returns:[Language.Lexeme])?) throws
        {
            switch (identifier, function)
            {
            case ("swift.enum.case", nil):
                self = .case
            case ("swift.associatedtype", nil):
                self = .associatedtype
            case ("swift.typealias", nil):
                self = .typealias
                
            case ("swift.init", nil):
                self = .initializer
            case ("swift.deinit", nil):
                self = .deinitializer
            case ("swift.type.subscript", nil):
                self = .typeSubscript
            case ("swift.subscript", nil):
                self = .instanceSubscript
            case ("swift.type.property", nil):
                self = .typeProperty
            case ("swift.property", nil):
                self = .instanceProperty
            case ("swift.type.method", let function?):
                self = .typeMethod(parameters: function.parameters, returns: function.returns)
            case ("swift.method", let function?):
                self = .instanceMethod(parameters: function.parameters, returns: function.returns)
            
            case ("swift.var", nil):
                self = .global    
            case ("swift.func", let function?):
                self = .function(parameters: function.parameters, returns: function.returns)
            case ("swift.func.op", let function?): 
                self = .operator(parameters: function.parameters, returns: function.returns)
            case ("swift.enum", nil):
                self = .enum
            case ("swift.struct", nil):
                self = .struct
            case ("swift.class", nil):
                self = .class
            case ("swift.actor", nil):
                self = .actor
            case ("swift.protocol", nil):
                self = .protocol
            default: 
                throw Entrapta.DecodingError<Descriptor, Self>.init(expected: Self.self, encountered: (identifier, function))
            }
        }
        
        public 
        var title:String 
        {
            switch self 
            {
            case .module:               return "Module"
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
        enum ID:Hashable, Comparable, Sendable 
        {
            case module(Module)
            case declaration(precise:String)
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
        // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/AvailabilityMixin.cpp
        public 
        enum Domain:String, Hashable  
        {
            case wildcard   = "*"
            case swift      = "Swift"
            case swiftpm    = "SwiftPM"
            
            case iOS 
            case macOS
            case macCatalyst
            case tvOS
            case watchOS
            case windows    = "Windows"
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
            var unavailable:Bool 
            // .some(nil) represents unconditional deprecation
            var deprecated:Entrapta.Version??
            var introduced:Entrapta.Version?
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
        
        var parameters:[Parameter]
        {
            switch self.kind 
            {
            case    .module, .case, .associatedtype, .typealias, .initializer, .deinitializer, 
                    .typeSubscript, .instanceSubscript, .typeProperty, .instanceProperty, 
                    .global, .enum, .struct, .class, .actor, .protocol:
                return []
            case    .typeMethod     (parameters: let parameters, returns: _),
                    .instanceMethod (parameters: let parameters, returns: _),
                    .function       (parameters: let parameters, returns: _),
                    .operator       (parameters: let parameters, returns: _):
                return parameters
            }
        }
        
        let extends:(module:String, where:[Language.Constraint])?
        let generic:(parameters:[Generic], constraints:[Language.Constraint])?
        let availability:[(key:Domain, value:Availability)]
        
        var comment:(text:String, processed:Entrapta.Comment)
        
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
            requirements:[(heading:Entrapta.Topic, indices:[Index])],
            members:[(heading:Entrapta.Topic, indices:[Index])]
        )
        
        init(module:Module, prefix:[String]) 
        {
            self.init(kind:    .module, 
                title:          module.name, 
                breadcrumbs:   .init(body: [], tail: module.title), 
                path:          .init(group: "/\((prefix + module.identifier).joined(separator: "/"))"), 
                in:             module, 
                declaration:    module.declaration)
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
            case .typealias:    keyword = "typealias"
            case .enum:         keyword = "enum"
            case .struct:       keyword = "struct"
            case .class:        keyword = "class"
            case .actor:        keyword = "actor"
            case .protocol:     keyword = "protocol"
            default:            keyword = nil 
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
            self.comment        = (comment, .init())
            
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
