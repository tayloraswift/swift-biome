struct Tree 
{
    let nationality:Package.Index
    private 
    var storage:[Branch]
    private(set)
    var branches:[Branch.ID: _Version.Branch]
    private
    var tags:[Tag: _Version]

    var `default`:_Version? 
    {
        nil
    }

    init(nationality:Package.Index)
    {
        self.nationality = nationality 
        self.storage = []
        self.branches = [:]
        self.tags = [:]
    }

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

    subscript(local article:Position<Article>) -> Article 
    {
        _read 
        {
            yield  self[article.branch].articles[contemporary: article.contemporary]
        }
    }
    subscript(local symbol:Position<Symbol>) -> Symbol 
    {
        _read 
        {
            yield  self[symbol.branch].symbols[contemporary: symbol.contemporary]
        }
    }
    subscript(local module:Position<Module>) -> Module 
    {
        _read 
        {
            yield  self[module.branch].modules[contemporary: module.contemporary]
        }
    }

    subscript(article:Position<Article>) -> Article? 
    {
        self.nationality == article.package ? self[local: article] : nil
    }
    subscript(symbol:Position<Symbol>) -> Symbol? 
    {
        self.nationality == symbol.package ? self[local: symbol] : nil
    }
    subscript(module:Position<Module>) -> Module? 
    {
        self.nationality == module.package ? self[local: module] : nil
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

    func fasces(upTo branch:_Version.Branch) -> Fasces
    {
        var current:Branch = self[branch]
        var fasces:[Fascis] = []
        while let fork:_Version = current.fork 
        {
            current = self[fork.branch]
            fasces.append(current[...fork.revision])
        }
        return .init(fasces)
    }
    // func fasces(through branch:_Version.Branch) -> [Fascis]
    // {
    //     var current:Branch = self[branch]
    //     var fasces:[Fascis] = [current[...]]
    //     while let fork:_Version = current.fork 
    //     {
    //         current = self[fork.branch]
    //         fasces.append(current[...fork.revision])
    //     }
    //     return fasces
    // }
    func fasces(through version:_Version) -> Fasces
    {
        var current:Branch = self[version.branch]
        var fasces:[Fascis] = [current[...version.revision]]
        while let fork:_Version = current.fork 
        {
            current = self[fork.branch]
            fasces.append(current[...fork.revision])
        }
        return .init(fasces)
    }

    func find(_ tag:Tag) -> _Version?
    {
        if  let version:_Version = self.tags[tag]
        {
            return version 
        }
        if case .named(let name) = tag, 
            let branch:_Version.Branch = self.branches[name], 
            let revision:_Version.Revision = self[branch]._head
        {
            return .init(branch, revision)
        }
        else 
        {
            return nil
        }
    }
}