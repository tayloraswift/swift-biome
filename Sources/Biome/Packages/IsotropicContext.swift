struct IsotropicContext:Sendable 
{
    private 
    let anisotropic:AnisotropicContext 

    init(_ anisotropic:AnisotropicContext)
    {
        self.anisotropic = anisotropic
    }
}
extension IsotropicContext:PackageContext
{
    subscript(nationality:Package.Index) -> Package.Pinned?
    {
        _read 
        {
            yield self.anisotropic[nationality]
        }
    }
}
extension IsotropicContext
{
    // func find(_ id:Symbol.ID, linked:Set<Atom<Module>>) -> (Atom<Symbol>.Position, Symbol)?
    // {
    //     self.anisotropic.find(id, linked: linked)
    // }
}