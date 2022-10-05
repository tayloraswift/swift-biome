import PackageResolution
import SymbolGraphs
import SymbolSource

enum DependencyNotFoundError:Error 
{
    case package                                       (PackageIdentifier)
    case pin                                           (PackageIdentifier)
    case version                        ((Tag, String), PackageIdentifier)
    case module (ModuleIdentifier, (Branch.ID, String), PackageIdentifier)
    case target (ModuleIdentifier,  Branch.ID)
}

struct PackageUpdateContext 
{
    let local:Fasces 
    private
    var storage:[BasisElement]
    
    init(resolution:PackageResolution,
        nationality:Packages.Index,
        graphs:__shared [SymbolGraph],
        branch:Version.Branch,
        packages:inout Packages) throws
    {
        let linkable:[Packages.Index: PackageUpdateContext.Dependency] = 
            packages.find(pins: resolution.pins.values)
        
        self.local = packages[nationality].tree.fasces(upTo: branch)
        self.storage = []
        self.storage.reserveCapacity(graphs.count)
        
        for graph:SymbolGraph in graphs 
        {
            let module:Atom<Module>.Position = 
                packages[nationality].tree[branch].addModule(graph.id,
                    nationality: nationality, 
                    local: self.local)
            // use this instead of `graph.id` to prevent string duplication
            var element:BasisElement = .init(module, id: packages[global: module].id)
            try element.link(dependencies: graph.dependencies, 
                linkable: linkable, 
                packages: packages,
                branch: branch, 
                fasces: self.local)
            self.storage.append(element)
        }
    }
}
extension PackageUpdateContext
{
    enum Dependency:Sendable 
    {
        case available(Version)
        case unavailable(Tag, String)
    }

    func pins() -> [Packages.Index: Version]
    {
        self.reduce(into: [:]) 
        { 
            for (nationality, pinned):(Packages.Index, Package.Pinned) in $1.upstream
            {
                $0[nationality] = pinned.version
            }
        }
    }
}
extension PackageUpdateContext:RandomAccessCollection
{
    var startIndex:Int
    {
        self.storage.startIndex
    }
    var endIndex:Int
    {
        self.storage.endIndex
    }
    subscript(index:Int) -> ModuleUpdateContext
    {
        let element:BasisElement = self.storage[index]
        return .init(namespaces: element.namespaces,
            upstream: element.upstream, 
            local: self.local)
    }
}

extension PackageUpdateContext
{
    private 
    struct BasisElement 
    {
        private(set)
        var namespaces:Namespaces, 
            upstream:[Packages.Index: Package.Pinned]

        init(_ module:Atom<Module>.Position, id:ModuleIdentifier)
        {
            self.namespaces = .init(module, id: id)
            self.upstream = [:]
        }
    
        var culture:Atom<Module> 
        {
            self.namespaces.culture
        }
        var nationality:Packages.Index
        {
            self.namespaces.nationality
        }
        // the `branch` parameter may be *different* from `module.position.branch`, 
        // which refers to the branch in which the module itself was founded.
        mutating 
        func link(dependencies:[SymbolGraph.Dependency], 
            linkable:[Packages.Index: Dependency], 
            packages:Packages,
            branch:Version.Branch, 
            fasces:Fasces) throws
        {
            self.upstream.reserveCapacity(dependencies.count + 2)
            // add explicit dependencies 
            for dependency:SymbolGraph.Dependency in dependencies
            {
                guard let package:Package = packages[dependency.package]
                else 
                {
                    throw DependencyNotFoundError.package(dependency.package)
                }
                if self.nationality == package.nationality 
                {
                    try self.link(local: package, dependencies: dependency.modules, 
                        branch: branch, 
                        fasces: fasces)
                }
                else 
                {
                    try self.link(upstream: package, dependencies: dependency.modules, 
                        linkable: linkable)
                }
            }
            // add implicit dependencies
            if self.nationality != .swift 
            {
                try self.link(upstream: .swift, linkable: linkable, packages: packages)
                
                if self.nationality != .core 
                {
                    try self.link(upstream: .core, linkable: linkable, packages: packages)
                }
            }
        }
        private mutating 
        func link(upstream package:PackageIdentifier, 
            linkable:[Packages.Index: Dependency], 
            packages:Packages) throws
        {
            if let package:Package = packages[package]
            {
                try self.link(upstream: _move package, linkable: linkable)
            }
            else 
            {
                throw DependencyNotFoundError.package(package)
            }
        }
        private mutating 
        func link(upstream package:__owned Package, dependencies:[ModuleIdentifier]? = nil, 
            linkable:[Packages.Index: Dependency]) throws 
        {
            switch linkable[package.nationality] 
            {
            case nil:
                throw DependencyNotFoundError.pin(package.id)
            case .unavailable(let requirement, let revision):
                throw DependencyNotFoundError.version((requirement, revision), package.id)
            case .available(let version):
                // upstream dependency 
                let pinned:Package.Pinned = .init(_move package, version: version)
                if let dependencies:[ModuleIdentifier] 
                {
                    for id:ModuleIdentifier in dependencies
                    {
                        if let module:Atom<Module>.Position = pinned.modules.find(id)
                        {
                            // use the stored id, not the requested id
                            let id:ModuleIdentifier = pinned.package.tree[local: module].id
                            self.namespaces.linked[id] = module
                        }
                        else 
                        {
                            let branch:Branch = pinned.package.tree[version.branch]
                            throw DependencyNotFoundError.module(id, 
                                (branch.id, branch.revisions[version.revision].commit.hash), 
                                pinned.package.id)
                        }
                    }
                }
                else 
                {
                    for period:_Period<IntrinsicSlice<Module>> in pinned.modules 
                    {
                        for module:Module in period.axis
                        {
                            self.namespaces.linked[module.id] = module.culture
                                .positioned(period.branch)
                        }
                    }
                }
                self.upstream[pinned.nationality] = pinned
            }
        }
        private mutating 
        func link(local package:Package, dependencies:[ModuleIdentifier], 
            branch:Version.Branch, 
            fasces:Fasces) throws 
        {
            let contemporary:IntrinsicSlice<Module> = 
                package.tree[branch].modules[...]
            for module:ModuleIdentifier in dependencies
            {
                if  let module:Atom<Module>.Position = 
                        contemporary.atoms[module].map({ $0.positioned(branch) }) ?? 
                        fasces.modules.find(module) 
                {
                    // use the stored id, not the requested id
                    self.namespaces.linked[package.tree[local: module].id] = module
                }
                else 
                {
                    throw DependencyNotFoundError.target(module, 
                        package.tree[branch].id)
                }
            }
        }
    }
}
