import JSON 

enum SwiftLanguage 
{
    struct Lexeme 
    {
        enum Kind:String 
        {
            // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/DeclarationFragmentPrinter.cpp
            case keyword    = "keyword"
            case attribute  = "attribute"
            case number     = "number"
            case string     = "string"
            case identifier = "identifier"
            case type       = "typeIdentifier"
            case generic    = "genericParameter"
            case parameter  = "internalParam"
            case label      = "externalParam"
            case text       = "text"
        }
        
        let text:String 
        let kind:Kind
        let reference:String?
    }
}
extension SwiftLanguage.Lexeme:Codable 
{
    enum CodingKeys:String, CodingKey 
    {
        case text       = "spelling"
        case kind       = "kind"
        case reference  = "preciseIdentifier"
    }
}
extension SwiftLanguage.Lexeme.Kind:Codable 
{
}

public 
enum Entrapta 
{
    enum Topic:Hashable, CustomStringConvertible 
    {
        case kind(Entrapta.Graph.Symbol.Kind)
        case custom(String)
        case cluster(String)
        
        var description:String 
        {
            switch self 
            {
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
        init(prefix:String, modules:[(module:Symbol.Module, json:[JSON])]) throws 
        {
            var symbols:[Symbol.ID: Symbol] = [:]
            for (module, json):(Symbol.Module, [JSON]) in modules
            {
                let root:Symbol = .init(prefix: prefix, module: module)
                if case _? = symbols.updateValue(root, forKey: .module(module))
                {
                    print("warning: duplicate module '\(module.description)'")
                }
                
                for json:JSON in json 
                {
                    let descriptor:Descriptor.Symbol = try .init(from: json)
                    let symbol:Symbol   = .init(prefix: prefix, declaration: descriptor, in: module), 
                        id:Symbol.ID    = .declaration(precise: descriptor.id)
                    guard case nil = symbols.updateValue(symbol, forKey: id)
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
        init(prefix:String, modules json:[JSON]) throws
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
                    throw GraphDecodingError.init()
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
            
            for (module, json):(Symbol.Module, [JSON]) in edges 
            {
                for json:JSON in json
                {
                    let descriptor:Descriptor.Edge = try .init(from: json)
                    
                    let source:Symbol.ID = .declaration(precise: descriptor.source)
                    let target:Symbol.ID = .declaration(precise: descriptor.target)
                    
                    switch 
                    (
                        self.symbols.index(forKey: source),
                        is: descriptor.kind,
                        of: self.symbols.index(forKey: target)
                    )
                    {
                    case (let symbol?, is: .member, of: let parent?): 
                        self[symbol].parent = parent
                        self[parent].members.append(symbol)
                    
                    case (let symbol?, is: .conformer, of: let destination?):
                        break
                    case (let symbol?, is: .subclass, of: let destination?):
                        break
                    case (let symbol?, is: .override, of: let destination?):
                        break
                    case (let symbol?, is: .requirement, of: let destination?):
                        break
                    case (let symbol?, is: .optionalRequirement, of: let destination?):
                        break
                    case (let symbol?, is: .defaultImplementation, of: let destination?):
                        break
                    case (nil, is: _, of: _): 
                        print("warning: undefined symbol id '\(source)'")
                    case (_, is: _, of: nil): 
                        print("warning: undefined symbol id '\(target)'")
                    }
                }
            }
            
            // if a symbol has no declaration as its parent, it is a top-level 
            // symbol, and its parent is its module. 
            for index:Index in self.symbols.indices 
            {
                guard   case nil = self[index].parent, 
                        case .declaration = self[index].kind, 
                        let parent:Index = self.symbols.index(forKey: .module(self[index].module))
                else 
                {
                    continue 
                }
                self[index].parent = parent
                self[parent].members.append(index)
            }
            
            self.populateTopics()
        }
        
        mutating 
        func populateTopics() 
        {
            for index:Index in self.symbols.indices 
            {
                let topics:[Entrapta.Graph.Symbol.Kind: [Index]] = 
                    .init(grouping: self[index].members)
                {
                    self[$0].kind
                }
                for kind:Entrapta.Graph.Symbol.Kind in Entrapta.Graph.Symbol.Kind.allCases 
                {
                    guard let members:[Index] = topics[kind]
                    else 
                    {
                        continue 
                    }
                    self[index].topics.append((.kind(kind), members))
                }
            }
        }
    }
}
extension Entrapta.Graph 
{
    public 
    struct Symbol 
    {
        public 
        enum Module:Hashable, Sendable, CustomStringConvertible
        {
            case swift 
            case framework(String, package:String)
            
            public 
            var name:String 
            {
                switch self 
                {
                case .swift:                                return "swift"
                case .framework(let module, package: _):    return module
                }
            }
            public 
            var description:String 
            {
                switch self 
                {
                case .swift:                                        return "swift"
                case .framework(let module, package: let package):  return "\(package.lowercased())/\(module.lowercased())"
                }
            }
        }
        public 
        enum ID:Hashable, Sendable 
        {
            case declaration(precise:String)
            case module(Module)
        }
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
            // lowercases all path components 
            init(prefix:String, components:[String], disambiguation:ID? = nil)
            {
                self.group          = "\(prefix)/\(components.joined(separator: "/").lowercased())"
                self.disambiguation = disambiguation
            }
            init(group:String, disambiguation:ID? = nil)
            {
                self.group          = group
                self.disambiguation = disambiguation
            }
        }
        
        let module:Module
        var path:Path
        
        let title:String 
        let kind:Kind
        let signature:[SwiftLanguage.Lexeme]
        let declaration:[SwiftLanguage.Lexeme]
        
        let discussion:String
        
        var parent:Index?
        var members:[Index]
        
        var topics:[(key:Entrapta.Topic, members:[Index])]
        
        init(prefix:String, module:Module) 
        {
            self.module         = module 
            self.path           = .init(group: "\(prefix)/\(module.description)")
            self.title          = module.name 
            self.kind           = .module 
            self.signature      = []
            self.declaration    = []
            self.discussion     = ""
            self.parent         = nil 
            self.members        = []
            self.topics         = []
        }
        init(prefix:String, declaration descriptor:Entrapta.Descriptor.Symbol, in module:Module) 
        {
            self.module         = module 
            self.path           = .init(prefix: prefix, components: [module.description] + descriptor.path)
            self.title          = descriptor.display.title 
            self.kind           = .declaration(descriptor.kind)
            self.signature      = descriptor.display.subtitle
            self.declaration    = descriptor.declaration
            self.discussion     = descriptor.comment.joined(separator: "\n")
            self.parent         = nil 
            self.members        = []
            self.topics         = []
        }
    }
}
extension Entrapta.Graph.Symbol 
{
    enum Kind:Hashable, CaseIterable, CustomStringConvertible 
    {
        enum Declaration:String, Hashable, CaseIterable, Codable 
        {    
            case enumerationCase    = "swift.enum.case"
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
            
            case global             = "swift.var"
            case function           = "swift.func"
            case `operator`         = "swift.func.op"
            case enumeration        = "swift.enum"
            case structure          = "swift.struct"
            case `class`            = "swift.class"
            case `protocol`         = "swift.protocol"
        }
        
        case declaration(Declaration)
        case module 
        
        static 
        var allCases:[Self]
        {
            Declaration.allCases.map(Self.declaration(_:)) + CollectionOfOne<Self>.init(.module)
        }
        
        var description:String 
        {
            switch self 
            {
            case .module:                   return "Module"
            case .declaration(let kind):
                switch kind 
                {
                case .enumerationCase:      return "Enumeration Case"
                case .`associatedtype`:     return "Associated Type"
                case .`typealias`:          return "Typealias"
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
                case .`operator`:           return "Operator"
                case .enumeration:          return "Enumeration"
                case .structure:            return "Structure"
                case .`class`:              return "Class"
                case .`protocol`:           return "Protocol"
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
                case .enumerationCase:      return "Enumeration Cases"
                case .`associatedtype`:     return "Associated Types"
                case .`typealias`:          return "Typealiases"
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
                case .`operator`:           return "Operators"
                case .enumeration:          return "Enumerations"
                case .structure:            return "Structures"
                case .`class`:              return "Classes"
                case .`protocol`:           return "Protocols"
                }
            }
        }
    }
}
