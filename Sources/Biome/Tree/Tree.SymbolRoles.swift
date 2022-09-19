// extension Tree 
// {
//     enum SymbolRoles
//     {
//         case one(Position<Symbol>)
//         case many([Position<Symbol>: Version.Branch])
        
//         private 
//         init?<Roles>(_ roles:Roles, 
//             validate:(Symbol.Role<Position<Symbol>>) throws -> Position<Symbol>) rethrows 
//             where Roles:Sequence<Symbol.Role<Position<Symbol>>>
//         {
//             var roles:Roles.Iterator = roles.makeIterator()
//             guard let first:Position<Symbol> = try roles.next().map(validate)
//             else 
//             {
//                 return nil 
//             }
//             while let second:Position<Symbol> = try roles.next().map(validate)
//             {
//                 guard second.contemporary != first.contemporary
//                 else 
//                 {
//                     continue 
//                 }
//                 var many:[Position<Symbol>: Version.Branch] = 
//                 [
//                     first.contemporary: first.branch,
//                     second.contemporary: second.branch,
//                 ]
//                 while let next:Position<Symbol> = try roles.next().map(validate)
//                 {
//                     many[next.contemporary] = next.branch
//                 }
//                 self = .many(many)
//                 return 
//             }
//             self = .one(first)
//             return 
//         }
//     }
// }
// extension Tree.SymbolRoles
// {
//     init?(_ roles:some Sequence<Symbol.Role<PluralPosition<Symbol>>>, 
//         superclass:PluralPosition<Symbol>?, 
//         shape:Symbol.Shape<PluralPosition<Symbol>>?, 
//         as community:Community) 
//     {
//         if  let superclass:PluralPosition<Symbol> = superclass 
//         {
//             switch  (community, shape)
//             {
//             case    (.class, .member(of: _)?), 
//                     (.class,           nil):
//                 self = .one(superclass)
            
//             default: 
//                 // should have thrown a ``ColorError`` earlier
//                 fatalError("unreachable")
//             }
//             for _:Symbol.Role<PluralPosition<Symbol>> in roles 
//             {
//                 fatalError("unreachable")
//             }
//         }
//         else 
//         {
//             switch  (community, shape)
//             {
//             case    (.callable(_),      .requirement(of: _)?), 
//                     (.associatedtype,   .requirement(of: _)?):
//                 self.init(roles)
//                 {
//                     switch $0 
//                     {
//                     case .override(of: let upstream): 
//                         return upstream
//                     default:
//                         fatalError("requirements cannot be default implementations")
//                         // throw PoliticalError.conflict(is: .requirement(of: interface), 
//                         //     and: other)
//                     }
//                 }
            
//             case    (_,                 .requirement(of: _)?):
//                 // should have thrown a ``ColorError`` earlier
//                 fatalError("unreachable")
                
//             case    (.concretetype(_),  nil), 
//                     (.typealias,          _), 
//                     (.global(_),        nil):
//                 for _:Symbol.Role<PluralPosition<Symbol>> in roles
//                 {
//                     fatalError("unreachable") 
//                 }
//                 return nil
            
//             case    (.concretetype(_),  .member(of: _)?), 
//                     (.callable(_),      .member(of: _)?):
//                 self.init(roles)
//                 {
//                     switch $0 
//                     {
//                     case .override(of: let upstream), .implementation(of: let upstream): 
//                         return upstream
//                     default: 
//                         fatalError("unreachable") 
//                     }
//                 }
                
//             case    (.callable(_),      nil):
//                 self.init(roles) 
//                 {
//                     switch $0 
//                     {
//                     case .implementation(of: let upstream): 
//                         return upstream
//                     default: 
//                         fatalError("unreachable") 
//                     }
//                 }
                
//             case    (.protocol,         nil):
//                 self.init(roles)
//                 {
//                     switch $0
//                     {
//                     case .interface(of: let symbol), .refinement(of: let symbol):
//                         return symbol 
//                     default: 
//                         fatalError("unreachable") 
//                     }
//                 }
            
//             default: 
//                 fatalError("unreachable")
//             }
//         }
//     }
// }
// extension Tree.SymbolRoles 
// {
//     func idealized() -> Symbol.Roles<Position<Symbol>>
//     {
//         fatalError("unimplemented")
//     }
// }