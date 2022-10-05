import SymbolGraphs

struct FieldAccessor<Element, Key, Value> where Element:BranchElement
{
    let alternate:WritableKeyPath<Element.Divergence, AlternateHead<Value>?>
    let original:WritableKeyPath<Element, OriginalHead<Value>?>
    let key:Key

    init(_ key:Key,
        _ original:WritableKeyPath<Element, OriginalHead<Value>?>,
        _ alternate:WritableKeyPath<Element.Divergence, AlternateHead<Value>?>)
    {
        self.alternate = alternate
        self.original = original 
        self.key = key 
    }
}
extension FieldAccessor<Overlay, Diacritic, Overlay.Metadata?>
{
    static 
    func metadata(of key:Key) -> Self
    {
        .init(key, \.metadata, \.metadata)
    }
}

extension FieldAccessor<Article, Atom<Article>, Article.Metadata?>
{
    static 
    func metadata(of key:Atom<Article>) -> Self
    {
        .init(key, \.metadata, \.metadata)
    }
}
extension FieldAccessor<Article, Atom<Article>, DocumentationExtension<Never>>
{
    static 
    func documentation(of key:Atom<Article>) -> Self
    {
        .init(key, \.documentation, \.documentation)
    }
}


extension FieldAccessor<Symbol, Atom<Symbol>, Symbol.Metadata?>
{
    static 
    func metadata(of key:Atom<Symbol>) -> Self
    {
        .init(key, \.metadata, \.metadata)
    }
}
extension FieldAccessor<Symbol, Atom<Symbol>, Declaration<Atom<Symbol>>>
{
    static 
    func declaration(of key:Atom<Symbol>) -> Self
    {
        .init(key, \.declaration, \.declaration)
    }
}
extension FieldAccessor<Symbol, Atom<Symbol>, DocumentationExtension<Atom<Symbol>>>
{
    static 
    func documentation(of key:Atom<Symbol>) -> Self
    {
        .init(key, \.documentation, \.documentation)
    }
}


extension FieldAccessor<Module, Atom<Module>, Module.Metadata?>
{
    static 
    func metadata(of key:Atom<Module>) -> Self
    {
        .init(key, \.metadata, \.metadata)
    }
}
extension FieldAccessor<Module, Atom<Module>, Set<Atom<Article>>>
{
    static 
    func topLevelArticles(of key:Atom<Module>) -> Self
    {
        .init(key, \.topLevelArticles, \.topLevelArticles)
    }
}
extension FieldAccessor<Module, Atom<Module>, Set<Atom<Symbol>>>
{
    static 
    func topLevelSymbols(of key:Atom<Module>) -> Self
    {
        .init(key, \.topLevelSymbols, \.topLevelSymbols)
    }
}
extension FieldAccessor<Module, Atom<Module>, DocumentationExtension<Never>>
{
    static 
    func documentation(of key:Atom<Module>) -> Self
    {
        .init(key, \.documentation, \.documentation)
    }
}