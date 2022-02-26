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
        let biome:Biome
        let symbols:[Article], 
            modules:[Article]
        public 
        let search:JSON
        
        private static 
        func modules(_ packages:[String?: [String]]) -> 
        (
            packages:[(String?, Range<Int>)],
            modules:[(module:Module.ID, bystanders:[Module.ID])]
        )
        {
            var modules:[(Module.ID, [Module.ID])]  = []
            let packages:[(String?, Range<Int>)]    = packages.map 
            {
                var targets:[Module.ID: [Module.ID]] = [:]
                for name:String in $0.value 
                {
                    let identifiers:[Module.ID] = name.split(separator: "@").map(Module.ID.init(_:))
                    guard let module:Module.ID  = identifiers.first 
                    else 
                    {
                        continue // name was all '@' signs
                    }
                    let bystanders:ArraySlice<Module.ID> = identifiers.dropFirst()
                    targets[module, default: []].append(contentsOf: bystanders.prefix(1))
                }
                let start:Int   = modules.endIndex 
                modules.append(contentsOf: targets.map { ($0.key, $0.value) })
                let end:Int     = modules.endIndex 
                return ($0.key, start ..< end)
            }
            return (packages, modules)
        }
        
        private static 
        func indices(for targets:[Target]) throws -> [Module.ID: Module.Index]
        {
            var indices:[Module.ID: Module.Index] = [:]
            for (index, target):(Int, Target) in targets.enumerated()
            {
                guard case nil = indices.updateValue(.init(index), forKey: target.module)
                else
                {
                    throw ModuleIdentifierError.duplicate(module: target.module)
                }
            }
            return indices
        }
        
        public 
        init(packages names:[String?: [String]], prefix:[String], 
            loader load:(_ package:String?, _ module:String) async throws -> Resource) async throws 
        {
            let prefix:[String] = prefix.map{ $0.lowercased() }
            
            let (names, targets):([(String?, Range<Int>)], [Target]) = Self.modules(names)
            let indices:[Module.ID: Module.Index] = try Self.indices(for: targets)
            var vertices:[Vertex] = []
            var modules:[Module] = []
            var edges:[Edge] = []
            var packages:[String?: (modules:Range<Module.Index>, hash:Resource.Version)] = [:]
            for package:(name:String?, targets:Range<Int>) in names 
            {
                var version:Resource.Version = .semantic(0, 1, 1)
                for target:(module:Module.ID, bystanders:[Module.ID]) in targets[package.targets]
                {
                    func graph(name:String) async throws -> Range<Int>
                    {
                        let json:JSON
                        switch try await load(package.name, name)
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
                        let descriptor:(module:Module.ID, vertices:[Vertex], edges:[Edge]) = try Biome.decode(module: json)
                        guard descriptor.module == target.module 
                        else 
                        {
                            throw ModuleIdentifierError.mismatch(decoded: descriptor.module, expected: target.module)
                        }
                        edges.append(contentsOf: descriptor.edges)
                        let start:Int   = vertices.endIndex
                        vertices.append(contentsOf: descriptor.vertices)
                        let end:Int     = vertices.endIndex
                        return start ..< end
                    }
                    let stem:String     = target.module.identifier 
                    let core:Range<Int> = try await graph(name: stem)
                    var extensions:[(bystander:Module.Index, symbols:Range<Int>)] = [] 
                    for bystander:Module.ID in target.bystanders
                    {
                        // reconstruct the name
                        let name:String                 = "\(stem)@\(bystander.identifier)"
                        guard let index:Module.Index    = indices[bystander]
                        else 
                        {
                            // a module extends a bystander module we do not have the 
                            // primary symbolgraph for
                            throw ModuleIdentifierError.undefined(module: bystander)
                            //print("warning: ignored module extensions '\(name)'")
                            //continue 
                        }
                        extensions.append((index, try await graph(name: name)))
                    }
                    let path:Path       = .init(prefix: prefix, package: package.name, namespace: target.module)
                    let module:Module   = .init(id: target.module, package: package.name, 
                        path: path, core: core, extensions: extensions)
                    modules.append(module)
                }
                packages[package.name] = (.init(package.targets.lowerBound) ..< .init(package.targets.upperBound), version)
            }
            print("parsed JSON")
            let comments:[String]   = vertices.map(\.comment)
            let biome:Biome         = try .init(prefix: prefix, 
                vertices: vertices, 
                edges: edges, 
                modules: .init(modules, indices: indices), 
                packages: packages)
            // render articles 
            self.symbols            = biome.symbols.indices.map 
            {
                biome.article(for: $0, comment: comments[$0]) 
            }
            self.modules            = []//biome.modules.indices
            self.biome              = biome 
            self.search             = .array(biome.search.map 
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
            let path:Path  = .init(group: Biome.normalize(path: group), 
                disambiguation: disambiguation.map(Symbol.ID.init(_:)))
            if let index:Index = self.biome.routes[path]
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
            if let symbol:Symbol = self.biome[id: key]
            {
                return .found(symbol.path.canonical)
            }
            //  we were given an extraneous disambiguation key, but the path might 
            //  still be valid
            let truncated:Path = .init(group: path.group)
            if case _? = self.biome.routes[truncated]
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
            self.biome[_index: index, 
                modules: self.modules, 
                symbols: self.symbols]
        }
    }
}
