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

        func map<T>(_ transform:(Position) throws -> T) rethrows -> Predicates<T> 
            where T:Hashable
        {
            fatalError("unimplemented")
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
        var roles:Roles<Position>?
        var primary:Traits<Position>
        var accepted:[Module.Index: Traits<Position>]

        @available(*, deprecated)
        var predicates:Predicates<Position>
        {
            fatalError("obsoleted")
        }
        
        init(shape:Shape<Position>?, 
            roles:Roles<Position>?,
            primary:Traits<Position>,
            accepted:[Module.Index: Traits<Position>] = [:])
        {
            self.shape = shape 
            self.roles = roles 
            self.primary = primary 
            self.accepted = accepted
        }
        init(traits:[Trait<Position>], roles:[Role<Position>], as community:Community)  
        {
            var shape:Shape<Position>? = nil 
            // partition relationships buffer 
            var superclass:Position? = nil 
            var residuals:[Role<Position>] = []
            for role:Role<Position> in roles
            {
                switch (shape, role) 
                {
                case  (nil,            .member(of: let type)): 
                    shape =            .member(of:     type) 
                case (nil,        .requirement(of: let interface)): 
                    shape =       .requirement(of:     interface) 
                
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
            
            self.init(shape: shape, 
                roles: .init(residuals, superclass: superclass, shape: shape, as: community), 
                primary: .init(traits, as: community))
        }

        func map<T>(_ transform:(Position) throws -> T) rethrows -> Facts<T>
            where T:Hashable
        {
            .init(shape: try self.shape?.map(transform), 
                roles: try self.roles?.map(transform),
                primary: try self.primary.map(transform),
                accepted: try self.accepted.mapValues { try $0.map(transform) })
        }

        mutating 
        func update(acceptedCulture culture:Module.Index, with traits:Traits<Position>)
        {
            self.accepted[culture] = traits.subtracting(self.primary)
        }
    }
}
extension Symbol.Facts<Tree.Position<Symbol>>
{
    func metadata() -> Symbol.Metadata 
    {
        fatalError("unimplemented")
    }
}