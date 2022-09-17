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
            yield  self[version.branch].revisions[version.revision]
        }
        _modify
        {
            yield &self[version.branch].revisions[version.revision]
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
    func branch(_ name:Branch.ID, from fork:_Version?) -> _Version.Branch 
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
        while let fork:Version = current.fork 
        {
            current = self[fork.branch]
            fasces.append(current[...fork.revision])
        }
        return .init(fasces)
    }
    /// Returns the version pointed to by the given version selector, if it exists. 
    /// 
    /// If the selector specifies a date, the tag component (if present) is 
    /// assumed to point to a branch. If no tag component is specified, 
    /// the default branch is used.
    func find(_ selector:Version.Selector) -> Version? 
    {
        switch selector 
        {
        case .tag(let tag):
            return self.find(tag)
        case .date(nil, let date):
            if  let branch:Version.Branch = self.default?.branch, 
                let revision:Version.Revision = self[branch].revisions.find(date)
            {
                return .init(branch, revision)
            }
            else 
            {
                return nil 
            }
        
        case .date(let tag?, let date):
            if  let branch:Version.Branch = self.branches[tag], 
                let revision:Version.Revision = self[branch].revisions.find(date)
            {
                return .init(branch, revision)
            }
            else 
            {
                return nil 
            }
        }
    }
    /// Returns the version pointed to by the given tag, if it exists. 
    /// 
    /// If the given tag refers to a branch, this method returns the 
    /// head of that branch.
    func find(_ tag:Tag) -> Version?
    {
        if  let version:Version = self.tags[tag]
        {
            return version 
        }
        if  let branch:Version.Branch = self.branches[tag], 
            let revision:Version.Revision = self[branch].head
        {
            return .init(branch, revision)
        }
        else 
        {
            return nil
        }
    }
    func abbreviate(_ version:Version) -> Version.Selector?
    {
        let branch:Branch = self[version.branch]
        let revision:Branch.Revision = branch.revisions[version.revision]
        if case version? = self.default 
        {
            return nil
        }
        else if case version.revision? = branch.head 
        {
            return .tag(branch.id)
        }
        else if let custom:Tag = revision.tag 
        {
            return .tag(custom)
        }
        else if case version.branch? = self.default?.branch
        {
            return .date(nil, revision.date)
        }
        else 
        {
            return .date(branch.id, revision.date)
        }
    }
}