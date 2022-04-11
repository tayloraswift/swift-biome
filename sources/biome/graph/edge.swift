import Grammar 
import JSON

extension SwiftConstraint where Link == Symbol.ID
{
    func map<T>(to transform:[Symbol.ID: T]) -> SwiftConstraint<T>
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
                // throw Biome.SymbolError.undefined(id: $0)
            }
        }
    }
}
extension Graph 
{
    enum EdgeError:Error 
    {
        case constraints(on:Int, is:Edge.Kind, of:Int)
        case polygamous(Int, is:Edge.Kind, of:Int, Int)
        case disputed(Edge, Edge)
    }
    
    struct Edge:Hashable 
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
        var source:Symbol.ID
        var target:Symbol.ID
        // if the source inherited docs 
        var origin:Symbol.ID?
        var constraints:[SwiftConstraint<Symbol.ID>]
        
        // only hash (source, kind, target)
        static 
        func == (lhs:Self, rhs:Self) -> Bool 
        {
            lhs.source == rhs.source && 
            lhs.kind   == rhs.kind && 
            lhs.target == rhs.target
        }
        func hash(into hasher:inout Hasher) 
        {
            self.source.hash(into: &hasher)
            self.kind.hash(into: &hasher)
            self.target.hash(into: &hasher)
        }
        
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
        }
    }
    static 
    func decode(edge json:JSON) throws -> Edge
    {
        try json.lint(["targetFallback"])
        {
            var kind:Edge.Kind = try $0.remove("kind") { try $0.case(of: Edge.Kind.self) }
            let target:Symbol.ID = try $0.remove("target", Self.decode(id:))
            let origin:Symbol.ID? = try $0.pop("sourceOrigin")
            {
                try $0.lint(["displayName"])
                {
                    try $0.remove("identifier", Self.decode(id:))
                }
            }
            let usr:Symbol.USR = try $0.remove("source")
            {
                let text:String = try $0.as(String.self)
                return try Grammar.parse(text.utf8, as: URI.Rule<String.Index, UInt8>.USR.self)
            }
            let source:Symbol.ID
            switch (kind, usr)
            {
            case (_,       .natural(let natural)): 
                source  = natural 
            // synthesized symbols can only be members of the type in their id
            case (.member, .synthesized(from: let generic, for: target)):
                source  = generic 
                kind    = .crime 
            case (_, let invalid):
                throw SymbolError.synthetic(resolution: invalid)
            }
            return .init(kind: kind, source: source, target: target, origin: origin, 
                constraints: try $0.pop("swiftConstraints", as: [JSON]?.self) 
                { 
                    try $0.map(Self.decode(constraint:)) 
                } ?? [])
        }
    }
}
