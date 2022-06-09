extension Symbol 
{
    typealias Statement = (subject:Index, predicate:Predicate)
    
    enum ColorError:Error 
    {
        case miscegenation(Color, is:Edge.Kind, of:Color)
    }
    enum ShapeError:Error 
    {
        case conflict   (is:Shape, and:Shape)
        case subclass   (of:Index, and:Index)
        case requirement(of:Index, is:Role)
    }
    
    enum Predicate 
    {
        case `is`(Role)
        case has(Trait)
    }
    struct Predicates:Equatable, Sendable 
    {
        let roles:Roles?
        var `internal`:Traits
        var  external:[Module.Index: Traits]
        
        init(roles:Roles?)
        {
            self.roles = roles 
            self.internal = .init()
            self.external = [:]
        }
        
        func featuresAssumingConcreteType() -> [(perpetrator:Module.Index?, features:Set<Index>)]
        {
            var features:[(perpetrator:Module.Index?, features:Set<Index>)] = []
            if !self.internal.features.isEmpty
            {
                features.append((nil, self.internal.features))
            }
            for (perpetrator, traits):(Module.Index, Traits) in self.external 
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
        
        init(traits:[Trait], roles combined:[Role], as color:Color) throws 
        {
            // partition relationships buffer 
            var roles:[Role] = []
            var superclass:Index? = nil 
            
            self.shape = nil 
            for role:Role in combined
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
                    roles.append(role)
                }
            }
            
            self.predicates = .init(roles: try .init(roles, 
                superclass: superclass, 
                shape: self.shape, 
                as: color))
            self.predicates.internal.update(with: traits, 
                as: color)
        }
    }
}
