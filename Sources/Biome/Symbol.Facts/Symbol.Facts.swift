import SymbolGraphs

extension Symbol 
{
    typealias Statement = (subject:Index, predicate:Predicate)
    
    enum Predicate 
    {
        case `is`(Role<Index>)
        case has(Trait<Index>)
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
        var shape:Shape<Index>?
        var predicates:Predicates
        
        init(traits:[Trait<Index>], roles:[Role<Index>], as community:Community) throws 
        {
            self.shape = nil 
            // partition relationships buffer 
            var superclass:Index? = nil 
            var residuals:[Role<Index>] = []
            for role:Role<Index> in roles
            {
                switch (self.shape, role) 
                {
                case  (nil,            .member(of: let type)): 
                    self.shape =       .member(of:     type) 
                case (nil,        .requirement(of: let interface)): 
                    self.shape =  .requirement(of:     interface) 
                
                case (let shape?,      .member(of: let type)):
                    guard case         .member(of:     type) = shape 
                    else 
                    {
                        throw PoliticalError.conflict(is: shape.role, 
                            and: .member(of: type))
                    }
                case (let shape?, .requirement(of: let interface)): 
                    guard case    .requirement(of:     interface) = shape 
                    else 
                    {
                        throw PoliticalError.conflict(is: shape.role, 
                            and: .requirement(of: interface))
                    }
                    
                case (_,             .subclass(of: let type)): 
                    switch superclass 
                    {
                    case nil, type?:
                        superclass = type
                    case let superclass?:
                        throw PoliticalError.conflict(is: .subclass(of: superclass), 
                            and: .subclass(of: type))
                    }
                    
                default: 
                    residuals.append(role)
                }
            }
            
            let roles:Roles? = try .init(residuals, 
                superclass: superclass, 
                shape: self.shape, 
                as: community)
            self.predicates = .init(roles: roles, primary: .init(traits, as: community))
        }
    }
}
