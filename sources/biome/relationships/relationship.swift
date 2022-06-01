extension Symbol 
{
    typealias Statement = (subject:Index, predicate:Relationship)
    
    enum RelationshipError:Error 
    {
        case miscegenation(Color, cannotBe:Edge.Kind, of:Color)
        case unauthorized(Module.Index, says:Index, is:Role)
    }
    enum ExclusivityError:Error 
    {
        case member     (of:Index, and:Index)
        case subclass   (of:Index, and:Role)
        case requirement(of:Index, and:Role)
        case global     (is:Role)
    }
    
    enum Relationship 
    {
        case `is`(Role)
        case has(Trait)
    }
    struct Relationships:Equatable, Sendable 
    {
        let roles:Roles
        private(set)
        var traits:Traits
        var identities:[Module.Index: Traits]
        
        init(validating relationships:[Relationship], as color:Color) throws 
        {
            // partition relationships buffer 
            var roles:[Role] = []
            var traits:[Trait] = []
            var membership:Index? = nil 
            var superclass:Index? = nil 
            var interface:Index?  = nil
            
            for relationship:Relationship in relationships 
            {
                switch relationship 
                {
                case  .is(.member(of: let mistress)): 
                    if let spouse:Index = membership 
                    {
                        throw ExclusivityError.member(of: spouse, and: mistress)
                    }
                    membership = mistress 
                    
                case  .is(.subclass(of: let mistress)): 
                    if let spouse:Index = superclass 
                    {
                        throw ExclusivityError.subclass(of: spouse, and: .subclass(of: mistress))
                    }
                    superclass = mistress 
                    
                case  .is(.requirement(of: let mistress)): 
                    if let spouse:Index = interface
                    {
                        throw ExclusivityError.requirement(of: spouse, and: .requirement(of: mistress))
                    }
                    interface = mistress 
                    
                case  .is(let role): 
                    roles.append(role)
                case .has(let trait): 
                    traits.append(trait)
                }
            }
            
            self.roles = try .init(roles, 
                membership: membership, 
                superclass: superclass, 
                interface: interface, 
                as: color)
            self.traits = .init()
            self.traits.update(with: traits, as: color)
            self.identities = [:]
        }
        
        func featuresAssumingConcreteType() -> [(perpetrator:Module.Index?, features:Set<Index>)]
        {
            var features:[(perpetrator:Module.Index?, features:Set<Index>)] = []
            if !self.traits.features.isEmpty
            {
                features.append((nil, self.traits.features))
            }
            for (perpetrator, traits):(Module.Index, Traits) in self.identities 
                where !traits.features.isEmpty
            {
                features.append((perpetrator, traits.features))
            }
            return features
        }
    }
}
