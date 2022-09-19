extension Symbol.Metadata? 
{
    fileprivate 
    var label:Evolution.Label 
    {
        switch self 
        {
        case nil: return .extinct 
        case  _?: return .extant
        }
    }
}

struct Evolution 
{
    enum Label 
    {
        case extant 
        case extinct 
    }
    struct Row 
    {
        let distance:Int 
        let version:Version
        var label:Label 
        var fork:Bool

        init(distance:Int = 0, version:Version, label:Label, fork:Bool = false)
        {
            self.distance = distance
            self.version = version
            self.label = label
            self.fork = fork
        }
    }

    var rows:[Row]

    init(for symbol:Tree.Position<Symbol>, 
        in tree:__shared Tree, 
        history:__shared History<Symbol.Metadata?>)
    {
        self.rows = []
        self.scan(founder: symbol.branch, tree: tree,
            position: symbol.contemporary, 
            history: history)
    }
    
    private mutating 
    func scan(founder:Version.Branch, tree:Tree,
        position:Branch.Position<Symbol>, 
        history:History<Symbol.Metadata?>)
    {
        let branch:Branch = tree[founder]
        var keyframes:History<Symbol.Metadata?>.Iterator = 
            history[branch.symbols[contemporary: position].metadata].makeIterator()
        
        guard var regime:History<Symbol.Metadata?>.Keyframe = keyframes.next()
        else 
        {
            return 
        }
        for revision:Version.Revision in branch.revisions.indices.reversed() 
        {
            if  revision < regime.since 
            {
                guard let predecessor:History<Symbol.Metadata?>.Keyframe = keyframes.next() 
                else 
                {
                    return 
                }
                regime = predecessor
            }
            let label:Label = regime.value.label 
            for alternate:Version.Branch in branch.revisions[revision].alternates 
            {
                self.scan(alternate: alternate, tree: tree, 
                    position: position, 
                    history: history, 
                    base: label)
            }
            self.rows.append(.init(version: .init(founder, revision), label: label))
        }
    }
    private mutating 
    func scan(alternate:Version.Branch, tree:Tree,
        distance:Int = 1, 
        position:Branch.Position<Symbol>, 
        history:History<Symbol.Metadata?>, 
        base:Label)
    {
        let branch:Branch = tree[alternate]
        var keyframes:History<Symbol.Metadata?>.Iterator = 
            history[branch.symbols.divergences[position]?.metadata?.head].makeIterator()

        var regime:History<Symbol.Metadata?>.Keyframe? = keyframes.next()
        let start:Version.Revision = branch.revisions.startIndex
        for revision:Version.Revision in branch.revisions.indices.reversed() 
        {
            if  let inauguration:Version.Revision = regime?.since,
                    revision < inauguration
            {
                regime = keyframes.next() 
            }
            let label:Label = regime?.value.label ?? base
            for alternate:Version.Branch in branch.revisions[revision].alternates 
            {
                self.scan(alternate: alternate, tree: tree, 
                    distance: distance + 1,
                    position: position, 
                    history: history, 
                    base: label)
            }
            self.rows.append(.init(distance: distance, 
                version: .init(alternate, revision), 
                label: label, 
                fork: revision == start))
        }
    }
}