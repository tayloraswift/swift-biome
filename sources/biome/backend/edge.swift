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
                
                upstream:[(index:Int, conditions:[SwiftLanguage.Constraint<Symbol.ID>])], // protocols this type conforms to
                downstream:[(index:Int, conditions:[SwiftLanguage.Constraint<Symbol.ID>])], // types that conform to this type 
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
        var constraints:[SwiftLanguage.Constraint<Symbol.ID>]
        
        /* init(specialization source:Symbol.ID, of target:Symbol.ID)
        {
            self.kind = .specialization 
            self.source = source 
            self.target = target 
            self.origin = nil 
            self.constraints = []
        } */
        
        func link(_ source:Int, to target:Int, origin:Int?, in table:inout [References]) throws 
        {
            switch self.kind
            {
            case .member: 
                guard self.constraints.isEmpty 
                else 
                {
                    throw LinkingError.constraints(on: source, is: self.kind, of: target)
                }
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
                table[source].upstream.append((target, self.constraints))
                table[target].downstream.append((source, self.constraints))
            
            case .subclass:
                guard self.constraints.isEmpty 
                else 
                {
                    throw LinkingError.constraints(on: source, is: self.kind, of: target)
                }
                if let incumbent:Int = table[source].superclass
                {
                    throw LinkingError.duplicate(source, have: incumbent, is: self.kind, of: target)
                }
                table[source].superclass = target
                table[target].subclasses.append(source)
                
            case .optionalRequirement, .requirement:
                guard self.constraints.isEmpty 
                else 
                {
                    throw LinkingError.constraints(on: source, is: self.kind, of: target)
                }
                if let incumbent:Int = table[source].requirementOf
                {
                    throw LinkingError.duplicate(source, have: incumbent, is: self.kind, of: target)
                }
                table[source].requirementOf = target
                table[target].requirements.append(source)
            
            case .override:
                guard self.constraints.isEmpty 
                else 
                {
                    throw LinkingError.constraints(on: source, is: self.kind, of: target)
                }
                if let incumbent:Int = table[source].overrideOf
                {
                    throw LinkingError.duplicate(source, have: incumbent, is: self.kind, of: target)
                }
                table[source].overrideOf = target 
                table[target]._overrides.append(source)
                
            case .defaultImplementation:
                guard self.constraints.isEmpty 
                else 
                {
                    throw LinkingError.constraints(on: source, is: self.kind, of: target)
                }
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
