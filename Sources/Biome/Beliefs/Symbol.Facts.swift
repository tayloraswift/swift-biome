import SymbolGraphs

extension Symbol.Predicates:Sendable where Position:Sendable 
{
}
extension Symbol 
{
    @available(*, deprecated)
    typealias Statement = (subject:Index, predicate:Predicate)
    
    @available(*, deprecated, renamed: "Belief.Predicate")
    typealias Predicate = Belief.Predicate 
    
    struct Predicates<Position>:Equatable where Position:Hashable
    {
        let roles:Roles<Position>?
        var primary:Traits<Position>
        var accepted:[Module.Index: Traits<Position>]
        
        init(roles:Roles<Position>?, primary:Traits<Position> = .init())
        {
            self.roles = roles 
            self.primary = primary
            self.accepted = [:]
        }
        
        mutating 
        func updateAcceptedTraits(_ traits:Traits<Position>, culture:Module.Index)
        {
            self.accepted[culture] = traits.subtracting(self.primary)
        }
        
        func featuresAssumingConcreteType() 
            -> [(perpetrator:Module.Index?, features:Set<Position>)]
        {
            var features:[(perpetrator:Module.Index?, features:Set<Position>)] = []
            if !self.primary.features.isEmpty
            {
                features.append((nil, self.primary.features))
            }
            for (perpetrator, traits):(Module.Index, Traits<Position>) in self.accepted
                where !traits.features.isEmpty
            {
                features.append((perpetrator, traits.features))
            }
            return features
        }
    }
}
extension Symbol.Facts:Sendable where Position:Sendable 
{
}
extension Symbol 
{
    struct Facts<Position> where Position:Hashable
    {
        var shape:Shape<Position>?
        var predicates:Predicates<Position>
        
        init(traits:[Trait<Position>], roles:[Role<Position>], as community:Community)  
        {
            self.shape = nil 
            // partition relationships buffer 
            var superclass:Position? = nil 
            var residuals:[Role<Position>] = []
            for role:Role<Position> in roles
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
                        fatalError("unimplemented")
                        // throw PoliticalError.conflict(is: shape.role, 
                        //     and: .member(of: type))
                    }
                case (let shape?, .requirement(of: let interface)): 
                    guard case    .requirement(of:     interface) = shape 
                    else 
                    {
                        fatalError("unimplemented")
                        // throw PoliticalError.conflict(is: shape.role, 
                        //     and: .requirement(of: interface))
                    }
                    
                case (_,             .subclass(of: let type)): 
                    switch superclass 
                    {
                    case nil, type?:
                        superclass = type
                    case _?:
                        fatalError("unimplemented")
                        // throw PoliticalError.conflict(is: .subclass(of: superclass), 
                        //     and: .subclass(of: type))
                    }
                    
                default: 
                    residuals.append(role)
                }
            }
            
            let roles:Roles<Position>? = .init(residuals, 
                superclass: superclass, 
                shape: self.shape, 
                as: community)
            self.predicates = .init(roles: roles, primary: .init(traits, as: community))
        }
    }
}
