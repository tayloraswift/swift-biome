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
                // throw Biome.SymbolIdentifierError.undefined(symbol: $0)
            }
        }
    }
}

extension Biome 
{
    struct Edge 
    {
        struct References 
        {
            var members:[Int], 
            
                defaultImplementationOf:[Int], 
                defaultImplementations:[Int], 
                
                overrideOf:Int?,
                _overrides:[Int],
                
                sourceOrigin:Int?,
                //specializationOf:Int?,
                //specializations:[Int],
                
                requirementOf:Int?,
                requirements:[Int],
                
                upstream:[(index:Int, conditions:[SwiftConstraint<Int>])], // protocols this type conforms to
                downstream:[(index:Int, conditions:[SwiftConstraint<Int>])], // types that conform to this type 
                subclasses:[Int],
                superclass:Int?
            
            init() 
            {
                self.members                    = []
                self.defaultImplementationOf    = []
                self.defaultImplementations     = []
                self.overrideOf                 = nil
                self._overrides                 = []
                self.sourceOrigin               = nil
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
            case member                 = "memberOf"
            case conformer              = "conformsTo"
            case subclass               = "inheritsFrom"
            case override               = "overrides"
            case requirement            = "requirementOf"
            case optionalRequirement    = "optionalRequirementOf"
            case defaultImplementation  = "defaultImplementationOf"
            
            // extras 
            // case specialization 
        }
        // https://github.com/apple/swift/blob/main/lib/SymbolGraphGen/Edge.cpp
        var kind:Kind 
        var source:Symbol.ID 
        var target:Symbol.ID
        // if the source inherited docs 
        var origin:(id:Symbol.ID, name:String)?
        var constraints:[SwiftConstraint<Symbol.ID>]
        
        /* init(specialization source:Symbol.ID, of target:Symbol.ID)
        {
            self.kind = .specialization 
            self.source = source 
            self.target = target 
            self.origin = nil 
            self.constraints = []
        } */
        
        func link(_ table:inout [References], indices:[Symbol.ID: Int]) throws 
        {
            guard let source:Int = indices[self.source]
            else 
            {
                throw SymbolIdentifierError.undefined(symbol: self.source)
            }
            guard let target:Int = indices[self.target]
            else 
            {
                throw SymbolIdentifierError.undefined(symbol: self.target)
            } 
            let constraints:[SwiftConstraint<Int>] = self.constraints.map 
            {
                $0.map(to: indices)
            }
            if let origin:Symbol.ID     = self.origin?.id
            {
                /* guard let origin:Int    = indices[origin]
                else 
                {
                    throw SymbolIdentifierError.undefined(symbol: origin)
                } */
                // `vertices[source].id` is not necessarily synthesized, 
                // because it could be an inherited `associatedtype`, which does 
                // not contain '::SYNTHESIZED::'
                try self.link(source, to: target, origin: indices[origin], constraints: constraints, 
                    in: &table)
            }
            else 
            {
                try self.link(source, to: target, origin: nil,    constraints: constraints, 
                    in: &table)
            }
        }
        private  
        func link(_ source:Int, to target:Int, origin:Int?, 
            constraints:[SwiftConstraint<Int>], 
            in table:inout [References]) throws 
        {
            if constraints.isEmpty
            {
                try self.link(source, to: target, origin: origin, in: &table)
            }
            else 
            {
                // only `conformer` edges can have constraints 
                guard case .conformer = self.kind 
                else 
                {
                    throw LinkingError.constraints(on: source, is: self.kind, of: target)
                }
                table[source].upstream.append((target, constraints))
                table[target].downstream.append((source, constraints))
            }
        }
        private  
        func link(_ source:Int, to target:Int, origin:Int?, in table:inout [References]) throws 
        {
            switch self.kind
            {
            case .member: 
                table[target].members.append(source)
                guard let origin:Int = origin
                else 
                {
                    break 
                }
                if let incumbent:Int = table[source].sourceOrigin
                {
                    throw LinkingError.duplicate(source, have: incumbent, is: self.kind, of: target)
                }
                table[source].sourceOrigin = origin
            
            case .conformer:
                table[source].upstream.append((target, []))
                table[target].downstream.append((source, []))
            
            case .subclass:
                if let incumbent:Int = table[source].superclass
                {
                    throw LinkingError.duplicate(source, have: incumbent, is: self.kind, of: target)
                }
                table[source].superclass = target
                table[target].subclasses.append(source)
                
            case .optionalRequirement, .requirement:
                if let incumbent:Int = table[source].requirementOf
                {
                    throw LinkingError.duplicate(source, have: incumbent, is: self.kind, of: target)
                }
                table[source].requirementOf = target
                table[target].requirements.append(source)
            
            case .override:
                if let incumbent:Int = table[source].overrideOf
                {
                    throw LinkingError.duplicate(source, have: incumbent, is: self.kind, of: target)
                }
                table[source].overrideOf = target 
                table[target]._overrides.append(source)
                
            case .defaultImplementation:
                table[source].defaultImplementationOf.append(target)
                table[target].defaultImplementations.append(source)
            
            // inferred edges 
            /* case .specialization:
                guard self.constraints.isEmpty 
                else 
                {
                    fatalError("unreachable")
                }
                if let incumbent:Int = table[source].specializationOf
                {
                    throw LinkingError.duplicate(source, have: incumbent, is: self.kind, of: target)
                }
                table[source].specializationOf = target
                table[target].specializations.append(source) */
            }
        }
    }
}
