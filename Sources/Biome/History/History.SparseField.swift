// extension History 
// {
//     struct SparseField<Key, Divergence>
//     {
//         let divergent:WritableKeyPath<Divergence, Divergent?>
//         let key:Key
//     }
// }
// extension Dictionary 
// {
//     subscript<Field>(field:History<Field>.SparseField<Key, Value>) -> History<Field>.Divergent?
//     {
//         self[field.key]?[keyPath: field.divergent]
//     }
// }
// extension History<Symbol.ForeignMetadata?>.SparseField 
//     where Divergence == Symbol.ForeignDivergence
// {
//     static 
//     func metadata(of key:Key) -> Self 
//     {
//         .init(divergent: \.metadata, key: key)
//     }
// }
