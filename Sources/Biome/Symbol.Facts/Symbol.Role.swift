extension Symbol.Role:Equatable where Target:Equatable {}
extension Symbol.Role:Hashable where Target:Hashable {}
extension Symbol.Role:Sendable where Target:Sendable {}
extension Symbol 
{
    @frozen public
    enum Role<Target>:CustomStringConvertible
    {
        case member(of:Target)
        case implementation(of:Target)
        case refinement(of:Target)
        case subclass(of:Target)
        case override(of:Target)
        
        case interface(of:Target)
        case requirement(of:Target)
        
        func map<T>(_ transform:(Target) throws -> T) rethrows -> Role<T>
        {
            switch self 
            {
            case .member(of: let target): 
                return .member(of: try transform(target))
            case .implementation(of: let target): 
                return .implementation(of: try transform(target))
            case .refinement(of: let target): 
                return .refinement(of: try transform(target))
            case .subclass(of: let target): 
                return .subclass(of: try transform(target))
            case .override(of: let target): 
                return .override(of: try transform(target))
            case .interface(of: let target): 
                return .interface(of: try transform(target))
            case .requirement(of: let target): 
                return .requirement(of: try transform(target))
            }
        }
        @inlinable public
        var description:String 
        {
            switch self 
            {
            case .member(of: let target): 
                return "member of \(target)"
            case .implementation(of: let target): 
                return "implementation of \(target)"
            case .refinement(of: let target): 
                return "refinement of \(target)"
            case .subclass(of: let target): 
                return "subclass of \(target)"
            case .override(of: let target): 
                return "override of \(target)"
            case .interface(of: let target): 
                return "interface of \(target)"
            case .requirement(of: let target): 
                return "requirement of \(target)"
            }
        }
    }
    
    /// symbol relationships that are independent of, and unaffected by any 
    /// downstream module consumers. 
    /// 
    /// in swift, it is not possible to retroactively subclass class types or 
    /// conform protocols to other protocols, so certain information about a 
    /// symbol can be determined using only information about modules the 
    /// symbol’s culture depends on.
    /// 
    /// the meaning of the roles stored in this structure depends on the kind of 
    /// symbol using it.
    ///
    /// -   callable class members can have a single role if they override 
    ///     a virtual superclass member.
    ///
    /// -   callable protocol members can have one or more upstream protocol 
    ///     requirements that they could serve as a default implementation for.
    ///
    ///     there can be more than one requirement if a type conforms to 
    ///     multiple protocols that have at least one requirement in common.
    ///
    ///     members of concrete types that merely satisfy protocol 
    ///     requirements are not default implementations, because any 
    ///     member of a concrete type can become an implementation 
    ///     via a retroactive protocol conformance.
    /// 
    /// -   protocol requirements can have one or more requirements of upstream 
    ///     protocols they restate. 
    /// 
    ///     there can be more than one such upstream requirement if a protocol 
    ///     refines multiple protocols that declare the same requirement.
    /// 
    /// -   protocols can have requirements, and can also have upstream protocols 
    ///     they refine. both kinds of roles are stored in the same buffer; they 
    ///     can be distinguished by querying the color of the symbol they reference.
    /// 
    ///     protocol requirements *always* have the same culture as the protocol 
    ///     itself.
    /// 
    ///     note: ``Ecosystem.add(role:to:pinned:)`` relies on this assumption!
    /// 
    /// -   classes can have a single role if they have a superclass.
    /// 
    /// -   other kinds of symbols never have roles.
    enum Roles:Equatable, Sendable 
    {
        // case none 
        case one        (Index)
        case many   (Set<Index>)
        
        private 
        init?(_ symbols:[Index]) 
        {
            if symbols.isEmpty 
            {
                return nil 
            }
            else if symbols.count == 1 
            {
                self = .one(symbols[0])
            }
            else  
            {
                self = .many(.init(symbols))
            }
        }
        init?<Roles>(_ roles:Roles, superclass:Index?, shape:Shape<Index>?, as color:Color) 
            throws 
            where Roles:Sequence, Roles.Element == Role<Index>
        {
            if  let superclass:Index = superclass 
            {
                switch  (color, shape)
                {
                case    (.class, .member(of: _)?), 
                        (.class,           nil):
                    self = .one(superclass)
                
                default: 
                    // should have thrown a ``ColorError`` earlier
                    fatalError("unreachable")
                }
                for _:Role<Index> in roles 
                {
                    fatalError("unreachable")
                }
            }
            else 
            {
                switch  (color, shape)
                {
                case    (.callable(_),      .requirement(of: let interface)?), 
                        (.associatedtype,   .requirement(of: let interface)?):
                    self.init(try roles.map 
                    {
                        switch $0 
                        {
                        case .override(of: let upstream): 
                            return upstream
                        case let other:
                            // requirements cannot be default implementations
                            throw PoliticalError.conflict(is: .requirement(of: interface), 
                                and: other)
                        }
                    })
                
                case    (_,                 .requirement(of: _)?):
                    // should have thrown a ``ColorError`` earlier
                    fatalError("unreachable")
                    
                case    (.concretetype(_),  nil), 
                        (.typealias,          _), 
                        (.global(_),        nil):
                    for _:Role<Index> in roles
                    {
                        fatalError("unreachable") 
                    }
                    return nil
                
                case    (.concretetype(_),  .member(of: _)?), 
                        (.callable(_),      .member(of: _)?):
                    self.init(roles.map 
                    {
                        switch $0 
                        {
                        case .override(of: let upstream), .implementation(of: let upstream): 
                            return upstream
                        default: 
                            fatalError("unreachable") 
                        }
                    })
                    
                case    (.callable(_),      nil):
                    self.init(roles.map 
                    {
                        switch $0 
                        {
                        case .implementation(of: let upstream): 
                            return upstream
                        default: 
                            fatalError("unreachable") 
                        }
                    })
                    
                case    (.protocol,         nil):
                    self.init(roles.map
                    {
                        switch $0
                        {
                        case .interface(of: let symbol), .refinement(of: let symbol):
                            return symbol 
                        default: 
                            fatalError("unreachable") 
                        }
                    })
                
                default: 
                    fatalError("unreachable")
                }
            }
        }
    }
}
