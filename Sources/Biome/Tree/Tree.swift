struct Tree 
{
    let nationality:Package.Index
    private 
    var storage:[Branch]
    private(set)
    var branches:[Branch.ID: Version.Branch]
    private
    var tags:[Tag: Version]
    private 
    var counter:UInt

    init(nationality:Package.Index)
    {
        self.nationality = nationality 
        self.storage = []
        self.branches = [:]
        self.tags = [:]

        self.counter = 0
    }

    var `default`:Version? 
    {
        nil
    }
}
extension Tree 
{
    subscript(branch:Version.Branch) -> Branch 
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
    subscript(version:Version) -> Branch.Revision
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
}
extension Tree 
{
    func fasces(upTo branch:Version.Branch) -> Fasces
    {
        var current:Branch = self[branch]
        var fasces:[Fascis] = []
        while let fork:Version = current.fork 
        {
            current = self[fork.branch]
            fasces.append(current[...fork.revision])
        }
        return .init(fasces)
    }
    func fasces(through version:Version) -> Fasces
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
}
extension Tree 
{
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
    /// Returns the preferred name for referring to the specified version.
    /// 
    /// -   Returns: 
    ///     -   [`nil`](), if `version` is the head of the default branch; otherwise
    /// 
    ///     -   The branch name, if `version` is the head of its branch; otherwise
    /// 
    ///     -   The custom tag name associated with the revision pointed to by 
    ///         `version`, if one exists; otherwise 
    ///
    ///     -   The date of the revision pointed to by `version`, if its branch 
    ///         is the default branch; otherwise 
    /// 
    ///     -   The branch name and date of the revision pointed to by `version`.
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
extension Tree 
{
    mutating 
    func branch(_ name:Branch.ID, from fork:Version?) -> Version.Branch 
    {
        if  let branch:Version.Branch = self.branches[name]
        {
            return branch 
        }
        let branch:Version.Branch = .init(self.storage.endIndex)
        if  let fork:Version 
        {
            let ring:Branch.Ring = self[fork].branch(branch)
            self.storage.append(.init(id: name, index: branch, fork: (fork, ring)))
        }
        else 
        {
            self.storage.append(.init(id: name, index: branch, fork: nil))
        }
        self.branches[name] = branch 
        return branch 
    }
    mutating 
    func commit(branch:Version.Branch, hash:String, pins:[Package.Index: Version], 
        date:Date, 
        tag:Tag?) -> Version
    {
        defer 
        {
            self.counter += 1
        }
        return self[branch].commit(token: self.counter, 
            hash: hash, 
            pins: pins, 
            date: date, 
            tag: tag)
    }
}

extension Tree 
{
    subscript(local article:PluralPosition<Article>) -> Article 
    {
        _read 
        {
            yield  self[article.branch].articles[contemporary: article.contemporary]
        }
        _modify
        {
            yield &self[article.branch].articles[contemporary: article.contemporary]
        }
    }
    subscript(local symbol:PluralPosition<Symbol>) -> Symbol 
    {
        _read 
        {
            yield  self[symbol.branch].symbols[contemporary: symbol.contemporary]
        }
        _modify
        {
            yield &self[symbol.branch].symbols[contemporary: symbol.contemporary]
        }
    }
    subscript(local module:PluralPosition<Module>) -> Module 
    {
        _read 
        {
            yield  self[module.branch].modules[contemporary: module.contemporary]
        }
        _modify 
        {
            yield &self[module.branch].modules[contemporary: module.contemporary]
        }
    }

    subscript(article:PluralPosition<Article>) -> Article? 
    {
        self.nationality == article.nationality ? self[local: article] : nil
    }
    subscript(symbol:PluralPosition<Symbol>) -> Symbol? 
    {
        self.nationality == symbol.nationality ? self[local: symbol] : nil
    }
    subscript(module:PluralPosition<Module>) -> Module? 
    {
        self.nationality == module.nationality ? self[local: module] : nil
    }
}