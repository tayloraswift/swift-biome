import SymbolSource

@frozen public
struct SnippetFile:Equatable
{
    public
    let name:ModuleIdentifier
    public
    let source:String
    public
    let dependencies:[PackageDependency]

    init(name:ModuleIdentifier, source:String, dependencies:[PackageDependency])
    {
        self.name = name
        self.dependencies = dependencies
        self.source = source
    }
}