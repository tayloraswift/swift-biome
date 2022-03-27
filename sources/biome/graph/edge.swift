import Grammar 
import JSON

extension SwiftConstraint where Link == Biome.Symbol.ID
{
    func map<T>(to transform:[Biome.Symbol.ID: T]) -> SwiftConstraint<T>
    {
        // TODO: turn this back into a `map` when we can enforce this again 
        //try self.map 
        self.flatMap 
        {
            if let transformed:T = transform[$0]
            {
                return transformed 
            }
            else 
            {
                return nil
                // throw Biome.SymbolIdentifierError.undefined(id: $0)
            }
        }
    }
}
extension Graph 
{
    enum EdgeError:Error 
    {
        case constraints(on:Int, is:Edge.Kind, of:Int)
        case duplicate(Int, have:Int, is:Edge.Kind, of:Int)
    }
    
    struct Edge 
    {
        struct References 
        {
            let parent:Int?, 
                module:Int?, 
                bystander:Int?
            
            var members:[Int], 
                crimes:[Int],
            
                defaultImplementationOf:[Int], 
                defaultImplementations:[Int], 
                
                overrideOf:Int?,
                overrides:[Int],
                
                sponsor:Int?,
                //specializationOf:Int?,
                //specializations:[Int],
                
                requirementOf:Int?,
                requirements:[Int],
                
                upstream:[(index:Int, conditions:[SwiftConstraint<Int>])], // protocols this type conforms to
                downstream:[(index:Int, conditions:[SwiftConstraint<Int>])], // types that conform to this type 
                subclasses:[Int],
                superclass:Int?
            
            init(parent:Int?, module:Int?, bystander:Int?) 
            {
                self.parent                     = parent
                self.module                     = module
                self.bystander                  = bystander
                self.members                    = []
                self.crimes                     = []
                self.defaultImplementationOf    = []
                self.defaultImplementations     = []
                self.overrideOf                 = nil
                self.overrides                  = []
                self.sponsor                    = nil
                // self.specializationOf           = nil
                // self.specializations            = []
                self.requirementOf              = nil
                self.requirements               = []
                self.upstream                   = []
                self.downstream                 = []
                self.subclasses                 = []
                self.superclass                 = nil
            }
        }
        // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/Edge.h
        enum Kind:String
        {
            case crime // like `member`, but for synthetic members
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
        var source:Biome.Symbol.ID
        var target:Biome.Symbol.ID
        // if the source inherited docs 
        var origin:Biome.Symbol.ID?
        var constraints:[SwiftConstraint<Biome.Symbol.ID>]
        
        /* init(specialization source:Biome.Symbol.ID, of target:Biome.Symbol.ID)
        {
            self.kind = .specialization 
            self.source = source 
            self.target = target 
            self.origin = nil 
            self.constraints = []
        } */
        
        func link(_ table:inout [References], indices:[Biome.Symbol.ID: Int]) throws 
        {
            guard let source:Int = indices[self.source]
            else 
            {
                throw SymbolIdentifierError.undefined(id: self.source)
            } 
            guard let target:Int = indices[self.target]
            else 
            {
                throw SymbolIdentifierError.undefined(id: self.target)
            } 
            let constraints:[SwiftConstraint<Int>] = self.constraints.map 
            {
                $0.map(to: indices)
            }
            // even after inferring the existence of mythical symbols, it’s still 
            // possible for the documentation origin to be unknown to us. this 
            // is fine, as we need a copy of the inherited docs anyways.
            if  let origin:Biome.Symbol.ID  = self.origin, 
                let origin:Int              = indices[origin]
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
                    throw EdgeError.duplicate(source, have: incumbent, is: self.kind, of: target)
                }
                table[source].superclass = target
                table[target].subclasses.append(source)
                
            case .optionalRequirement, .requirement:
                if let incumbent:Int = table[source].requirementOf
                {
                    throw EdgeError.duplicate(source, have: incumbent, is: self.kind, of: target)
                }
                table[source].requirementOf = target
                table[target].requirements.append(source)
            
            case .override:
                if let incumbent:Int = table[source].overrideOf
                {
                    throw EdgeError.duplicate(source, have: incumbent, is: self.kind, of: target)
                }
                table[source].overrideOf = target 
                table[target].overrides.append(source)
                
            case .defaultImplementation:
                table[source].defaultImplementationOf.append(target)
                table[target].defaultImplementations.append(source)
            }
        }
    }
    static 
    func decode(edge json:JSON) throws -> Edge
    {
        try json.lint(["targetFallback"])
        {
            var kind:Edge.Kind = try $0.remove("kind") { try $0.case(of: Edge.Kind.self) }
            let target:Biome.Symbol.ID = try $0.remove("target", Self.decode(id:))
            let origin:Biome.Symbol.ID? = try $0.pop("sourceOrigin")
            {
                try $0.lint(["displayName"])
                {
                    try $0.remove("identifier", Self.decode(id:))
                }
            }
            let usr:Biome.USR = try $0.remove("source")
            {
                let text:String = try $0.as(String.self)
                return try Grammar.parse(text.utf8, as: Biome.USR.Rule<String.Index>.self)
            }
            let source:Biome.Symbol.ID
            switch (kind, usr)
            {
            case (_,       .natural(let natural)): 
                source  = natural 
            // synthesized symbols can only be members of the type in their id
            case (.member, .synthesized(from: let generic, for: target)):
                source  = generic 
                kind    = .crime 
            case (_, let invalid):
                throw SymbolIdentifierError.synthetic(resolution: invalid)
            }
            return .init(kind: kind, source: source, target: target, origin: origin, 
                constraints: try $0.pop("swiftConstraints", as: [JSON]?.self) 
                { 
                    try $0.map(Self.decode(constraint:)) 
                } ?? [])
        }
    }
}
