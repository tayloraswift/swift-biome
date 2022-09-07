// extension Branch 
// {
//     struct API<Element> where Element:Hashable
//     {
//         private(set)
//         var missing:Set<Element>

//         init()
//         {
//             self.missing = []
//         }

//         mutating 
//         func expect(_ apis:some Sequence<Tree.Position<Element>>)
//         {
//             self.missing.formUnion(apis.lazy.map(\.contemporary))
//         }

//         mutating 
//         func confirm(_ apis:some Sequence<Tree.Position<Element>>)
//         {
//             self.missing.subtract(apis.lazy.map(\.contemporary))
//         }
//         mutating 
//         func confirm(_ apis:some Sequence<Tree.Position<Element>?>)
//         {
//             self.missing.subtract(apis.lazy.compactMap { $0?.contemporary })
//         }
//         mutating 
//         func confirm(_ api:Tree.Position<Element>)
//         {
//             self.missing.remove(api.contemporary)
//         }
//     }
// }