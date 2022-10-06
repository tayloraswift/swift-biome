import SymbolSource

public 
struct Module:Intrinsic, Identifiable, Sendable
{
    public 
    typealias Culture = Packages.Index 
    public 
    typealias Offset = UInt16

    public
    let id:ModuleIdentifier
    let culture:Atom<Module>
    /// Indicates if this module should be served directly from the site root. 
    var isFunction:Bool

    init(id:ModuleIdentifier, culture:Atom<Module>)
    {
        self.id = id 
        self.culture = culture
        self.isFunction = false
    }
}
extension Module
{
    var path:Path 
    {
        .init(last: self.id.string)
    }
    var nationality:Packages.Index 
    {
        self.culture.nationality
    }
}