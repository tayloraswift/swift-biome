import Highlight

struct Symbol:Sendable, Identifiable  
{
    enum LinkingError:Error 
    {
        case members([Int], in:Kind, Int) 
        case crimes([Int], in:Kind, Int) 
        case conformers([(index:Int, conditions:[SwiftConstraint<Int>])], in:Kind, Int) 
        case conformances([(index:Int, conditions:[SwiftConstraint<Int>])], in:Kind, Int) 
        case requirements([Int], in:Kind, Int) 
        case subclasses([Int], in:Kind, Int) 
        case superclass(Int, in:Kind, Int) 
        
        case defaultImplementationOf([Int], Kind, Int) 
        case requirementOf(Int, Kind, Int) 
        case overrideOf(Int, Kind, Int) 
        
        case island(associatedtype:Int)
        case orphaned(symbol:Int)
        //case junction(symbol:Int)
    }
    enum AccessLevel:String, Sendable
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
    let sponsor:Int?
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
    let platforms:[Biome.Domain: Availability]
    
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
        size += MemoryLayout<(Biome.Domain, Availability)>.stride * self.platforms.capacity
        
        size += self.relationships._heapSize
        return size
    }
    
    init(modules:Biome.Storage<Module>, indices:[Symbol.ID: Int],
        vertex:Graph.Vertex,
        edges:Graph.Edge.References, 
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
        self.sponsor        = edges.sponsor
        
        self.signature      = vertex.signature
        self.declaration    = vertex.declaration.compactMapLinks 
        {
            // TODO: emit warning
            indices[$0]
        }
        self.relationships  = relationships
        
        if let extended:Module.ID   = vertex.extension?.extendedModule
        {
            guard let extended:Int  = modules.index(of: extended)
            else 
            {
                throw Graph.ModuleError.undefined(id: extended)
            }
            if  extended != self.module
            {
                switch self.bystander
                {
                case nil, extended?: 
                    break 
                case let bystander?:
                    throw Graph.ModuleError.mismatchedExtension(
                        id: modules[extended].id, expected: modules[bystander].id, 
                        in: self.id)
                }
            }
        }
        self.generics               = vertex.generics?.parameters ?? []
        self.genericConstraints     = vertex.generics?.constraints.map 
        {
            $0.map(to: indices)
        } ?? []
        self.extensionConstraints   = vertex.extension?.constraints.map
        {
            $0.map(to: indices)
        } ?? []
        
        var platforms:[Biome.Domain: Availability] = [:]
        var availability:(unconditional:UnconditionalAvailability?, swift:SwiftAvailability?) = (nil, nil)
        for (domain, value):(Biome.Domain, Availability) in vertex.availability 
        {
            switch domain 
            {
            case .wildcard:
                guard case nil = availability.unconditional 
                else 
                {
                    throw Graph.AvailabilityError.duplicate(domain: domain, in: self.id)
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
                    throw Graph.AvailabilityError.duplicate(domain: domain, in: self.id)
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
                    throw Graph.AvailabilityError.duplicate(domain: domain, in: self.id)
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
