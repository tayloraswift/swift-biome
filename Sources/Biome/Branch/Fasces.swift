import Sediment

struct Fasces
{
    struct RoutingView:RandomAccessCollection
    {
        private 
        let segments:[Fascis]

        init(_ segments:__owned [Fascis])
        {
            self.segments = segments
        }

        var startIndex:Int 
        {
            self.segments.startIndex
        }
        var endIndex:Int 
        {
            self.segments.endIndex
        }
        subscript(index:Int) -> Divergences<Route, Branch.Stack> 
        {
            self.segments[index].routes
        }
    }
    struct AugmentedRoutingView
    {
        private 
        let trunk:[Fascis], 
            routes:[Route: Branch.Stack], 
            branch:Version.Branch

        init(_ trunk:[Fascis], 
            routes:[Route: Branch.Stack], 
            branch:Version.Branch)
        {
            self.trunk = trunk 
            self.routes = routes
            self.branch = branch
        }

        func select<T>(_ key:Route, 
            where filter:(Version.Branch, Composite) throws -> T?) rethrows -> Selection<T>?
        {
            var selection:Selection<T>? = nil
            try self.select(key)
            {
                if let selected:T = try filter($0, $1)
                {
                    selection.append(selected)
                }
            }
            return selection
        }
        private 
        func select(_ key:Route, 
            _ body:(Version.Branch, Composite) throws -> ()) rethrows 
        {
            try self.routes.select(key) 
            { 
                try body(self.branch, $0) 
            }
            for fascis:Fascis in self.trunk 
            {
                try fascis.routes.select(key) 
                { 
                    try body(fascis.branch, $0)
                }
            }
        }
    }

    private
    var segments:[Fascis]

    init() 
    {
        self.segments = []
    }
    init(_ segments:__owned [Fascis])
    {
        self.segments = segments
    }

    var routes:RoutingView 
    {
        .init(self.segments)
    }
    func routes(layering routes:[Route: Branch.Stack], branch:Version.Branch) 
        -> AugmentedRoutingView 
    {
        .init(self.segments, routes: routes, branch: branch)
    }
}
extension Fasces:ExpressibleByArrayLiteral 
{
    init(arrayLiteral:Fascis...)
    {
        self.init(arrayLiteral)
    }
}
extension Fasces:RandomAccessCollection, RangeReplaceableCollection 
{
    var startIndex:Int 
    {
        self.segments.startIndex
    }
    var endIndex:Int 
    {
        self.segments.endIndex
    }
    subscript(index:Int) -> Fascis
    {
        _read 
        {
            yield self.segments[index]
        }
    }
    mutating 
    func replaceSubrange(_ subrange:Range<Int>, with elements:some Collection<Fascis>) 
    {
        self.segments.replaceSubrange(subrange, with: elements)
    }
}


protocol Periods<Axis>:Collection where Element == _Period<Axis>
{
    associatedtype Axis:PeriodAxis

    subscript(index:Int) -> _Period<Axis>
    {
        get
    }
}
extension Periods
{
    func find<Element>(_ id:Element.ID) -> Atom<Element>.Position? 
        where Axis == IntrinsicSlice<Element>
    {
        for period:_Period<Axis> in self 
        {
            if let atom:Atom<Element> = period.axis.atoms[id]
            {
                return atom.positioned(period.branch)
            }
        }
        return nil
    }
}

protocol FieldViews<Axis, Value>:Collection where Element == _Period<Axis>.FieldView<Value>
{
    associatedtype Axis:PeriodAxis
    associatedtype Value:Equatable

    subscript(index:Int) -> _Period<Axis>.FieldView<Value>
    {
        get
    }
}
extension FieldViews
{
    private 
    func values(of field:Axis.Field<Value>) -> Timeline<Self>
    {
        .init(self, field: field)
    }
    func value(of field:Axis.Field<Value>) -> Value?
    {
        for (value, _):(Value, Version.Revision) in self.values(of: field).joined()
        {
            return value
        }
        return nil
    }

    func latestVersion(of field:Axis.Field<Value>, 
        where predicate:(Value) throws -> Bool) rethrows -> Version?
    {
        var candidate:Version? = nil
        for values:Timeline<Self>.FieldValues in self.values(of: field)
        {
            if case nil = candidate 
            {
                candidate = values.latest
            }
            for keyframe:(value:Value, since:Version.Revision) in values
            {
                if try predicate(keyframe.value) 
                {
                    return candidate 
                }
                else if let version:Version = values.version(before: keyframe.since)
                {
                    candidate = version
                }
            }
        }
        return nil 
    }
}


struct Timeline<Trunk>:Sequence, IteratorProtocol where Trunk:FieldViews
{
    private 
    var trunk:Trunk.Iterator? 
    private 
    let field:Trunk.Axis.Field<Trunk.Value>
    
    init(_ trunk:__shared Trunk, field:Trunk.Axis.Field<Trunk.Value>)
    {
        self.trunk = trunk.makeIterator()
        self.field = field
    }

    mutating 
    func next() -> FieldValues?
    {
        guard let view:_Period<Trunk.Axis>.FieldView<Trunk.Value> = self.trunk?.next() 
        else 
        {
            return nil 
        }

        let index:Sediment<Version.Revision, Trunk.Value>.Index?
        switch view.axis[self.field]
        {
        case .original(let head):
            // we know no prior epochs could possibly contain any information 
            // about this symbol, so we can stop iterating after this.
            self.trunk = nil

            if  let head:OriginalHead<Trunk.Value>
            {
                index = view.sediment[head].find(view.latest.revision)
            }
            else 
            {
                index = nil
            }
        
        case .alternate(let alternate?):
            if  view.latest.revision < alternate.since 
            {
                index = nil
            }
            else 
            {
                index = view.sediment[alternate.head].find(view.latest.revision)
                assert(index != nil, "containment check succeeded but revision was not found")
            }

        case .alternate(nil):
            index = nil
        }
        return .init(.init(current: index, sediment: view.sediment), 
            latest: view.latest,
            fork: view.fork)
    }
}
extension Timeline
{
    struct FieldValues:Sequence
    {
        private 
        let iterator:Sediment<Version.Revision, Trunk.Value>.StratumIterator
        let latest:Version
        /// The branch and revision this period was forked from, 
        /// if applicable.
        let fork:Version?

        init(_ iterator:Sediment<Version.Revision, Trunk.Value>.StratumIterator, 
            latest:Version,
            fork:Version?)
        {
            self.iterator = iterator
            self.latest = latest
            self.fork = fork
        }

        func makeIterator() -> Sediment<Version.Revision, Trunk.Value>.StratumIterator
        {
            self.iterator
        }

        func version(before revision:Version.Revision) -> Version?
        {
            revision.predecessor.map { .init(self.latest.branch, $0) } ?? self.fork
        }
    }
}