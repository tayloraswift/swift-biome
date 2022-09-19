extension Branch 
{
    struct SymbolTraits:Equatable, Sendable
    {
        /// if a concrete type, the members of this type, not including members 
        /// inherited through protocol conformances. 
        /// if a protocol, the members in extensions of this protocol. 
        /// 
        /// requirements and witnesses must not access this property.
        var members:Set<Atom<Symbol>>
        
        /// if a protocol, protocols that inherit from this protocol.
        /// if a class, classes that subclass this class.
        /// if a requirement, any requirements of protocols that refine its
        /// interface that also restate this requirement.
        /// if a witness, any subclass members that override this witness, if 
        /// it is a class member.
        var downstream:Set<Atom<Symbol>>
        
        //private 
        var unconditional:Set<Atom<Symbol>>
        /// if a concrete type, members of this type inherited through 
        /// protocol conformances.
        /// 
        /// this shares backing storage with ``implementations``. requirements 
        /// should access ``implementations`` instead. protocols and witnesses 
        /// must not access this property.
        /// 
        /// > note: for concrete types, the module that an inherited member 
        /// originates from is not necessarily the perpetrator of the conformance 
        /// that trafficked it into its scope.
        var features:Set<Atom<Symbol>>
        {
            _read 
            {
                yield self.unconditional
            }
            _modify
            {
                yield &self.unconditional
            }
        }
        
        /// if a requirement, the default implementations available for this 
        /// requirement. 
        /// 
        /// this shares backing storage with ``features``. types and witnesses 
        /// must not access this property.
        var implementations:Set<Atom<Symbol>>
        {
            _read 
            {
                yield self.unconditional
            }
            _modify
            {
                yield &self.unconditional
            }
        }

        //private 
        var conditional:[Atom<Symbol>: [Generic.Constraint<Atom<Symbol>>]]
        /// if a protocol, concrete types that implement this protocol.
        /// 
        /// this shares backing storage with ``conformances``. concrete types 
        /// should access ``conformances`` instead. requirements and witnesses 
        /// must not access this property.
        var conformers:[Atom<Symbol>: [Generic.Constraint<Atom<Symbol>>]]
        {
            _read 
            {
                yield self.conditional
            }
            _modify
            {
                yield &self.conditional
            }
        }
        /// if a concrete type, protocols this type conforms to.
        /// 
        /// this shares backing storage with ``conformers``. protocols 
        /// should access ``conformers`` instead. requirements and witnesses 
        /// must not access this property.
        var conformances:[Atom<Symbol>: [Generic.Constraint<Atom<Symbol>>]]
        {
            _read 
            {
                yield self.conditional
            }
            _modify
            {
                yield &self.conditional
            }
        }
        
        init(members:Set<Atom<Symbol>> = [],
            downstream:Set<Atom<Symbol>> = [],
            unconditional:Set<Atom<Symbol>> = [],
            conditional:[Atom<Symbol>: [Generic.Constraint<Atom<Symbol>>]] = [:]) 
        {
            self.members = members
            self.downstream = downstream
            self.unconditional = unconditional
            self.conditional = conditional
        }
    }
}