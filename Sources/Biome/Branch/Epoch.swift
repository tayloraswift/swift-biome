// extension Epoch:Sendable where Element:Sendable 
// {
// }
// @available(*, deprecated)
// struct Epoch<Element>:TrunkPeriod, RandomAccessCollection 
//     where Element:AtomicElement & BranchElement, Element.Divergence:Voidable
// {
//     private 
//     let slice:IntrinsicSlice<Element>
//     /// The last version contained within this epoch.
//     let latest:Version
//     /// The branch and revision this epoch was forked from, 
//     /// if applicable.
//     let fork:Version?

//     init(_ slice:IntrinsicSlice<Element>, 
//         latest:Version, 
//         fork:Version?)
//     {
//         self.slice = slice
//         self.latest = latest
//         self.fork = fork
//     }

//     var divergences:Divergences<Atom<Element>, Element.Divergence> 
//     {
//         .init(self.slice.divergences, latest: self.latest, fork: self.fork)
//     }
    
//     var startIndex:Element.Offset 
//     {
//         self.slice.startIndex
//     }
//     var endIndex:Element.Offset 
//     {
//         self.slice.endIndex
//     }
//     subscript(offset:Element.Offset) -> Element 
//     {
//         _read 
//         {
//             yield   self.slice[offset]
//         }
//     }
//     subscript(atom:Atom<Element>) -> Element? 
//     {
//         _read 
//         {
//             yield   self.slice.indices ~= atom.offset ? 
//                     self.slice[contemporary: atom] : nil
//         }
//     }

//     var atoms:IntrinsicSlice<Element>.Atoms
//     {
//         self.slice.atoms
//     }
    
//     @available(*, deprecated, renamed: "atoms")
//     func atom(of id:Element.ID) -> Atom<Element>? 
//     {
//         self.slice.atoms[id]
//     }
// }