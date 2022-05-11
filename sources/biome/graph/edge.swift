import Grammar 
import JSON

struct Edge:Hashable, Sendable
{
    // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/Edge.h
    enum Kind:String, Sendable
    {
        case feature                = "_featureOf"
        case member                 = "memberOf"
        case conformer              = "conformsTo"
        case subclass               = "inheritsFrom"
        case override               = "overrides"
        case requirement            = "requirementOf"
        case optionalRequirement    = "optionalRequirementOf"
        case defaultImplementation  = "defaultImplementationOf"
    }
    // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/Edge.cpp
    var kind:Kind
    var source:Symbol.ID
    var target:Symbol.ID
    var origin:Symbol.ID?
    var constraints:[Generic.Constraint<Symbol.ID>]
    
    /*
    func link(_ table:inout [References], indices:[Symbol.ID: Int]) throws 
    {
        guard let source:Int = indices[self.source]
        else 
        {
            throw SymbolError.undefined(id: self.source)
        } 
        guard let target:Int = indices[self.target]
        else 
        {
            throw SymbolError.undefined(id: self.target)
        } 
        let constraints:[SwiftConstraint<Int>] = self.constraints.map 
        {
            $0.map(to: indices)
        }
        // even after inferring the existence of mythical symbols, it’s still 
        // possible for the documentation origin to be unknown to us. this 
        // is fine, as we need a copy of the inherited docs anyways.
        if  let origin:Symbol.ID = self.origin, 
            let origin:Int = indices[origin]
        {
            if let incumbent:Int = table[source].sponsor
            {
                // origin is allowed to duplicate, as long as the index is the same 
                guard incumbent == origin
                else 
                {
                    fatalError("unimplemented")
                }
            }
            else if origin != source 
            {
                table[source].sponsor = origin
            }
            // `vertices[source].id` is not necessarily synthesized, 
            // because it could be an inherited `associatedtype`, which does 
            // not contain '::SYNTHESIZED::'
        }
        
        try self.link(source, to: target, constraints: constraints, in: &table)
    }
    private  
    func link(_ source:Int, to target:Int, constraints:[SwiftConstraint<Int>], 
        in table:inout [References]) throws 
    {
        if constraints.isEmpty
        {
            try self.link(source, to: target, in: &table)
        }
        else 
        {
            // only `conformer` edges can have constraints 
            guard case .conformer = self.kind 
            else 
            {
                throw EdgeError.constraints(on: source, is: self.kind, of: target)
            }
            table[source].upstream.append((target, constraints))
            table[target].downstream.append((source, constraints))
        }
    }
    private  
    func link(_ source:Int, to target:Int, in table:inout [References]) throws 
    {
        switch self.kind
        {
        case .crime: 
            table[target].crimes.append(source)
        case .member: 
            guard case target? = table[source].parent 
            else 
            {
                fatalError("natural declaration is not member of parent")
            }
            table[target].members.append(source)
        
        case .conformer:
            table[source].upstream.append((target, []))
            table[target].downstream.append((source, []))
        
        case .subclass:
            if let incumbent:Int = table[source].superclass
            {
                throw EdgeError.polygamous(source, is: self.kind, of: incumbent, target)
            }
            table[source].superclass = target
            table[target].subclasses.append(source)
            
        case .optionalRequirement, .requirement:
            if let incumbent:Int = table[source].requirementOf
            {
                throw EdgeError.polygamous(source, is: self.kind, of: incumbent, target)
            }
            table[source].requirementOf = target
            table[target].requirements.append(source)
        
        case .override:
            if let incumbent:Int = table[source].overrideOf
            {
                throw EdgeError.polygamous(source, is: self.kind, of: incumbent, target)
            }
            table[source].overrideOf = target 
            table[target].overrides.append(source)
            
        case .defaultImplementation:
            table[source].defaultImplementationOf.append(target)
            table[target].defaultImplementations.append(source)
        }
    } */
}
extension Edge 
{
    init(from json:JSON) throws
    {
        (self.kind, self.origin, source: self.source, target: self.target, self.constraints) = 
            try json.lint(["targetFallback"])
        {
            var kind:Edge.Kind = try $0.remove("kind") { try $0.case(of: Edge.Kind.self) }
            let target:Symbol.ID = try $0.remove("target", Symbol.ID.init(from:))
            let origin:Symbol.ID? = try $0.pop("sourceOrigin")
            {
                try $0.lint(["displayName"])
                {
                    try $0.remove("identifier", Symbol.ID.init(from:))
                }
            }
            let usr:Symbol.USR = try $0.remove("source")
            {
                let text:String = try $0.as(String.self)
                return try Grammar.parse(text.utf8, as: Symbol.USR.Rule<String.Index>.self)
            }
            let source:Symbol.ID
            switch (kind, usr)
            {
            case (_,       .natural(let natural)): 
                source  = natural 
            // synthesized symbols can only be members of the type in their id
            case (.member, .synthesized(from: let generic, for: target)):
                source  = generic 
                kind    = .feature 
            case (_, _):
                fatalError("unimplemented")
                //throw SymbolError.synthetic(resolution: invalid)
            }
            return 
                (
                    kind: kind, origin: origin, source: source, target: target, 
                    constraints: try $0.pop("swiftConstraints", as: [JSON]?.self) 
                    { 
                        try $0.map(Generic.Constraint.init(from:)) 
                    } ?? []
                )
        }
    }
}
