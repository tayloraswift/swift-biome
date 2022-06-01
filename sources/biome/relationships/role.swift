extension Symbol 
{
    enum Role:Hashable, Sendable 
    {
        case member(of:Index)
        case implementation(of:Index)
        case refinement(of:Index)
        case subclass(of:Index)
        case override(of:Index)
        
        case interface(of:Index)
        case requirement(of:Index)
    }
    enum Roles:Equatable, Sendable 
    {
        /// roles for global symbols, of which there are none.
        case global
        
        /// general roles for scoped symbols that are neither protocols, protocol 
        /// requirements, or subclasses.
        /// 
        /// - parameters:
        ///     - of: 
        ///         a single-element array if this symbol is a class member 
        ///         that overrides a virtual superclass member; otherwise a 
        ///         list of protocol requirements that this symbol could serve 
        ///         as a default implementation for, if this symbol is a 
        ///         protocol extension member. 
        /// 
        ///         there can be more than one 
        ///         requirement if a type conforms to multiple protocols that 
        ///         have at least one requirement in common.
        ///         
        ///         members of concrete types that merely satisfy protocol 
        ///         requirements are not default implementations, because any 
        ///         member of a concrete type can become an implementation 
        ///         via a retroactive protocol conformance.
        /// 
        ///     - membership: 
        ///         the type this symbol is a member of.
        /// 
        /// > tip: it is not possible to retroactively conform protocols to other 
        /// protocols, so the implemented requirements can be determined 
        /// using only information about modules the current culture depends on.
        case implementation(of:Set<Index>, membership:Index?)
        /// protocol requirement-specific roles. 
        /// 
        /// - parameters: 
        ///     - of: 
        ///         the protocol this requirement is part of. the protocol 
        ///         **must** share the same module culture as this requirement.
        ///     - upstream: 
        ///         the inherited requirement(s) this requirement restates. 
        ///         there can be more than one if its protocol refines more 
        ///         than one protocol that declares the same requirement.
        /// 
        /// > tip: it is not possible to retroactively conform protocols to other 
        /// protocols, so the overridden requirement can be determined 
        /// using only information about modules the current culture depends on.
        case requirement(of:Index, upstream:Set<Index>)
        /// protocol-specific roles. 
        /// 
        /// - parameters:
        ///     - of: 
        ///         the requirements of this protocol. all requirements **must** 
        ///         share the same module culture as this protocol.
        ///     - upstream: 
        ///         the protocols this protocol inherits from.
        /// 
        /// > tip: it is not possible to retroactively conform protocols to other 
        /// protocols, so the full list of implications can be computed using 
        /// only information about modules the current culture depends on.
        case interface(of:Set<Index>, upstream:Set<Index>)
        /// subclass-specific roles. 
        /// 
        /// - parameters: 
        ///     - of: 
        ///         the superclass of this class type.
        ///     - membership: 
        ///         the type this class is nested in, if applicable.
        /// 
        /// nested base classes do not use this case; they use 
        /// ``implementation(of:membership:)`` instead. top-level base classes 
        /// also do not use this case; they use ``global`` instead.
        case subclass(of:Index, membership:Index?)
        
        init<Roles>(_ roles:Roles, membership:Index?, superclass:Index?, interface:Index?, as color:Color) 
            throws 
            where Roles:Sequence, Roles.Element == Role
        {
            switch (color, membership: membership, superclass: superclass, interface: interface) 
            {
            case    (.concretetype(_),  membership: nil,                superclass: nil, interface: nil), 
                    (.typealias,        membership: nil,                superclass: nil, interface: nil), 
                    (.global(_),        membership: nil,                superclass: nil, interface: nil):
                for _:Role in roles
                {
                    fatalError("unreachable") 
                }
                self = .global 
                
            case    (.typealias,        membership: let membership?,    superclass: nil, interface: nil): 
                for _:Role in roles
                {
                    fatalError("unreachable") 
                }
                self = .implementation(of: [], membership: membership)
                
            case    (.class,            membership: let membership,     superclass: let superclass?, interface: nil):
                self = .subclass(of: superclass, membership: membership)
                for role:Role in roles 
                {
                    throw ExclusivityError.subclass(of: superclass, and: role)
                }
                
            case    (.concretetype(_),  membership: let membership?,    superclass: nil, interface: nil), 
                    (.callable(_),      membership: let membership?,    superclass: nil, interface: nil):
                self = .implementation(of: .init(roles.map 
                {
                    switch $0 
                    {
                    case .override(of: let upstream), .implementation(of: let upstream): 
                        return upstream
                    default: 
                        fatalError("unreachable") 
                    }
                }), membership: membership)
                
            case    (.callable(_),      membership: nil,                superclass: nil, interface: nil):
                self = .implementation(of: .init(roles.map 
                {
                    switch $0 
                    {
                    case .implementation(of: let upstream): 
                        return upstream
                    default: 
                        fatalError("unreachable") 
                    }
                }), membership: nil)
                
            case    (.callable(_),      membership: let membership?,    superclass: nil, interface: let interface?):
                throw ExclusivityError.requirement(of: interface, and: .member(of: membership))
                
            case    (.callable(_),      membership: nil,                superclass: nil, interface: let interface?):
                self = .requirement(of: interface, upstream: .init(try roles.map 
                {
                    switch $0 
                    {
                    case .override(of: let upstream): 
                        return upstream
                    default: 
                        throw ExclusivityError.requirement(of: interface, and: $0)
                    }
                }))
            
            case    (.associatedtype,   membership: nil,                superclass: nil, interface: let interface?):
                self = .requirement(of: interface, upstream: .init(try roles.map 
                {
                    switch $0 
                    {
                    case .override(of: let upstream): 
                        return upstream
                    default: 
                        throw ExclusivityError.requirement(of: interface, and: $0)
                    }
                }))
                
            // sanity check: should have thrown a ``MiscegenationError`` earlier
            case    (.protocol,         membership: nil,                superclass: nil, interface: nil):
                var requirements:Set<Index> = [], 
                    upstream:Set<Index> = []
                for role:Role in roles 
                {
                    switch role 
                    {
                    case .interface(of: let requirement):
                        requirements.insert(requirement)
                    case .refinement(of: let `protocol`):
                        upstream.insert(`protocol`)
                    default: 
                        fatalError("unreachable") 
                    }
                }
                self = .interface(of: requirements, upstream: upstream)
            
            default: 
                fatalError("unreachable")
            }
        }
    }
}
