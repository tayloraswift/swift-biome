import HTML
import Resources

extension Ecosystem 
{
    static 
    var logo:[UInt8]
    {
        let logo:HTML.Element<Never> = .ol(items: [.li(.a(
        [
            .text(escaped: "swift"), 
            .container(.i, content: [.text(escaped: "init")])
        ]) 
        { 
            ("class", "logo") 
            ("href", "/")
        })])
        
        return logo.rendered(as: [UInt8].self)
    }
    
    @usableFromInline 
    func response(for resolution:Ecosystem.Resolution, canonical uri:URI) -> StaticResponse 
    {
        let _template:DOM.Template<Page.Key> = self.templates[.master]!
        switch resolution 
        {
        case .index(let index, pins: let pins, exhibit: let exhibit): 
            var page:Page = .init(ecosystem: self, pins: pins)
                page.generate(for: index, exhibit: exhibit)
                page.add(scriptConstants: self.caches.keys)
            return .matched(.init(_template.rendered(as: [UInt8].self, 
                        substituting: _move(page).substitutions), 
                    type: .utf8(encoded: .html)), 
                canonical: uri.description)
        
        case .choices(let choices, pins: let pins): 
            var page:Page = .init(ecosystem: self, pins: pins)
                page.generate(for: choices, uri: uri)
                page.add(scriptConstants: self.caches.keys)
            return .multiple(.init(_template.rendered(as: [UInt8].self, 
                        substituting: _move(page).substitutions), 
                    type: .utf8(encoded: .html)))
        
        case .resource(let resource, uri: let uri): 
            return .matched(resource, canonical: uri.description) 
        }
    }
}
