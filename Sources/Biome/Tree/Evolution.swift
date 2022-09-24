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

    init(atomic symbol:Atom<Symbol>.Position, 
        in tree:__shared Tree, 
        history:__shared History<Symbol.Metadata?>)
    {
        self.rows = []
        self.scan(founder: symbol.branch, tree: tree,
            element: symbol.atom, 
            history: history)
        {
            switch $0
            {
            case nil: return .extinct 
            case  _?: return .extant
            }
        }
    }
    // init(atomic symbol:Atom<Symbol>.Position, 
    //     in tree:__shared Tree, 
    //     history:__shared History<Symbol.Metadata?>)
    // {
    //     self.rows = []
    //     self.scan(founder: symbol.branch, tree: tree,
    //         element: symbol.atom, 
    //         history: history)
    //     {
    //         switch $0
    //         {
    //         case nil: return .extinct 
    //         case  _?: return .extant
    //         }
    //     }
    // }
    
    private mutating 
    func scan(founder:Version.Branch, tree:Tree,
        element:Atom<Symbol>, 
        history:History<Symbol.Metadata?>, 
        label:(Symbol.Metadata?) throws -> Label) rethrows
    {
        let branch:Branch = tree[founder]
        var keyframes:History<Symbol.Metadata?>.Iterator = 
            history[branch.symbols[contemporary: element].metadata].makeIterator()

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
            let inherit:Label = try label(regime.value)
            for alternate:Version.Branch in branch.revisions[revision].alternates 
            {
                try self.scan(alternate: alternate, tree: tree, 
                    element: element, 
                    history: history, 
                    inherit: inherit, 
                    label: label)
            }
            self.rows.append(.init(version: .init(founder, revision), label: inherit))
        }
    }
    private mutating 
    func scan(alternate:Version.Branch, tree:Tree,
        distance:Int = 1, 
        element:Atom<Symbol>, 
        history:History<Symbol.Metadata?>, 
        inherit:Label, 
        label:(Symbol.Metadata?) throws -> Label) rethrows 
    {
        let branch:Branch = tree[alternate]
        var keyframes:History<Symbol.Metadata?>.Iterator = 
            history[branch.symbols.divergences[element]?.metadata?.head].makeIterator()

        var regime:History<Symbol.Metadata?>.Keyframe? = keyframes.next()
        let start:Version.Revision = branch.revisions.startIndex
        for revision:Version.Revision in branch.revisions.indices.reversed() 
        {
            if  let inauguration:Version.Revision = regime?.since,
                    revision < inauguration
            {
                regime = keyframes.next() 
            }
            let inherit:Label = try regime.map { try label($0.value) } ?? inherit
            for alternate:Version.Branch in branch.revisions[revision].alternates 
            {
                try self.scan(alternate: alternate, tree: tree, 
                    distance: distance + 1,
                    element: element, 
                    history: history, 
                    inherit: inherit, 
                    label: label)
            }
            self.rows.append(.init(distance: distance, 
                version: .init(alternate, revision), 
                label: inherit, 
                fork: revision == start))
        }
    }
}