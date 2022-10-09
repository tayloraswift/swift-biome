import SymbolSource 

struct RawCulturalGraph:Identifiable, Sendable 
{
    let id:ModuleIdentifier 
    var dependencies:[PackageDependency],
        markdown:[MarkdownFile]
    var colonies:[RawColonialGraph]

    init(id:ID, 
        dependencies:[PackageDependency] = [],
        markdown:[MarkdownFile] = [], 
        colonies:[RawColonialGraph] = [])
    {
        self.id = id 
        self.dependencies = dependencies 
        self.markdown = markdown 
        self.colonies = colonies
    }
}
