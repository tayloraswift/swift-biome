/// an ecosystem is a subset of a biome containing packages that are relevant 
/// (in some user-defined way) to some task. 
/// 
/// ecosystem views are mainly useful for providing an immutable context for 
/// accessing foreign packages.
struct Ecosystem 
{
    enum DependencyError:Error 
    {
        case packageNotFound(Package.ID)
        case targetNotFound(Module.ID, in:Package.ID)
    }
    
    //private 
    //let standardModules:[Module.ID], 
    //    coreModules:[Module.ID]
    
    var packages:[Package], 
        indices:[Package.ID: Package.Index]
    
    var standardLibrary:Set<Module.Index>
    {
        if let swift:Package = self[.swift]
        {
            return .init(swift.modules.indices.values)
        }
        else 
        {
            // must register standard library before any other packages 
            fatalError("first package must be the swift standard library")
        }
    }
    
    init()
    {
        self.packages = []
        self.indices = [:]
    }
    
    subscript(package:Package.ID) -> Package?
    {
        self.indices[package].map { self[$0] }
    } 
    subscript(package:Package.Index) -> Package
    {
        _read 
        {
            yield  self.packages[package.offset]
        }
        _modify 
        {
            yield &self.packages[package.offset]
        }
    } 
    subscript(module:Module.Index) -> Module
    {
        _read 
        {
            yield self.packages[       module.package.offset][local: module]
        }
    } 
    subscript(symbol:Symbol.Index) -> Symbol
    {
        _read 
        {
            yield self.packages[symbol.module.package.offset][local: symbol]
        }
    } 
    

    /// returns the index of the entry for the given package, creating it if it 
    /// does not already exist.
    mutating 
    func updatePackageRegistration(for package:Package.ID, to version:Version)
        throws -> Package.Index
    {
        if let package:Package.Index = self.indices[package]
        {
            try self[package].push(version: version)
            return package 
        }
        let index:Package.Index = .init(offset: self.packages.endIndex)
        self.packages.append(.init(id: package, index: index))
        self.indices[package] = index
        return index
    }
    
    mutating 
    func updateModuleRegistrations(in culture:Package.Index,
        graphs:[Module.Graph], 
        era:[Package.ID: Version])
        throws -> (pins:Package.Pins, scopes:[Symbol.Scope])
    {
        // create modules, if they do not exist already.
        // note: module indices are *not* necessarily contiguous, 
        // or even monotonically increasing
        let cultures:[Module.Index] = self[culture].addModules(graphs)
        
        let dependencies:[Set<Module.Index>] = 
            try self.computeDependencies(of: cultures, graphs: graphs)
        
        var upstream:Set<Package.Index> = []
        for target:Module.Index in dependencies.joined()
        {
            upstream.insert(target.package)
        }
        // allows a package update to look up its own version
        upstream.insert(culture)
        
        let pins:Package.Pins = .init(dependencies: upstream)
        {
            let package:Package = self[$0]
            return $0 == culture ? package.latest : era[package.id] ?? .latest
        }
        
        self[culture].updateDependencies(of: cultures, with: dependencies)
        //self[culture].updatePins(with: pins)
        
        return (pins, self.scopes(of: cultures, dependencies: dependencies))
    }
    
    mutating 
    func updateDocumentation(in culture:Package.Index, 
        compiled:[Link.Target: Documentation],
        hints:[Symbol.Index: Symbol.Index], 
        pins:Package.Pins)
    {
        let sponsors:[Symbol.Index: Keyframe<Documentation>.Buffer.Index] = 
            self[culture].updateDocumentation(compiled)
        let migrants:[Symbol.Index: Keyframe<Documentation>.Buffer.Index] = 
            self.recruitMigrants(in: culture, 
                sponsors: _move(sponsors), 
                hints: hints, 
                pins: pins)
        self[culture].distributeDocumentation(_move(migrants))
    }
    
    // `culture` parameter not strictly needed, but we use it to make sure 
    // that ``generateRhetoric(graphs:scopes:)`` did not return ``hints``
    // about other packages
    private 
    func recruitMigrants(in culture:Package.Index,
        sponsors:[Symbol.Index: Keyframe<Documentation>.Buffer.Index],
        hints:[Symbol.Index: Symbol.Index],
        pins:Package.Pins) 
        -> [Symbol.Index: Keyframe<Documentation>.Buffer.Index]
    {
        var migrants:[Symbol.Index: Keyframe<Documentation>.Buffer.Index] = [:]
        for (member, sponsor):(Symbol.Index, Symbol.Index) in hints
            where !sponsors.keys.contains(member)
        {
            assert(member.module.package == culture)
            // if a symbol did not have documentation of its own, 
            // check if it has a sponsor 
            if let sponsor:Keyframe<Documentation>.Buffer.Index = sponsors[sponsor]
            {
                migrants[member] = sponsor 
            }
            else if culture != sponsor.module.package
            {
                // note: empty doccomments are omitted from the documentation buffer
                guard let sponsor:Keyframe<Documentation>.Buffer.Index = 
                    self[sponsor.module.package].documentation(forLocal: sponsor, 
                        at: pins[sponsor.module.package])
                else 
                {
                    continue 
                }
                migrants[member] = sponsor
            }
        }
        return migrants
    }
}
extension Ecosystem 
{
    private 
    func scopes(of cultures:[Module.Index], dependencies:[Set<Module.Index>])
        -> [Symbol.Scope]
    {
        zip(cultures, dependencies).map 
        {
            self.scope(of: $0.0, dependencies: $0.1)
        }
    }
    private 
    func scope(of culture:Module.Index, dependencies:Set<Module.Index>) 
        -> Symbol.Scope
    {
        var scope:Module.Scope = .init(culture: culture, id: self[culture].id)
        for namespace:Module.Index in dependencies 
        {
            scope.insert(namespace: namespace, id: self[namespace].id)
        }
        return .init(namespaces: scope, lenses: scope.packages().map 
        {
            self[$0].symbols.indices
        })
    }
}
