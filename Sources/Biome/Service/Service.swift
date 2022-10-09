import PackageResolution
import SymbolSource
import SymbolGraphs
import Versions

protocol _Database:Sendable
{
    func loadSurface(for nationality:Packages.Index, version:Version) async throws -> Surface 

    func storeSurface(_ surface:Surface, 
        for nationality:Packages.Index, 
        version:Version) async throws

    func storeDocumentation(_ literature:PackageDocumentation) async throws
}

public 
actor Service 
{
    var packages:Packages, 
        stems:Route.Stems

    public
    init()
    {
        self.packages = .init()
        self.stems = .init()
    }
}
extension Service 
{
    func updatePackage(resolution:PackageResolution,
        branch:String, 
        fork:String? = nil,
        date:Date, 
        tag:String? = nil,
        graph:__owned SymbolGraph, 
        database:some _Database) async throws -> Packages.Index
    {
        try Task.checkCancellation()

        guard let pin:PackageResolution.Pin = resolution.pins[graph.id]
        else 
        {
            fatalError("missing pin for '\(graph.id)'")
        }
        guard let branch:Tag = .init(parsing: branch) 
        else 
        {
            fatalError("branch name cannot be empty")
        }

        let fork:Version.Selector? = fork.flatMap(Version.Selector.init(parsing:))

        let nationality:Packages.Index = self.packages.addPackage(graph.id)

        let impact:PackageImpact = try await self.updatePackage(nationality, 
            resolution: resolution, 
            commit: .init(hash: pin.revision, date: date, tag: tag.flatMap(Tag.init(parsing:))),
            branch: branch, 
            fork: fork,
            graph: _move graph, 
            database: database)
        
        for (dependency, (pin, consumers)):(Packages.Index, (Version, Set<Atom<Module>>)) in 
            impact.dependencies
        {
            assert(dependency != nationality)

            self.packages[dependency].tree[pin]
                .consumers[nationality, default: [:]][impact.version] = consumers
        }

        return nationality
    }

    private  
    func updatePackage<Database:_Database>(_ nationality:Packages.Index,
        resolution:__owned PackageResolution, 
        commit:__owned Commit,
        branch:Tag, 
        fork:Version.Selector?,
        graph:__owned SymbolGraph,
        database:Database) async throws -> PackageImpact
    {
        let (branch, previous):(Version.Branch, Version?) = 
            try self.packages[nationality].tree.branch(branch, from: fork)

        // we are going to mutate `self[package].tree[branch]`, so we must not 
        // capture that buffer or any slice of it!
        var api:SurfaceBuilder 
        if let previous:Version 
        {
            api = .init(previous: try await database.loadSurface(for: nationality, 
                version: previous))
        }
        else 
        {
            api = .init(previous: .init())
        }
        
        do 
        {
            let context:PackageUpdateContext = try .init(resolution: _move resolution,
                nationality: nationality,
                branch: branch,
                graph: graph,
                packages: &self.packages)
            
            let interface:PackageInterface = .init(context: _move context, commit: _move commit, 
                branch: branch,
                graph: graph,
                stems: &self.stems,
                tree: &self.packages[nationality].tree)
            
            self.packages[nationality].updateMetadata(interface: interface,
                branch: branch,
                graph: graph,
                stems: self.stems,
                api: &api)
            
            let documentation:PackageDocumentation = .init(interface: interface, 
                graph: graph,
                local: self.packages[nationality], 
                stems: stems)
            
            let surface:Surface = (_move api).surface()
            try await database.storeSurface(_move surface, for: nationality, version: interface.version)
            try await database.storeDocumentation(documentation)

            self.packages[nationality].updateDocumentation(_move documentation, 
                interface: interface)
            self.packages[nationality].updateData(_move graph,
                interface: interface)
            
            return .init(interface: _move interface)
        }
        catch let error
        {
            self.packages[nationality].tree.revert(branch, to: previous)
            throw error
        }
    }
}