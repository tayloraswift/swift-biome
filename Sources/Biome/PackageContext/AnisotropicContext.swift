import SymbolSource 

protocol AnisotropicContext:PackageContext
{
    var local:Package.Pinned { get }
    var foreign:[Packages.Index: Package.Pinned] { get }

    init(local:Package.Pinned, context:__shared Packages) 
}
extension AnisotropicContext 
{
    init(local:Packages.Index, version:Version, context:__shared Packages) 
    {
        self.init(local: .init(context[local], version: version), context: context)
    }
}
extension AnisotropicContext 
{
    subscript(nationality:Packages.Index) -> Package.Pinned?
    {
        _read 
        {
            yield   self.local.nationality == nationality ? 
                    self.local : self.foreign[nationality]
        }
    }
}
extension AnisotropicContext
{
    func find(_ id:SymbolIdentifier, linked:Set<Atom<Module>>) -> (Atom<Symbol>.Position, Symbol)?
    {
        if  let position:Atom<Symbol>.Position = self.local.symbols.find(id), 
                linked.contains(position.culture)
        {
            return (position, self.local.package.tree[local: position]) 
        }
        for upstream:Package.Pinned in self.foreign.values 
        {
            if  let position:Atom<Symbol>.Position = upstream.symbols.find(id), 
                    linked.contains(position.culture)
            {
                return (position, upstream.package.tree[local: position])
            }
        }
        return nil
    }
}