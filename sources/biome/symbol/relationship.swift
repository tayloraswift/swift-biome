extension Symbol 
{
    typealias ColoredIndex = (index:Index, color:Color)
    
    enum RelationshipError:Error 
    {
        case miscegenation(Module.Index, says:Index, is:IntrinsicRelationship)
        case jurisdiction(Module.Index, says:Index, impersonates:Index)
        case constraints(ColoredIndex,   isOnly:Edge.Kind, of:ColoredIndex, where:[Generic.Constraint<Index>])
        case color      (ColoredIndex, cannotBe:Edge.Kind, of:ColoredIndex)
    }
    
    struct Relationships:Sendable 
    {
        let color:Color
        let intrinsic:IntrinsicRelationships
        let citizens:ExtrinsicRelationships
        var aliens:[Package.Index: ExtrinsicRelationships]
        
        init(validating relationships:[Relationship]) throws 
        {
            fatalError("unimplemented")
        }
    }
    //  conceptually, this type encodes:
    //  -   associatedtype: 
    //          0: (uninhabited)
    //          1: default implementations (``implementations``)
    //          2: restatements (``downstream``)
    //          3: (uninhabited)
    //  -   protocol:
    //          0: (uninhabited; requirements are stored in ``IntrinsicRelationships``)
    //          1: extension members (``features``)
    //          2: inheriting protocols (``downstream``)
    //          3: conforming types (``conformers``)
    //  -   typealias:
    //          0: (uninhabited)
    //          1: (uninhabited)
    //          2: (uninhabited)
    //          3: (uninhabited)
    //  -   concretetype(_):
    //          0: members (``members``)
    //          1: features (``features``)
    //          2: subclasses (``downstream``)
    //          3: protocol conformances (``conformances``)
    //  -   callable(_):
    //          0: (uninhabited)
    //          1: (uninhabited)
    //          2: overriding callables (``downstream``)
    //          3: (uninhabited)
    struct ExtrinsicRelationships:Sendable 
    {
        init() 
        {
            self.storage = ([], [], [], [])
        }
        private 
        var storage:
        (
            [Index], 
            [Index], 
            [Index], 
            [(index:Index, conditions:[Generic.Constraint<Index>])]
        )
        /// if a concrete type, the members of this type, not including members 
        /// inherited through protocol conformances.
        /// 
        /// protocols, requirements, and witnesses must not access this property.
        var members:[Index]
        {
            _read 
            {
                yield self.storage.0
            }
            _modify
            {
                yield &self.storage.0
            }
        }
        /// if a protocol, the members in extensions of this protocol. 
        /// if a concrete type, members of this type inherited through 
        /// protocol conformances.
        /// 
        /// this shares backing storage with ``implementations``. requirements 
        /// should access ``implementations`` instead. witnesses must not access 
        /// this property.
        /// 
        /// > note: for concrete types, the module that an inherited member 
        /// originates from is not necessarily the perpetrator of the conformance 
        /// that trafficked it into its scope.
        var features:[Index]
        {
            _read 
            {
                yield self.storage.1
            }
            _modify
            {
                yield &self.storage.1
            }
        }
        /// if a requirement, the default implementations available for this 
        /// requirement. 
        /// 
        /// this shares backing storage with ``members``. types should access 
        /// ``members`` instead. witnesses must not access this property.
        var implementations:[Index]
        {
            _read 
            {
                yield self.storage.1
            }
            _modify
            {
                yield &self.storage.1
            }
        }
        /// if a protocol, protocols that inherit from this protocol.
        /// if a class, classes that subclass this class.
        /// if a requirement, any requirements of protocols that refine its
        /// interface that also restate this requirement.
        /// if a witness, any subclass members that override this witness, if 
        /// it is a class member.
        var downstream:[Index] 
        {
            _read 
            {
                yield self.storage.2
            }
            _modify
            {
                yield &self.storage.2
            }
        }
        
        /// if a protocol, concrete types that implement this protocol.
        /// 
        /// this shares backing storage with ``conformances``. concrete types 
        /// should access ``conformances`` instead. requirements and witnesses 
        /// must not access this property.
        var conformers:[(index:Index, conditions:[Generic.Constraint<Index>])]
        {
            _read 
            {
                yield self.storage.3
            }
            _modify
            {
                yield &self.storage.3
            }
        }
        /// if a concrete type, protocols this type conforms to.
        /// 
        /// this shares backing storage with ``conformers``. protocols 
        /// should access ``conformers`` instead. requirements and witnesses 
        /// must not access this property.
        var conformances:[(index:Index, conditions:[Generic.Constraint<Index>])]
        {
            _read 
            {
                yield self.storage.3
            }
            _modify
            {
                yield &self.storage.3
            }
        }
    }
    enum IntrinsicRelationships:Sendable 
    {
        case `protocol`(ProtocolRelationships)
        case requirement(RequirementRelationships)
        case witness(WitnessRelationships)
        case global
    }
    struct ProtocolRelationships:Sendable 
    {
        /// the requirements of this protocol. 
        /// 
        /// > tip: requirements are always module-local.
        var requirements:[Index]
        /// protocols this protocol inherits from. 
        /// 
        /// > tip: it is not possible to retroactively conform protocols to other 
        /// protocols, so the full list of implications can be computed 
        /// using only upstream information.
        var upstream:[Index]
    }
    struct RequirementRelationships:Sendable 
    {
        /// the protocol this requirement is part of. 
        /// 
        /// > tip: requirements are always module-local.
        var `protocol`:Index
        /// the inherited requirement this requirement restates. 
        /// 
        /// > tip: it is not possible to retroactively conform protocols to other 
        /// protocols, so the overridden requirement can be determined 
        /// using only module-local information.
        var upstream:Index?
    }
    struct WitnessRelationships:Sendable 
    {
        var membership:Index
        /// the requirements that this witness could serve as a default 
        /// implementation for, if this witness originates from a protocol extension;
        /// otherwise a single-element array if this witness is a class 
        /// member that overrides a virtual superclass member.
        /// 
        /// there can be more than one requirement if a type conforms to 
        /// multiple protocols that have at least one requirement in common.
        /// 
        /// > tip: it is not possible to retroactively conform protocols to other 
        /// protocols, so the implemented requirements can be determined 
        /// using only upstream information.
        var requirements:[Index]
    }
    
    enum Relationship 
    {
        case `is`(IntrinsicRelationship)
        case has(ExtrinsicRelationship)
    }
    enum ExtrinsicRelationship 
    {
        // members 
        case member(Index)
        case feature(Index)
        // implementations 
        case implementation(Index)
        // downstream
        case refinement(Index)
        case subclass(Index)
        case override(Index)
        // conformers
        case conformer(Index, where:[Generic.Constraint<Index>])
        // conformances
        case conformance(Index, where:[Generic.Constraint<Index>])
    }
    enum IntrinsicRelationship 
    {
        case member(of:Index)
        case implementation(of:Index)
        case refinement(of:Index)
        case subclass(of:Index)
        case override(of:Index)
        
        case `protocol`(of:Index)
        case requirement(of:Index)
    }
}
extension Edge.Kind 
{
    func relationships(_ source:Symbol.ColoredIndex, _ target:Symbol.ColoredIndex, 
        where constraints:[Generic.Constraint<Symbol.Index>])
    throws -> (source:Symbol.Relationship?, target:Symbol.Relationship)
    {
        let relationships:(source:Symbol.Relationship?, target:Symbol.Relationship)
        switch  (source.color,      is: self,                   of: target.color,       conditional: constraints.isEmpty) 
        {
        case    (.callable(_),      is: .feature,               of: .concretetype(_),   conditional: false):
            relationships =
            (
                source:  nil,
                target: .has(.feature(source.index))
            )
        
        case    (.concretetype(_),  is: .member,                of: .concretetype(_),   conditional: false), 
                (.typealias,        is: .member,                of: .concretetype(_),   conditional: false), 
                (.callable(_),      is: .member,                of: .concretetype(_),   conditional: false), 
                (.concretetype(_),  is: .member,                of: .protocol,          conditional: false),
                (.typealias,        is: .member,                of: .protocol,          conditional: false),
                (.callable(_),      is: .member,                of: .protocol,          conditional: false):
            relationships = 
            (
                source:  .is(.member(of: target.index)), 
                target: .has(.member(    source.index))
            )
        
        case    (.concretetype(_),  is: .conformer,             of: .protocol,          conditional: _):
            relationships = 
            (
                source: .has(.conformance(target.index, where: constraints)), 
                target: .has(  .conformer(source.index, where: constraints))
            ) 
        case    (.protocol,         is: .conformer,             of: .protocol,          conditional: false):
            relationships = 
            (
                source:  .is(.refinement(of: target.index)), 
                target: .has(.refinement(    source.index))
            ) 
        
        case    (.class,            is: .subclass,              of: .class,             conditional: false):
            relationships = 
            (
                source:  .is(.subclass(of: target.index)), 
                target: .has(.subclass(    source.index))
            ) 
         
        case    (.associatedtype,   is: .override,              of: .associatedtype,    conditional: false),
                (.callable(_),      is: .override,              of: .callable,          conditional: false):
            relationships = 
            (
                source:  .is(.override(of: target.index)), 
                target: .has(.override(    source.index))
            ) 
         
        case    (.associatedtype,   is: .requirement,           of: .protocol,          conditional: false),
                (.callable(_),      is: .requirement,           of: .protocol,          conditional: false),
                (.associatedtype,   is: .optionalRequirement,   of: .protocol,          conditional: false),
                (.callable(_),      is: .optionalRequirement,   of: .protocol,          conditional: false):
            relationships = 
            (
                source:  .is(.requirement(of: target.index)), 
                target:  .is(   .protocol(of: source.index))
            ) 
         
        case    (.callable(_),      is: .defaultImplementation, of: .callable(_),       conditional: false):
            relationships = 
            (
                source:  .is(.implementation(of: target.index)), 
                target: .has(.implementation(    source.index))
            ) 
        
        case (_, is: _, of: _, conditional: true):
            throw Symbol.RelationshipError.constraints(source, isOnly: self, of: target, where: constraints)
        case (_, is: _, of: _, conditional: false):
            throw Symbol.RelationshipError.color(source, cannotBe: self, of: target)
        }
        return relationships
    }
}
