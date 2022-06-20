extension Package 
{
    struct Pinned:Sendable 
    {
        let package:Package 
        let version:Version
        
        init(_ package:Package, at version:Version)
        {
            self.version = version  
            self.package = package
        }
        
        func template() -> Article.Template<Link>
        {
            self.package.templates.at(self.version, head: self.package.heads.template) ?? 
                .init()
        }
        func template(_ module:Module.Index) -> Article.Template<Link>
        {
            self.package.templates
                .at(self.version, head: self.package[local: module].heads.template) ?? 
                .init()
        }
        func template(_ symbol:Symbol.Index) -> Article.Template<Link>
        {
            self.package.templates
                .at(self.version, head: self.package[local: symbol].heads.template) ?? 
                .init()
        }
        
        func dependencies(_ module:Module.Index) -> Set<Module.Index>
        {
            // `nil` case should be unreachable in practice
            self.package.dependencies
                .at(self.version, head: self.package[local: module].heads.dependencies) ?? []
        }
        func toplevel(_ module:Module.Index) -> Set<Symbol.Index>
        {
            // `nil` case should be unreachable in practice
            self.package.toplevels
                .at(self.version, head: self.package[local: module].heads.toplevel) ?? []
        }
        
        func declaration(_ symbol:Symbol.Index) -> Symbol.Declaration
        {
            // `nil` case should be unreachable in practice
            self.package.declarations
                .at(self.version, head: self.package[local: symbol].heads.declaration) ?? 
                .init(fallback: "<unavailable>")
        }
        func facts(_ symbol:Symbol.Index) -> Symbol.Predicates 
        {
            // `nil` case should be unreachable in practice
            self.package.facts
                .at(self.version, head: self.package[local: symbol].heads.facts) ?? 
                .init(roles: nil)
        }
        
        func contains(_ composite:Symbol.Composite) -> Bool 
        {
            self.package.contains(composite, at: self.version)
        }
    }
}
