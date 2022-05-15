extension Symbol 
{
    enum Role 
    {
        case member(of:Index)
        case implementation(of:Index)
        case refinement(of:Index)
        case subclass(of:Index)
        case override(of:Index)
        
        case interface(of:Index)
        case requirement(of:Index)
    }
    enum Roles:Sendable 
    {
        /// roles for global symbols, of which there are none.
        case global
        /// roles for mythical symbols, which we don’t have membership information for
        case mythicalImplementation(of:[Index])
        
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
        case implementation(of:[Index], membership:Index)
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
        case requirement(of:Index, upstream:[Index])
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
        case interface(of:[Index], upstream:[Index])
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
    }
}
