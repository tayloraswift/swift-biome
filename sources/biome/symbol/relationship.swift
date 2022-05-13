extension Symbol 
{
    typealias Statement = (subject:Index, predicate:Relationship)
    typealias Sponsorship = (sponsored:Index, by:Index)
    typealias ColoredIndex = (index:Index, color:Color)
    
    enum JurisdictionalError:Error 
    {
        case module(Module.Index,   says:Index, is:Role)
        case package(Package.Index, says:Index, isSponsoredBy:Index)
    }
    enum MiscegenationError:Error 
    {
        case constraints(ColoredIndex,   isOnly:Edge.Kind, of:ColoredIndex, where:[Generic.Constraint<Index>])
        case color      (ColoredIndex, cannotBe:Edge.Kind, of:ColoredIndex)
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
    struct Relationships:Sendable 
    {
        let color:Color
        let roles:Roles
        private(set)
        var facts:Traits, 
            opinions:[Package.Index: Traits]
        
        init(validating relationships:[Relationship], color:Color) throws 
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
            
            try self.init(membership: membership, superclass: superclass, interface: interface, 
                roles: roles, color: color)
            self.update(traits: traits)
        }
        private 
        init(membership:Index?, superclass:Index?, interface:Index?, roles:[Role], color:Color) throws
        {
            self.opinions = [:]
            self.facts = .init()
            self.color = color 
            if  case .protocol = color 
            {
                // sanity check: should have thrown a ``MiscegenationError`` earlier
                guard case (nil, nil, nil) = (membership, superclass, interface)
                else 
                {
                    fatalError("unreachable")
                }
                
                var requirements:[Index] = [], 
                    upstream:[Index] = []
                for role:Role in roles 
                {
                    switch role 
                    {
                    case .interface(of: let requirement):
                        requirements.append(requirement)
                    case .refinement(of: let `protocol`):
                        upstream.append(`protocol`)
                    default: 
                        fatalError("unreachable") 
                    }
                }
                self.roles = .interface(of: requirements, upstream: upstream)
                return 
            }
            
            switch (membership: membership, superclass: superclass, interface: interface) 
            {
            case (membership: let membership?, superclass: _,               interface: let interface?):
                throw ExclusivityError.requirement(of: interface, and: .member(of: membership))
                
            case (membership: nil,             superclass: _,               interface: let interface?):
                self.roles = .requirement(of: interface, upstream: try roles.map 
                {
                    switch $0 
                    {
                    case .override(of: let upstream): 
                        return upstream
                    default: 
                        throw ExclusivityError.requirement(of: interface, and: $0)
                    }
                })
                
            case (membership: let membership?, superclass: nil,             interface: nil):
                self.roles = .implementation(of: roles.map 
                {
                    switch $0 
                    {
                    case .implementation(of: let upstream), .override(of: let upstream): 
                        return upstream
                    default: 
                        fatalError("unreachable") 
                    }
                }, membership: membership)
            
            case (membership: nil,             superclass: nil,             interface: nil):
                self.roles = .global 
                for role:Role in roles 
                {
                    throw ExclusivityError.global(is: role)
                }
                
            case (membership: let membership,  superclass: let superclass?, interface: nil):
                self.roles = .subclass(of: superclass, membership: membership)
                for role:Role in roles 
                {
                    throw ExclusivityError.subclass(of: superclass, and: role)
                }
            }
        }
        private mutating 
        func update(traits:[Trait])  
        {
            self.facts.update(with: traits, as: self.color)
        }
        mutating 
        func update(traits:[Trait], from package:Package.Index)  
        {
            self.opinions[package, default: .init()].update(with: traits, as: self.color)
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
        
        let sponsorship:Symbol.Sponsorship? = try self.origin.map
        {
            (sponsored: index.source, by: try scope.index(of: $0))
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
            throw Symbol.MiscegenationError.constraints(source, isOnly: self, of: target, where: constraints)
        case (_, is: _, of: _, unconditional: true):
            throw Symbol.MiscegenationError.color(source, cannotBe: self, of: target)
        }
        return relationships
    }
}
