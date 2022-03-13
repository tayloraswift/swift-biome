import Highlight

extension Biome 
{
    struct Symbol:Sendable, Identifiable  
    {        
        let id:ID
        // symbol may be mythical, in which case it will not have a module
        let module:Int? 
        let bystander:Int? 
        var namespace:Int? 
        {
            self.bystander ?? self.module
        }
        /// This symbol’s canonical parent. If the symbol is a protocol extension 
        /// member, this points to the protocol.
        let parent:Int?
        let commentOrigin:Int?
        let relationships:Relationships
        /// The original scope this symbol was defined in. 
        let scope:[String]
        let title:String 
        let signature:Notebook<SwiftHighlight, Never>
        let declaration:Notebook<SwiftHighlight, Int>
        
        let generics:[Generic], 
            genericConstraints:[SwiftConstraint<Int>], 
            extensionConstraints:[SwiftConstraint<Int>]
        let availability:
        (
            unconditional:UnconditionalAvailability?, 
            swift:SwiftAvailability?
        )
        let platforms:[Domain: Availability]
        
        // var topics:
        // (
        //     requirements:[(heading:Biome.Topic, indices:[Int])],
        //     members:[(heading:Biome.Topic, indices:[Int])],
        //     removed:[(heading:Biome.Topic, indices:[Int])]
        // )
        
        var _size:Int 
        {
            var size:Int = MemoryLayout<Self>.stride 
            size += self.id.string.utf8.count
            size += MemoryLayout<String>.stride * self.scope.count
            size += self.scope.reduce(0) { $0 + $1.utf8.count }
            size += self.title.utf8.count
            
            size += MemoryLayout<UInt64>.stride * self.signature.content.elements.count
            size += self.signature.content.storage.utf8.count
            
            size += MemoryLayout<UInt64>.stride * self.declaration.content.elements.count
            size += self.declaration.content.storage.utf8.count
            
            size += MemoryLayout<Generic>.stride * self.generics.count
            size += MemoryLayout<SwiftConstraint<Int>>.stride * self.genericConstraints.count
            size += MemoryLayout<SwiftConstraint<Int>>.stride * self.extensionConstraints.count
            size += MemoryLayout<(Domain, Availability)>.stride * self.platforms.capacity
            
            size += self.relationships._heapSize
            return size
        }
        
        init(modules:Storage<Module>, indices:[Symbol.ID: Int],
            vertex:Vertex,
            edges:Edge.References, 
            relationships:Relationships) 
            throws 
        {
            self.id             = vertex.id
            self.module         = edges.module 
            self.bystander      = edges.bystander
            
            var scope:[String]  = vertex.path
            self.title          = scope.removeLast()
            self.scope          = scope 
            self.parent         = edges.parent
            self.commentOrigin  = edges.commentOrigin
            
            self.signature      = vertex.signature
            self.declaration    = vertex.declaration.compactMapLinks 
            {
                // TODO: emit warning
                indices[$0]
            }
            self.relationships  = relationships
            
            if let extended:Module.ID   = vertex.extends?.module
            {
                guard let extended:Int  = modules.index(of: extended)
                else 
                {
                    throw ModuleIdentifierError.undefined(module: extended)
                }
                if  extended != self.module
                {
                    switch self.bystander
                    {
                    case nil, extended?: 
                        break 
                    case let bystander?:
                        throw SymbolExtensionError.mismatch(decoded: modules[extended].id, expected: modules[bystander].id, in: self.id)
                    }
                }
            }
            self.generics               = vertex.generic?.parameters ?? []
            self.genericConstraints     = vertex.generic?.constraints.map 
            {
                $0.map(to: indices)
            } ?? []
            self.extensionConstraints   = vertex.extends?.where.map
            {
                $0.map(to: indices)
            } ?? []
            
            var platforms:[Domain: Availability] = [:]
            var availability:(unconditional:UnconditionalAvailability?, swift:SwiftAvailability?) = (nil, nil)
            for (domain, value):(Domain, Availability) in vertex.availability 
            {
                switch domain 
                {
                case .wildcard:
                    guard case nil = availability.unconditional 
                    else 
                    {
                        throw SymbolAvailabilityError.duplicate(domain: domain, in: self.id)
                    }
                    let deprecated:Bool 
                    if case .some(nil) = value.deprecated 
                    {
                        deprecated = true 
                    }
                    else 
                    {
                        deprecated = false 
                    }
                    availability.unconditional = .init(unavailable: value.unavailable, 
                        deprecated: deprecated, 
                        renamed: value.renamed, 
                        message: value.message)
                case .swift:
                    guard case nil = availability.swift 
                    else 
                    {
                        throw SymbolAvailabilityError.duplicate(domain: domain, in: self.id)
                    }
                    availability.swift = .init(
                        deprecated: value.deprecated ?? nil, 
                        obsoleted: value.obsoleted,
                        renamed: value.renamed, 
                        message: value.message)
                default:
                    guard case nil = platforms.updateValue(value, forKey: domain)
                    else 
                    {
                        throw SymbolAvailabilityError.duplicate(domain: domain, in: self.id)
                    }
                }
            }
            self.availability   = availability
            self.platforms      = platforms
            // self.topics         = ([], [], [])
        }
        
        var kind:Kind 
        {
            switch self.relationships 
            {
            case .typealias:        return .typealias
            case .enum:             return .enum
            case .struct:           return .struct
            case .class:            return .class
            case .actor:            return .actor
            case .protocol:         return .protocol
            case .associatedtype:   return .associatedtype
            case .witness(_, callable: let  callable):
                switch callable 
                {
                case .subscript (instance: true,    parameters: _, returns: _): return .instanceSubscript
                case .subscript (instance: false,   parameters: _, returns: _): return .typeSubscript
                case .func      (instance: true?,   parameters: _, returns: _): return .instanceMethod
                case .func      (instance: false?,  parameters: _, returns: _): return .typeMethod
                case .func      (instance: nil,     parameters: _, returns: _): return .func
                case .var(instance: true?):         return .instanceProperty
                case .var(instance: false?):        return .typeProperty
                case .var(instance: nil):           return .var
                case .operator:                     return .operator
                case .case:                         return .case
                case .initializer:                  return .initializer
                case .deinitializer:                return .deinitializer
                }
            }
        }
    }
}
extension Biome.Symbol 
{
    enum Kind:String, Sendable, Hashable
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
        
        case `var`              = "swift.var"
        case `func`             = "swift.func"
        case `operator`         = "swift.func.op"
        case `enum`             = "swift.enum"
        case `struct`           = "swift.struct"
        case `class`            = "swift.class"
        case  actor             = "swift.actor"
        case `protocol`         = "swift.protocol"
        
        public 
        var topic:Documentation.Topic.Automatic
        {
            switch self 
            {
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
            case .var:                  return .global
            case .func:                 return .function
            case .operator:             return .operator
            case .enum:                 return .enum
            case .struct:               return .struct
            case .class:                return .class
            case .actor:                return .actor
            case .protocol:             return .protocol
            }
        }
        
        var title:String 
        {
            switch self 
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
            case .var:                  return "Global Variable"
            case .func:                 return "Function"
            case .operator:             return "Operator"
            case .enum:                 return "Enumeration"
            case .struct:               return "Structure"
            case .class:                return "Class"
            case .actor:                return "Actor"
            case .protocol:             return "Protocol"
            }
        }
    }
    enum Access:Sendable
    {
        case `private` 
        case `fileprivate`
        case `internal`
        case `public`
        case `open`
    }

    /* public 
    struct Parameter:Sendable
    {
        var label:String 
        var name:String?
        // var fragment:[SwiftLanguage.Lexeme<ID>]
    } */
    struct Generic:Hashable, Sendable
    {
        var name:String 
        var index:Int 
        var depth:Int 
    }
}
