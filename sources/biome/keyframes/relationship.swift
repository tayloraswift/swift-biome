extension Symbol 
{
    typealias Statement = (subject:Index, predicate:Relationship)
    typealias Sponsorship = (sponsored:Index, by:Index)
    typealias ColoredIndex = (index:Index, color:Color)
    
    enum SponsorshipError:Error 
    {
        case disputed                        (Index, isSponsoredBy:Index, and:Index)
    //    case unauthorized(Package.Index, says:Index, isSponsoredBy:Index)
    }
    enum RelationshipError:Error 
    {
        case miscegenation(ColoredIndex, cannotBe:Edge.Kind, of:ColoredIndex)
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
        var facts:Traits
        
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
            self.facts = .init()
            self.facts.update(with: traits, as: color)
        }
    }
}
extension Edge 
{
    typealias Statements = (Symbol.Statement, Symbol.Statement?, Symbol.Sponsorship?)
    
    func statements(given scope:Scope, color:(Symbol.Index) throws -> Symbol.Color) 
        throws -> Statements
    {
        let constraints:[Generic.Constraint<Symbol.Index>] = try self.constraints.map
        {
            try $0.map(scope.index(of:))
        }
        let index:(source:Symbol.Index, target:Symbol.Index) = 
        (
            try scope.index(of: self.source),
            try scope.index(of: self.target)
        )
        let (source, target):(Symbol.ColoredIndex, Symbol.ColoredIndex) = 
        (
            (index.source, try color(index.source)),
            (index.target, try color(index.target))
        )
        // this fails quite frequently. we don’t have a great solution for this.
        let sponsorship:Symbol.Sponsorship? 
        if  let origin:Symbol.ID = self.origin, 
            let origin:Symbol.Index = try? scope.index(of: origin)
        {
            sponsorship = (index.source, by: origin)
        }
        else 
        {
            sponsorship = nil
        }
        
        let (secondary, primary):(Symbol.Relationship?, Symbol.Relationship) = 
            try self.kind.relationships(source, target, where: constraints)

        return ((index.target, primary), secondary.map { (index.source, $0) }, sponsorship)
    }
}
extension Edge.Kind 
{
    func relationships(_ source:Symbol.ColoredIndex, _ target:Symbol.ColoredIndex, 
        where constraints:[Generic.Constraint<Symbol.Index>])
        throws -> (source:Symbol.Relationship?, target:Symbol.Relationship)
    {
        let relationships:(source:Symbol.Relationship?, target:Symbol.Relationship)
        switch  (source.color,      is: self,                   of: target.color,       unconditional: constraints.isEmpty) 
        {
        case    (.callable(_),      is: .feature,               of: .concretetype(_),   unconditional: true):
            relationships =
            (
                source:  nil,
                target: .has(.feature(source.index))
            )
        
        case    (.concretetype(_),  is: .member,                of: .concretetype(_),   unconditional: true), 
                (.typealias,        is: .member,                of: .concretetype(_),   unconditional: true), 
                (.callable(_),      is: .member,                of: .concretetype(_),   unconditional: true), 
                (.concretetype(_),  is: .member,                of: .protocol,          unconditional: true),
                (.typealias,        is: .member,                of: .protocol,          unconditional: true),
                (.callable(_),      is: .member,                of: .protocol,          unconditional: true):
            relationships = 
            (
                source:  .is(.member(of: target.index)), 
                target: .has(.member(    source.index))
            )
        
        case    (.concretetype(_),  is: .conformer,             of: .protocol,          unconditional: _):
            relationships = 
            (
                source: .has(.conformance(target.index, where: constraints)), 
                target: .has(  .conformer(source.index, where: constraints))
            ) 
        case    (.protocol,         is: .conformer,             of: .protocol,          unconditional: true):
            relationships = 
            (
                source:  .is(.refinement(of: target.index)), 
                target: .has(.refinement(    source.index))
            ) 
        
        case    (.class,            is: .subclass,              of: .class,             unconditional: true):
            relationships = 
            (
                source:  .is(.subclass(of: target.index)), 
                target: .has(.subclass(    source.index))
            ) 
         
        case    (.associatedtype,   is: .override,              of: .associatedtype,    unconditional: true),
                (.callable(_),      is: .override,              of: .callable,          unconditional: true):
            relationships = 
            (
                source:  .is(.override(of: target.index)), 
                target: .has(.override(    source.index))
            ) 
         
        case    (.associatedtype,   is: .requirement,           of: .protocol,          unconditional: true),
                (.callable(_),      is: .requirement,           of: .protocol,          unconditional: true),
                (.associatedtype,   is: .optionalRequirement,   of: .protocol,          unconditional: true),
                (.callable(_),      is: .optionalRequirement,   of: .protocol,          unconditional: true):
            relationships = 
            (
                source:  .is(.requirement(of: target.index)), 
                target:  .is(  .interface(of: source.index))
            ) 
         
        case    (.callable(_),      is: .defaultImplementation, of: .callable(_),       unconditional: true):
            relationships = 
            (
                source:  .is(.implementation(of: target.index)), 
                target: .has(.implementation(    source.index))
            ) 
        
        case (_, is: _, of: _, unconditional: false):
            // ``Edge.init(from:)`` should have thrown a ``JSON.LintingError`
            fatalError("unreachable")
        
        case (_, is: _, of: _, unconditional: true):
            throw Symbol.RelationshipError.miscegenation(source, cannotBe: self, of: target)
        }
        return relationships
    }
}
