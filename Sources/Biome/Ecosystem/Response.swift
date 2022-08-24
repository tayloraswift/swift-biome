import HTML
import Resources
import WebSemantics
import URI

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

    public 
    subscript(request:URI) -> Response<Resource>
    {
        let resolution:Resolution, 
            temporary:Bool 
        
        let path:[String] = request.path.normalized.components
        let query:[URI.Parameter] = request.query ?? []

        if let direct:(Resolution, Bool) = self.resolve(path: path, query: query)
        {
            (resolution, temporary) = direct 
        }
        else 
        {
            let normalized:URI = .init(path: path, query: query.isEmpty ? nil : query)
            switch self.redirects[normalized.description]
            {
            case nil: 
                return .init(uri: normalized.description, results: .none, 
                    payload: .init("page not found.")) 
            case .resource(let resource)?: 
                resolution = .resource(resource, uri: normalized)
            case .index(let index, pins: let pins, template: let template)?:
                resolution = .index(index, pins: pins, template: template)
            }
            temporary = false 
        }

        let uri:String, 
            results:Canonicity<String>, 
            redirection:Redirection<Resource>
        switch resolution 
        {        
        case .index(let index, let pins, exhibit: let exhibit, template: let template):
            let (normalized, canonical):(URI, URI?) = 
                self.uri(of: index, pins: pins, exhibit: exhibit)
            
            uri = normalized.description
            results = .one(canonical?.description ?? uri)

            guard normalized ~= request 
            else 
            {
                redirection = temporary ? .temporary : .permanent
                break 
            }

            let template:DOM.Template<Page.Key> = template ?? self.template
            var page:Page = .init(ecosystem: self, pins: pins)
                page.generate(for: index, exhibit: exhibit)
                page.add(scriptConstants: self.caches.keys)
            
            redirection = .none(.init(template.rendered(as: [UInt8].self, 
                    substituting: (_move page).substitutions), 
                type: .utf8(encoded: .html)))
            
        case .choices(let choices, let pins):
            let normalized:URI = self.uri(of: choices, pins: pins)

            uri = normalized.description
            results = .many

            guard normalized ~= request 
            else 
            {
                redirection = temporary ? .temporary : .permanent
                break 
            }

            var page:Page = .init(ecosystem: self, pins: pins)
                page.generate(for: choices, uri: normalized)
                page.add(scriptConstants: self.caches.keys)
            
            redirection = .none(.init(self.template.rendered(as: [UInt8].self, 
                    substituting: (_move page).substitutions), 
                type: .utf8(encoded: .html)))
        
        case .resource(let resource, uri: let normalized): 
            uri = normalized.description 
            results = .one(uri)
            redirection = .none(resource)
        }

        return .init(uri: uri, results: results, redirection: redirection)
    }
    
    private 
    func uri(of index:Index, pins:Package.Pins, exhibit:Version?) 
        -> (exact:URI, canonical:URI?) 
    {
        let pinned:Package.Pinned = .init(self[pins.local.package], 
            at: pins.local.version, 
            exhibit: exhibit)
        let uri:URI
        switch index 
        {
        case .composite(let composite):
            uri = self.uri(of: composite, in: pinned)
            guard composite.isNatural 
            else 
            {
                // if this is a synthetic feature, set the canonical page to 
                // its generic base (which may be in a completely different package)
                let canonical:URI = self.uri(of: .init(natural: composite.base), 
                    in: self[composite.base.module.package].pinned())
                return (exact: uri, canonical: canonical)
            }
        
        case .article(let article):
            uri = self.uri(of: article, in: pinned)
            
        case .module(let module):
            uri = self.uri(of: module, in: pinned)
        
        case .package(_):
            uri = self.uri(of: pinned)
        }
        
        if pinned.version == pinned.package.versions.latest 
        {
            return (exact: uri, nil)
        }
        else
        {
            // if this is an old version, set the canonical version to 
            // the latest version 
            return (exact: uri, self.uri(of: index, in: pinned.package.pinned()))
        }
    }
    private 
    func uri(of index:Index, in pinned:Package.Pinned) -> URI 
    {
        switch index 
        {
        case .composite(let composite):
            return self.uri(of: composite, in: pinned)
        case .article(let article):
            return self.uri(of: article, in: pinned)
        case .module(let module):
            return self.uri(of: module, in: pinned)
        case .package(_):
            return self.uri(of: pinned)
        }
    }
}
