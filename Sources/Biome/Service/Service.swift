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

    func storeLiterature(_ literature:Literature) async throws
}

public 
actor Service 
{
    var packages:Packages, 
        stems:Route.Stems

    init()
    {
        self.packages = .init()
        self.stems = .init()
    }
}
extension Service 
{
    func updatePackage(_ id:PackageIdentifier, 
        resolved:PackageResolution,
        branch:String, 
        fork:String? = nil,
        date:Date, 
        tag:String? = nil,
        graphs:[SymbolGraph], 
        database:some _Database) async throws -> Packages.Index
    {
        try Task.checkCancellation()

        guard let pin:PackageResolution.Pin = resolved.pins[id]
        else 
        {
            fatalError("missing pin for '\(id)'")
        }
        guard let branch:Tag = .init(parsing: branch) 
        else 
        {
            fatalError("branch name cannot be empty")
        }

        let fork:Version.Selector? = fork.flatMap(Version.Selector.init(parsing:))
        // topological sort  
        let graphs:[SymbolGraph] = try graphs.topologicallySorted(for: id)
        return try await self.add(package: id, 
            resolved: resolved, 
            commit: .init(hash: pin.revision, date: date, tag: tag.flatMap(Tag.init(parsing:))),
            branch: branch, 
            fork: fork,
            graphs: graphs, 
            database: database)
    }

    private  
    func add<Database:_Database>(package id:PackageIdentifier, 
        resolved:__owned PackageResolution, 
        commit:__owned Commit,
        branch:Tag, 
        fork:Version.Selector?,
        graphs:__owned [SymbolGraph], 
        database:Database) async throws -> Packages.Index
    {
        let nationality:Packages.Index = self.packages.addPackage(id)
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
        
        let context:PackageUpdateContext = try self.packages.addModules(to: branch, 
            nationality: nationality, 
            resolved: _move resolved,
            graphs: graphs)
        
        let interface:PackageInterface = self.packages[nationality].updateMetadata(
            context: _move context, 
            commit: _move commit,
            branch: branch,
            graphs: graphs,
            stems: &self.stems,
            api: &api)
        
        let literature:Literature = .init(compiling: graphs, 
            interface: interface, 
            local: self.packages[nationality], 
            stems: stems)
        
        let surface:Surface = (_move api).surface()
        try await database.storeSurface(_move surface, for: nationality, version: interface.version)
        try await database.storeLiterature(literature)

        self.packages[nationality].updateData(literature: _move literature, 
            interface: _move interface, 
            graphs: _move graphs)
        
        return nationality 
    }
}