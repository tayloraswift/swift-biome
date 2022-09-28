import HTML 
import DOM

extension ArticlePage 
{
    struct _MetadataLoadingError:Error 
    {
    }
}
struct ArticlePage 
{
    let evolution:Evolution
    let culture:ModuleReference
    let metadata:Article.Metadata
    let discussion:[UInt8]?
    let logo:[UInt8]

    init(_ article:Atom<Article>.Position, logo:[UInt8],
        documentation:__shared DocumentationExtension<Never>, 
        evolution:Evolution,
        context:__shared AnisotropicContext, 
        cache:inout ReferenceCache) throws 
    {
        assert(context.local.nationality == article.nationality)

        guard let metadata:Article.Metadata = context.local.metadata(local: article.atom) 
        else 
        {
            throw _MetadataLoadingError.init()
        }

        self.culture = try cache.load(article.culture, context: context)
        self.metadata = metadata
        self.evolution = evolution
        self.logo = logo

        switch 
        (
            try cache.link(documentation.card, context: context),
            try cache.link(documentation.body, context: context)
        )
        {
        case (nil, nil):
            self.discussion = nil
        case (let head?, nil):
            self.discussion = head
        case (let head?, let body?):
            self.discussion = head + body
        case (nil, let body?):
            self.discussion = body
        }
    }

    func render(element:PageElement) -> [UInt8]?
    {
        let html:HTML.Element<Never>?
        switch element
        {
        case .summary: 
            return nil
        case .discussion: 
            return self.discussion
        case .topics: 
            return nil
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
            html = nil 
        case .culture: 
            html = self.culture.html 
        case .dependencies: 
            html = nil
        case .fragments: 
            html = nil
        case .headline: 
            html = .h1(self.metadata.headline.formatted)
        case .host: 
            html = nil 
        case .kind: 
            return [UInt8].init("Article".utf8)
        
        case .meta: 
            html = self.metadata.excerpt.isEmpty ? nil : .meta(attributes: 
            [
                .name("description"), 
                .content(DOM.escape(self.metadata.excerpt)),
            ])
        
        case .nationality: 
            html = .span(self.evolution.current.package.title, 
                attributes: [.class("package")])

        case .notes: 
            html = nil
        case .notices: 
            html = self.evolution.newer?.html
        case .platforms: 
            html = nil
        case .versions: 
            html = self.evolution.items.html
        }
        return html?.node.rendered(as: [UInt8].self)
    }
}