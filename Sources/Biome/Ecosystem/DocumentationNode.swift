enum DocumentationNode:Sendable, Equatable
{
    case inherits(Branch.Position<Symbol>)
    case extends(Branch.Position<Symbol>?, with:Article.Template<Ecosystem.Link>)
}