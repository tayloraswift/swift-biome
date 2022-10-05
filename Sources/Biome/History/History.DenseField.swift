// import SymbolGraphs

// extension History 
// {
//     struct DenseField<Element> where Element:BranchElement
//     {
//         let contemporary:WritableKeyPath<Element, Head?>
//         let divergent:WritableKeyPath<Element.Divergence, Divergent?>
//         let element:Atom<Element>
//     }
// }
// extension Dictionary 
// {
//     subscript<Field, Element>(field:History<Field>.DenseField<Element>) 
//         -> History<Field>.Divergent?
//         where Element:BranchElement, Value == Element.Divergence, Key == Atom<Element>
//     {
//         self[field.element]?[keyPath: field.divergent]
//     }
// }

// extension History<Article.Metadata?>.DenseField<Article> 
// {
//     static 
//     func metadata(of element:Atom<Article>) -> Self 
//     {
//         .init(contemporary: \.metadata, divergent: \.metadata, element: element)
//     }
// }
// extension History<DocumentationExtension<Never>>.DenseField<Article> 
// {
//     static 
//     func documentation(of element:Atom<Article>) -> Self 
//     {
//         .init(contemporary: \.documentation, divergent: \.documentation, element: element)
//     }
// }


// extension History<Symbol.Metadata?>.DenseField<Symbol> 
// {
//     static 
//     func metadata(of element:Atom<Symbol>) -> Self 
//     {
//         .init(contemporary: \.metadata, divergent: \.metadata, element: element)
//     }
// }
// extension History<Declaration<Atom<Symbol>>>.DenseField<Symbol> 
// {
//     static 
//     func declaration(of element:Atom<Symbol>) -> Self 
//     {
//         .init(contemporary: \.declaration, divergent: \.declaration, element: element)
//     }
// }
// extension History<DocumentationExtension<Atom<Symbol>>>.DenseField<Symbol> 
// {
//     static 
//     func documentation(of element:Atom<Symbol>) -> Self 
//     {
//         .init(contemporary: \.documentation, divergent: \.documentation, element: element)
//     }
// }


// extension History<Module.Metadata?>.DenseField<Module> 
// {
//     static 
//     func metadata(of element:Atom<Module>) -> Self 
//     {
//         .init(contemporary: \.metadata, divergent: \.metadata, element: element)
//     }
// }
// extension History<Set<Atom<Article>>>.DenseField<Module> 
// {
//     static 
//     func topLevelArticles(of element:Atom<Module>) -> Self 
//     {
//         .init(contemporary: \.topLevelArticles, divergent: \.topLevelArticles, element: element)
//     }
// }
// extension History<Set<Atom<Symbol>>>.DenseField<Module> 
// {
//     static 
//     func topLevelSymbols(of element:Atom<Module>) -> Self 
//     {
//         .init(contemporary: \.topLevelSymbols, divergent: \.topLevelSymbols, element: element)
//     }
// }
// extension History<DocumentationExtension<Never>>.DenseField<Module> 
// {
//     static 
//     func documentation(of element:Atom<Module>) -> Self 
//     {
//         .init(contemporary: \.documentation, divergent: \.documentation, element: element)
//     }
// }