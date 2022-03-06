import Resource
import JSON

extension Biome
{
    public 
    struct Documentation:Sendable
    {
        typealias Route = (index:Index, canonical:Path?)
        enum Index:Hashable, Sendable 
        {
            case packageSearchIndex(Int)
            case package(Int)
            case module(Int)
            case symbol(Int)
        }
        
        let biome:Biome
        let symbols:[Article], 
            modules:[Article], 
            packages:[(article:Article, searchIndex:Resource)]
        let routes:[Path: Route]
        
        public 
        init(packages:[Package.ID: [String]], prefix:[String], 
            loader load:(_ package:Package.ID, _ module:String) async throws -> Resource) async throws 
        {
            let (biome, comments):(Biome, [String]) = try await Biome.load(packages: packages, 
                prefix: prefix.map{ $0.lowercased() }, 
                loader: load)
            
            // render articles 
            self.symbols            = zip(biome.symbols.indices, _move(comments)).map 
            {
                biome.article(symbol: $0.0, comment: $0.1) 
            }
            self.modules            =     biome.modules.indices.map 
            {
                biome.article(module: $0, comment: "") 
            }
            self.packages           =     biome.packages.indices.map 
            {
                (
                    article:              biome.article(package: $0, comment: ""),
                    searchIndex:          biome.searchIndex(for: biome.packages[$0])
                )
            }
            self.biome              = _move(biome)
            
            // paths (combined)
            var routes:[Path: Route] = [:]
            for (index, package):(Int, Package) in zip(self.biome.packages.indices, self.biome.packages)
            {
                guard   case nil = routes.updateValue((.package(index), nil), forKey: package.path), 
                        case nil = routes.updateValue((.packageSearchIndex(index), nil), forKey: package.search)
                else 
                {
                    fatalError("unreachable")
                }
                // insert the 'standard-library' -> 'swift-standard-library' redirect 
                if case .swift = package.id 
                {
                    guard   case nil = routes.updateValue((.package(index), package.path), 
                            forKey: Path.init(prefix: prefix, package: .community("standard-library"))), 
                            case nil = routes.updateValue((.package(index), package.path), 
                            forKey: Path.init(prefix: prefix, package: .community("swift-stdlib"))),
                            case nil = routes.updateValue((.package(index), package.path), 
                            forKey: Path.init(prefix: prefix, package: .community("stdlib")))
                    else 
                    {
                        fatalError("unreachable")
                    }
                }
            }
            for module:Int in self.biome.modules.indices
            {
                guard case nil = routes.updateValue((.module(module), nil), forKey: self.biome.modules[module].path)
                else 
                {
                    fatalError("unreachable")
                }
            }
            for symbol:Int in self.biome.symbols.indices
            {
                guard case nil = routes.updateValue((.symbol(symbol), nil), forKey: self.biome.symbols[symbol].path)
                else 
                {
                    fatalError("unreachable")
                }
            }
            self.routes = routes
            
            var _memory:Int 
            {
                self.modules.reduce(0)
                {
                    $0 + $1.size
                }
                +
                self.symbols.reduce(0)
                {
                    $0 + $1.size
                }
            }
            print("rendered \(self.modules.count + self.symbols.count) articles (\(_memory >> 10) KB)")
            
            for module:Module in self.biome.modules
            {
                var errors:Int = 0
                for index:Int in module.allSymbols
                {
                    errors += self.symbols[index].errors.count
                }
                if errors > 0 
                {
                    print("note: \(errors) linter warnings(s) in module '\(module.id.identifier)'")
                }
            }
        }
        
        public 
        subscript(uri:(path:String, query:Substring?), referrer referrer:(path:String, query:Substring?)? = nil)
            -> (content:Resource?, canonical:String)?
        {
            let (path, redirected):(Path, Bool) = Path.normalize(uri.path, parameters: uri.query)
            guard let (index, canonical):(Index, Path?) = self.routes[path]
            else 
            {
                guard let symbol:Symbol.ID = path.disambiguation
                else 
                {
                    //  we did not find the resource, and we have no other method 
                    //  of locating it
                    return nil 
                }
                if let path:Path    = self.biome.symbols[symbol]?.path
                {
                    //  we were given a bad path + disambiguation key combo, 
                    //  but the disambiguation key matched a symbol. 
                    //  respond with a 301 redirect to the actual URI of that symbol 
                    return (nil, path.description)
                }
                let truncated:Path  = .init(group: path.group)
                if case (_, let canonical)? = self.routes[truncated]
                {
                    //  we were given an extraneous disambiguation key, but the path 
                    //  itself was still valid.  
                    return (nil, (canonical ?? truncated).description)
                }
                else 
                {
                    return nil
                }
            }
            //  we found the resource. if we had to significantly alter the uri, 
            //  (e.g., discarding unknown query parameters), force a 301 redirect. 
            if let canonical:Path = _move(canonical)
            {
                return (nil, canonical.description)
            }
            else if redirected 
            {
                return (nil, path.description)
            }
            //  if the uri was already canonical, or only differed in 
            //  percent-encoding, return the resource, but include the canonical uri
            //let (referrer, _):(Path, Bool) = Path.normalize(referrer.path, parameters: referrer.query)
            let resource:Resource
            switch index 
            {
            case .packageSearchIndex(let package): 
                resource = self.packages[package].searchIndex
            case .package(let package): 
                let _filter:[Package.ID] = self.biome.packages.map(\.id)
                resource = self.biome.page(package: package, article: self.packages[package].article, filter: _filter)
            case .module(let module): 
                let _filter:[Package.ID] = self.biome.packages.map(\.id)
                resource = self.biome.page(module: module, article: self.modules[module], articles: self.symbols, filter: _filter)
            case .symbol(let symbol):
                let _filter:[Package.ID] = self.biome.packages.map(\.id)
                resource = self.biome.page(symbol: symbol, articles: self.symbols, filter: _filter)
            }
            return (resource, path.description)
        }
        /// the `group` is the full URL path, without the query, and including 
        /// the beginning slash '/' and path prefix. 
        /// the path *must* be normalized with respect to slashes, but it 
        /// *must not* be percent-decoded. (otherwise the user may be sent into 
        /// an infinite redirect loop.)
        ///
        /// '/reference/swift-package/somemodule/foo/bar.baz%28_%3A%29':    OK (canonical page for `SomeModule.Foo.Bar.baz(_:)`)
        /// '/reference/swift-package/somemodule/foo/bar.baz(_:)':          OK (301 redirect to `SomeModule.Foo.Bar.baz(_:)`)
        /// '/reference/swift-package/SomeModule/FOO/BAR.BAZ(_:)':          OK (301 redirect to `SomeModule.Foo.Bar.baz(_:)`)
        /// '/reference/swift-package/somemodule/foo/bar%2Ebaz%28_%3A%29':  OK (301 redirect to `SomeModule.Foo.Bar.baz(_:)`)
        /// '/reference/swift-package/somemodule/foo//bar.baz%28_%3A%29':   Error (slashes not normalized)
        ///
        /// note: the URL of a page for an operator containing a slash '/' *must*
        /// be percent-encoded; Biome will not be able to redirect it to the 
        /// correct canonical URL. 
        ///
        /// note: the URL path is case-insensitive, but the disambiguation query 
        /// *is* case-sensitive. the `disambiguation` parameter should include 
        /// the mangled name only, without the `?overload=` part. if you provide 
        /// a valid disambiguation query, the URL path can be complete garbage; 
        /// Biome will respond with a 301 redirect to the correct page.
    }
}
