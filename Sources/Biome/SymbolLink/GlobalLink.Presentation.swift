extension GlobalLink
{
    enum Presentation:Hashable, Sendable
    {
        case article(Atom<Article>)
        case module(Atom<Module>)
        case package(Packages.Index)
        case composite(Composite, visible:Int)

        init(_ target:Target, visible:Int)
        {
            switch target 
            {
            case .article(let article):
                self = .article(article)
            case .module(let module):
                self = .module(module)
            case .package(let package):
                self = .package(package)
            case .composite(let composite):
                self = .composite(composite, visible: visible)
            }
        }
    }
}