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
    struct Position<Element> where Element:BranchElement
    {
        let index:Element.Index 
        let branch:_Version.Branch 

        init(_ index:Element.Index, branch:_Version.Branch)
        {
            self.index = index 
            self.branch = branch
        }
    }

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
    subscript(local module:Position<Module>) -> Module 
    {
        _read 
        {
            yield  self[module.branch].newModules[local: module.index]
        }
    }

    mutating 
    func branch(_ pin:PackageResolution.Pin?) -> _Version.Branch 
    {
        guard let pin:PackageResolution.Pin 
        else 
        {
            fatalError("unimplemented")
        }
        return self.branch(from: nil, name: .init(pin.requirement))
    }
    private mutating 
    func branch(from fork:_Version?, name:Branch.ID) -> _Version.Branch 
    {
        if  let branch:_Version.Branch = self.branches[name]
        {
            return branch 
        }
        let branch:_Version.Branch = .init(self.storage.endIndex)
        if  let fork:_Version 
        {
            let ring:Branch.Ring = self[fork.branch][fork.revision].ring
            self.storage.append(.init(id: name, index: branch, fork: (fork, ring)))
        }
        else 
        {
            self.storage.append(.init(id: name, index: branch, fork: nil))
        }
        self.branches[name] = branch 
        return branch 
    }

    func trunks(_ version:_Version) -> [Trunk]
    {
        var current:Branch = self[version.branch]
        var trunks:[Trunk] = [current[..<version.revision]]
        while let fork:_Version = current.fork 
        {
            current = self[fork.branch]
            trunks.append(current[..<fork.revision])
        }
        return trunks
    }
    func trunks(of branch:_Version.Branch) -> [Trunk]
    {
        var current:Branch = self[branch]
        var trunks:[Trunk] = []
        while let fork:_Version = current.fork 
        {
            current = self[fork.branch]
            trunks.append(current[..<fork.revision])
        }
        return trunks
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