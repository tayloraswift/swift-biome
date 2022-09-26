protocol PackageContext 
{
    subscript(nationality:Package.Index) -> Package.Pinned?
    {
        get 
    }
}

extension Package 
{
    @available(*, deprecated, renamed: "AnisotropicContext")
    typealias Context = AnisotropicContext
}

extension PackageContext 
{
    func load(_ symbol:Atom<Symbol>) -> Symbol?
    {
        self[symbol.nationality]?.load(local: symbol) 
    }

    func documentation(for symbol:inout Atom<Symbol>) -> DocumentationExtension<Never>?
    {
        while   let documentation:DocumentationExtension<Atom<Symbol>> = 
                    self[symbol.nationality]?.documentation(for: symbol)
        {
            guard   documentation.card.isEmpty, 
                    documentation.body.isEmpty 
            else 
            {
                let documentation:DocumentationExtension<Never> = .init(
                    errors: documentation.errors, 
                    card: documentation.card, 
                    body: documentation.body)
                return documentation
            }
            guard   let next:Atom<Symbol> = documentation.extends, 
                        next != symbol // sanity check
            else 
            {
                break 
            }
            symbol = next
        }
        return nil
    }
    func documentation(for symbol:Atom<Symbol>) -> DocumentationExtension<Never>?
    {
        var ignored:Atom<Symbol> = symbol 
        return self.documentation(for: &ignored)
    }
}
