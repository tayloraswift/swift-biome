import HTML 

struct ModulePage 
{
    let evolution:Evolution

    let nationality:PackageReference
    let culture:ModuleReference

    let overview:[UInt8]?
    let discussion:[UInt8]?
    let topics:[UInt8]?
    let logo:[UInt8]

    init(_ module:Atom<Module>.Position, logo:[UInt8],
        documentation:__shared DocumentationExtension<Never>, 
        evolution:Evolution,
        context:__shared AnisotropicContext, 
        cache:inout ReferenceCache) throws 
    {
        assert(context.local.nationality == module.nationality)

        self.logo = logo
        self.evolution = evolution
        self.nationality = try cache.load(module.nationality, context: context)
        self.culture = try cache.load(module, context: context)

        self.overview = try cache.link(documentation.card, context: context)
        self.discussion = try cache.link(documentation.body, context: context)

        let topics:Organizer.Topics = try .init(for: module.atom, 
            context: context, 
            cache: &cache)
        self.topics = try topics.html(context: context, cache: &cache)?.node
            .rendered(as: [UInt8].self)
    }

    func render(element:PageElement) -> [UInt8]?
    {
        let html:HTML.Element<Never>?
        switch element
        {
        case .overview: 
            return self.overview
        case .discussion: 
            return self.discussion
        case .topics: 
            return self.topics
        case .title: 
            fatalError("unimplemented") 
        case .constants: 
            fatalError("unimplemented") 
        case .availability: 
            return nil 
        case .base: 
            return nil
        
        case .branch: 
            html = .span(self.evolution.current.branch.description, 
                attributes: [.class("version")]) 

        case .breadcrumbs: 
            return self.logo
        case .consumers: 
            return nil 
        case .culture: 
            html = self.nationality.html 
        case .dependencies: 
            return nil
        case .fragments: 
            return nil
        case .headline: 
            html = .h1(self.culture.name.string)
        case .host: 
            return nil 
        case .kind: 
            return [UInt8].init("Module".utf8)
        
        case .meta: 
            return nil
        
        case .nationality: 
            html = .span(self.evolution.current.package.title, 
                attributes: [.class("package")])

        case .notes: 
            return nil
        case .notices: 
            html = self.evolution.newer?.html
        case .platforms: 
            return nil
        case .versions: 
            html = self.evolution.items.html
        }
        return html?.node.rendered(as: [UInt8].self)
    }
}