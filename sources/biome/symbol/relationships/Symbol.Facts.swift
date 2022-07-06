extension Symbol 
{
    typealias Statement = (subject:Index, predicate:Predicate)
    
    enum Predicate 
    {
        case `is`(Role)
        case has(Trait)
    }
    struct Predicates:Equatable, Sendable 
    {
        let roles:Roles?
        let primary:Traits
        private(set)
        var accepted:[Module.Index: Traits]
        
        init(roles:Roles?, primary:Traits = .init())
        {
            self.roles = roles 
            self.primary = primary
            self.accepted = [:]
        }
        
        mutating 
        func updateAcceptedTraits(_ traits:Traits, culture:Module.Index)
        {
            self.accepted[culture] = traits.subtracting(self.primary)
        }
        
        func featuresAssumingConcreteType() -> [(perpetrator:Module.Index?, features:Set<Index>)]
        {
            var features:[(perpetrator:Module.Index?, features:Set<Index>)] = []
            if !self.primary.features.isEmpty
            {
                features.append((nil, self.primary.features))
            }
            for (perpetrator, traits):(Module.Index, Traits) in self.accepted
                where !traits.features.isEmpty
            {
                features.append((perpetrator, traits.features))
            }
            return features
        }
    }
    struct Facts
    {
        var shape:Shape?
        var predicates:Predicates
        
        init(traits:[Trait], roles:[Role], as color:Color) throws 
        {
            self.shape = nil 
            // partition relationships buffer 
            var superclass:Index? = nil 
            var residuals:[Role] = []
            for role:Role in roles
            {
                switch (self.shape, role) 
                {
                case (let shape?,      .member(of: let type)): 
                    throw ShapeError.conflict(is: shape, and:      .member(of: type))
                case (let shape?, .requirement(of: let type)): 
                    throw ShapeError.conflict(is: shape, and: .requirement(of: type))
                
                case (nil,             .member(of: let type)): 
                    self.shape =       .member(of:     type) 
                case (nil,        .requirement(of: let type)): 
                    self.shape =  .requirement(of:     type) 
                    
                case (_,             .subclass(of: let type)): 
                    if let superclass:Index = superclass 
                    {
                        throw ShapeError.subclass(of: type, and: superclass)
                    }
                    else 
                    {
                        superclass = type
                    }
                    
                default: 
                    residuals.append(role)
                }
            }
            
            let roles:Roles? = try .init(residuals, 
                superclass: superclass, 
                shape: self.shape, 
                as: color)
            self.predicates = .init(roles: roles, 
                primary: .init(traits, as: color))
        }
    }
}
