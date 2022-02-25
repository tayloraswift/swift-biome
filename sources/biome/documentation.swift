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
        case canonical(Page)
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
        typealias Index = Dictionary<Symbol.Path, Page>.Index 
        
        let pages:[Symbol.Path: Page]
        let biome:Biome
        
        public 
        let search:JSON
        
        public 
        init(packages names:[String?: [String]], prefix:[String], 
            loader load:(_ package:String?, _ module:String) async throws -> Resource) async throws 
        {
            var symbols:[SymbolDescriptor] = []
            var graphs:[(graph:Graph, symbols:Range<Int>, edges:[Edge])] = []
            var packages:[String?: (modules:[Module.ID: [Range<Int>]], hash:Resource.Version)] = [:]
            for (package, names):(String?, [String]) in names
            {
                var modules:[Module.ID: [Range<Int>]]   = [:],
                    version:Resource.Version            = .semantic(0, 1, 1)
                for name:String in names 
                {
                    let identifiers:[Substring] = name.split(separator: "@")
                    guard let module:Substring = identifiers.first 
                    else 
                    {
                        continue // name was all '@' signs
                    }
                    
                    let json:JSON
                    
                    switch try await load(package, name)
                    {
                    case    .text   (let string, type: .json, version: let component?):
                        json = try Grammar.parse(string.utf8, as: JSON.Rule<String.Index>.Root.self)
                        version *= component
                    case    .bytes  (let bytes, type: .json, version: let component?):
                        json = try Grammar.parse(bytes, as: JSON.Rule<Array<UInt8>.Index>.Root.self)
                        version *= component
                    case    .text   (_, type: .json, version: nil),
                            .bytes  (_, type: .json, version: nil):
                        throw ResourceVersionError.missing
                    case    .text   (_, type: let type, version: _),
                            .bytes  (_, type: let type, version: _):
                        throw ResourceTypeError.init(type.description, expected: Resource.Text.json.description)
                    case    .binary (_, type: let type, version: _):
                        throw ResourceTypeError.init(type.description, expected: Resource.Text.json.description)
                    }
                    var descriptor:ModuleDescriptor = try Biome.decode(module: json)
                    switch identifiers.dropFirst().first 
                    {
                    case "Swift"?:
                        descriptor.graph.bystander = .swift
                    case "_Concurrency"?:
                        descriptor.graph.bystander = .concurrency
                    case let bystander?:
                        descriptor.graph.bystander = .community(String.init(bystander))
                    case nil: 
                        break 
                    }
                    guard descriptor.graph.module.identifier == module 
                    else 
                    {
                        throw ModuleIdentifierError.mismatch(decoded: descriptor.graph.module, expected: String.init(module))
                    }
                    let start:Int   = symbols.endIndex
                    for symbol:SymbolDescriptor in descriptor.symbols 
                    {
                        symbols.append(symbol)
                    }
                    let end:Int     = symbols.endIndex
                    modules[descriptor.graph.module, default: []].append(start ..< end)
                    graphs.append((descriptor.graph, start ..< end, descriptor.edges))
                }
                packages[package] = (modules, version)
            }
            
            print("parsed JSON")
            var biome:Biome = try .init(prefix: prefix.map{ $0.lowercased() }, 
                symbols: symbols, graphs: graphs, packages: packages)
            
            var diagnostics:Diagnostics = .init(uri: "/")
            // rendering must take place in two passes, since pages can include 
            // snippets of other pages 
            for index:Int in biome.symbols.indices 
            {
                guard !biome[index].comment.text.isEmpty
                else 
                {
                    continue 
                }
                diagnostics.uri = biome[index].path.canonical 
                biome[index].comment.processed = biome.render(
                    markdown: biome[index].comment.text, 
                //    parameters: biome[index].parameters, 
                    diagnostics: &diagnostics)
            }
            self.init(biome: biome)
        }
        
        init(biome:Biome) 
        {
            // paths are always unique at this point 
            let pages:[Symbol.Path: Page] = .init(uniqueKeysWithValues: 
                biome.symbols.map { ($0.path, biome.render($0)) })
            self.biome  = biome
            self.pages  = _move(pages)
            self.search = .array(biome.search.map 
            { 
                .object(["uri": .string($0.uri), "title": .string($0.title), "text": .array($0.text.map(JSON.string(_:)))]) 
            })
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
            let path:Symbol.Path  = .init(group: Biome.normalize(path: group), 
                disambiguation: disambiguation.map(Symbol.ID.init(_:)))
            if let page:Page = self.pages[path]
            {
                return path.group == group ? .canonical(page) : .found(path.canonical)
            }
            guard let key:Symbol.ID = path.disambiguation
            else 
            {
                return nil 
            }
            //  we were given a bad path + disambiguation key combo, 
            //  but the query might still be valid 
            if let symbol:Symbol = self.biome[id: key]
            {
                return .found(symbol.path.canonical)
            }
            //  we were given an extraneous disambiguation key, but the path might 
            //  still be valid
            let truncated:Symbol.Path = .init(group: path.group)
            if case _? = self.pages[truncated]
            {
                return .found(truncated.canonical)
            }
            else 
            {
                return nil
            }
        }
    }
}
