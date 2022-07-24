extension SymbolGraph.Edge:Sendable where Source:Sendable {}
extension SymbolGraph.Edge:Hashable where Source:Hashable {}
extension SymbolGraph.Edge:Equatable where Source:Equatable {}

extension SymbolGraph.Edge.Target:Sendable where Source:Sendable {}
extension SymbolGraph.Edge.Target:Hashable where Source:Hashable {}
extension SymbolGraph.Edge.Target:Equatable where Source:Equatable {}

extension SymbolGraph 
{
    @frozen public 
    struct Edge<Source>
    {
        @frozen public 
        enum Target 
        {
            case feature(of:Source)
            case member(of:Source)
            case conformer(of:Source, where:[Generic.Constraint<Source>])
            case subclass(of:Source)
            case override(of:Source)
            case requirement(of:Source)
            case optionalRequirement(of:Source)
            case defaultImplementation(of:Source)

            func forEach(_ body:(Source) throws -> ()) rethrows 
            {
                switch self  
                {
                case .feature(of: let target):
                    try body(target)
                case .member(of: let target):
                    try body(target)
                case .conformer(of: let target, where: let constraints):
                    try body(target)
                    for constraint:Generic.Constraint<Source> in constraints 
                    {
                        try constraint.forEach(body)
                    }
                case .subclass(of: let target):
                    try body(target)
                case .override(of: let target):
                    try body(target)
                case .requirement(of: let target):
                    try body(target)
                case .optionalRequirement(of: let target):
                    try body(target)
                case .defaultImplementation(of: let target):
                    try body(target)
                }
            }
            func map<T>(_ transform:(Source) throws -> T) rethrows -> Edge<T>.Target
            {
                switch self  
                {
                case .feature(of: let target):
                    return .feature(of: try transform(target))
                case .member(of: let target):
                    return .member(of: try transform(target))
                case .conformer(of: let target, where: let constraints):
                    return .conformer(of: try transform(target), 
                        where: try constraints.map { try $0.map(transform) })
                case .subclass(of: let target):
                    return .subclass(of: try transform(target))
                case .override(of: let target):
                    return .override(of: try transform(target))
                case .requirement(of: let target):
                    return .requirement(of: try transform(target))
                case .optionalRequirement(of: let target):
                    return .optionalRequirement(of: try transform(target))
                case .defaultImplementation(of: let target):
                    return .defaultImplementation(of: try transform(target))
                }
            }
        }

        public 
        let source:Source 
        public 
        let target:Target

        var bounds:(Source, UInt8, Source)
        {
            switch self.target
            {
            case .feature(of: let target):
                return (self.source, 0, target)
            case .member(of: let target):
                return (self.source, 1, target)
            case .conformer(of: let target, where: _):
                return (self.source, 2, target)
            case .subclass(of: let target):
                return (self.source, 3, target)
            case .override(of: let target):
                return (self.source, 4, target)
            case .requirement(of: let target):
                return (self.source, 5, target)
            case .optionalRequirement(of: let target):
                return (self.source, 6, target)
            case .defaultImplementation(of: let target):
                return (self.source, 7, target)
            }
        }

        init(_ source:Source, is target:Target)
        {
            self.source = source 
            self.target = target
        }

        func forEach(_ body:(Source) throws -> ()) rethrows 
        {
            try body(self.source)
            try self.target.forEach(body)
        }
        func map<T>(_ transform:(Source) throws -> T) rethrows -> Edge<T>
        {
            .init(try transform(self.source), is: try self.target.map(transform))
        }
    }
}
