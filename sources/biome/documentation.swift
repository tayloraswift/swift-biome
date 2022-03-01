import Resource
import JSON

extension Biome
{
    public 
    enum ResourceVersionError:Error 
    {
        case missing
    }
    public 
    struct ResourceTypeError:Error 
    {
        let expected:String, 
            encountered:String 
        init(_ encountered:String, expected:String)
        {
            self.expected       = expected
            self.encountered    = encountered
        }
    }
    
    public 
    enum Response 
    {
        case canonical(Resource)
        case found(String)
    }
    public 
    struct Diagnostics 
    {
        var uri:String
        
        mutating 
        func warning(_ string:String)
        {
            print("(\(self.uri)): \(string)")
        }
    }
    public 
    struct Documentation:Sendable
    {
        enum Index 
        {
            case package(Int)
            case module(Int)
            case symbol(Int)
        }
        
        let biome:Biome
        let symbols:[Article], 
            modules:[Article], 
            packages:[Article]
        let routes:[Path: Index]
        public 
        let search:JSON
        
        public 
        init(packages:[Package.ID: [String]], prefix:[String], 
            loader load:(_ package:Package.ID, _ module:String) async throws -> Resource) async throws 
        {
            let (biome, comments):(Biome, [String]) = try await Biome.load(packages: packages, 
                prefix: prefix.map{ $0.lowercased() }, 
                loader: load)
            
            // render articles 
            self.symbols            = zip(biome.symbols.indices, comments).map 
            {
                biome.article(symbol: $0.0, comment: $0.1) 
            }
            self.modules            =     biome.modules.indices.map 
            {
                biome.article(module: $0, comment: "") 
            }
            self.packages           =     biome.packages.indices.map 
            {
                biome.article(package: $0, comment: "") 
            }
            self.biome              = _move(biome)
            self.search             = .array(self.biome.search.map 
            { 
                .object(["uri": .string($0.uri), "title": .string($0.title), "text": .array($0.text.map(JSON.string(_:)))]) 
            })
            // paths (combined)
            var routes:[Path: Index] = [:]
            for package:Int in self.biome.packages.indices
            {
                guard case nil = routes.updateValue(.package(package), forKey: self.biome.packages[package].path)
                else 
                {
                    fatalError("unreachable")
                }
            }
            for module:Int in self.biome.modules.indices
            {
                guard case nil = routes.updateValue(.module(module), forKey: self.biome.modules[module].path)
                else 
                {
                    fatalError("unreachable")
                }
            }
            for symbol:Int in self.biome.symbols.indices
            {
                guard case nil = routes.updateValue(.symbol(symbol), forKey: self.biome.symbols[symbol].path)
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
                for index:Int in module.allSymbols.joined()
                {
                    errors += self.symbols[index].errors.count
                }
                if errors > 0 
                {
                    print("note: \(errors) linter warnings(s) in module '\(module.id.identifier)'")
                }
            }
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
        public 
        subscript(group:String, disambiguation disambiguation:String?) -> Response?
        {
            let path:Path  = .init(group: Biome.normalize(path: group), 
                disambiguation: disambiguation.map(Symbol.ID.init(_:)))
            if let index:Index = self.routes[path]
            {
                return path.group == group ? .canonical(self[index]) : .found(path.canonical)
            }
            guard let key:Symbol.ID = path.disambiguation
            else 
            {
                return nil 
            }
            //  we were given a bad path + disambiguation key combo, 
            //  but the query might still be valid 
            if let symbol:Symbol = self.biome.symbols[key]
            {
                return .found(symbol.path.canonical)
            }
            //  we were given an extraneous disambiguation key, but the path might 
            //  still be valid
            let truncated:Path = .init(group: path.group)
            if case _? = self.routes[truncated]
            {
                return .found(truncated.canonical)
            }
            else 
            {
                return nil
            }
        }
        subscript(index:Index) -> Resource 
        {
            switch index 
            {
            case .package(let index): 
                return self.biome.page(package: index, article: self.packages[index])
            case .module(let index): 
                return self.biome.page(module: index, article: self.modules[index], articles: self.symbols)
            case .symbol(let index):
                return self.biome.page(symbol: index, articles: self.symbols)
            }
        }
    }
}
