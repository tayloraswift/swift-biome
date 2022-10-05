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
        resolution:PackageResolution,
        branch:String, 
        fork:String? = nil,
        date:Date, 
        tag:String? = nil,
        graphs:[SymbolGraph], 
        database:some _Database) async throws -> Packages.Index
    {
        try Task.checkCancellation()

        guard let pin:PackageResolution.Pin = resolution.pins[id]
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

        let nationality:Packages.Index = self.packages.addPackage(id)

        let impact:PackageImpact = try await self.updatePackage(nationality, 
            resolution: resolution, 
            commit: .init(hash: pin.revision, date: date, tag: tag.flatMap(Tag.init(parsing:))),
            branch: branch, 
            fork: fork,
            graphs: graphs, 
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
        graphs:__owned [SymbolGraph], 
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
                graphs: graphs,
                branch: branch,
                packages: &self.packages)
            
            let interface:PackageInterface = .init(context: _move context, commit: _move commit, 
                graphs: graphs,
                branch: branch,
                stems: &self.stems,
                tree: &self.packages[nationality].tree)
            
            self.packages[nationality].updateMetadata(interface: interface,
                graphs: graphs,
                branch: branch,
                stems: self.stems,
                api: &api)
            
            let literature:Literature = .init(compiling: graphs, 
                interface: interface, 
                local: self.packages[nationality], 
                stems: stems)
            
            let surface:Surface = (_move api).surface()
            try await database.storeSurface(_move surface, for: nationality, version: interface.version)
            try await database.storeLiterature(literature)

            self.packages[nationality].updateData(literature: _move literature, 
                interface: interface, 
                graphs: _move graphs)
            
            return .init(interface: _move interface)
        }
        catch let error
        {
            //self.packages[nationality].tree[branch].revert(to: previous)
            throw error 
        }
    }
}