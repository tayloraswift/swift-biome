extension Package 
{
    var tree:Tree
    {
        _read 
        {
            fatalError("unimplemented")
        }
        _modify
        {
            fatalError("unimplemented")
        }
    }
}

struct Tree 
{
    let culture:Package.Index
    private 
    var storage:[Branch]
    private(set)
    var branches:[Branch.ID: _Version.Branch]

    subscript(branch:_Version.Branch) -> Branch 
    {
        _read 
        {
            yield  self.storage[branch.index]
        }
        _modify
        {
            yield &self.storage[branch.index]
        }
    }
    subscript(version:_Version) -> Branch.Revision
    {
        _read 
        {
            yield  self[version.branch][version.revision]
        }
        _modify
        {
            yield &self[version.branch][version.revision]
        }
    }
    subscript(local module:Position<Module>) -> Module 
    {
        _read 
        {
            yield  self[module.branch].newModules[contemporary: module.contemporary]
        }
        // _modify 
        // {
        //     yield &self[module.branch].newModules[contemporary: module.contemporary]
        // }
    }
    subscript(local symbol:Position<Symbol>) -> Symbol 
    {
        _read 
        {
            yield  self[symbol.branch].newSymbols[contemporary: symbol.contemporary]
        }
        // _modify 
        // {
        //     yield &self[symbol.branch].newSymbols[contemporary: symbol.contemporary]
        // }
    }

    mutating 
    func branch(from fork:_Version?, name:Branch.ID) -> _Version.Branch 
    {
        if  let branch:_Version.Branch = self.branches[name]
        {
            return branch 
        }
        let branch:_Version.Branch = .init(self.storage.endIndex)
        if  let fork:_Version 
        {
            let ring:Branch.Ring = self[fork].ring
            self.storage.append(.init(id: name, index: branch, fork: (fork, ring)))
        }
        else 
        {
            self.storage.append(.init(id: name, index: branch, fork: nil))
        }
        self.branches[name] = branch 
        return branch 
    }

    func fasces(upTo branch:_Version.Branch) -> [Fascis]
    {
        var current:Branch = self[branch]
        var fasces:[Fascis] = []
        while let fork:_Version = current.fork 
        {
            current = self[fork.branch]
            fasces.append(current[...fork.revision])
        }
        return fasces
    }
    func fasces(through branch:_Version.Branch) -> [Fascis]
    {
        var current:Branch = self[branch]
        var fasces:[Fascis] = [current[...]]
        while let fork:_Version = current.fork 
        {
            current = self[fork.branch]
            fasces.append(current[...fork.revision])
        }
        return fasces
    }
    func fasces(through version:_Version) -> [Fascis]
    {
        var current:Branch = self[version.branch]
        var fasces:[Fascis] = [current[...version.revision]]
        while let fork:_Version = current.fork 
        {
            current = self[fork.branch]
            fasces.append(current[...fork.revision])
        }
        return fasces
    }

    func find(_ pin:PackageResolution.Pin) -> _Dependency 
    {
        let name:Branch.ID = .init(pin.requirement)
        if  let branch:_Version.Branch = self.branches[name], 
            let revision:_Version.Revision = self[branch].find(pin.revision)
        {
            return .available(.init(branch, revision))
        }
        else 
        {
            return .unavailable(name, pin.revision)
        }
    }
}