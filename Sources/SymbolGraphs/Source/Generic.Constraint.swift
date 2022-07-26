import JSON 

extension Generic 
{
    @frozen public
    enum Verb:Int, Hashable, Sendable
    {
        case subclasses = 0 
        case implements 
        case `is`
    }
    @frozen public 
    struct Constraint<Target>
    {
        public 
        var subject:String
        public 
        var verb:Verb 
        public 
        var target:Target?
        public 
        var object:String
        
        @inlinable public 
        init(_ subject:String, _ verb:Verb, _ object:String, target:Target?)
        {
            self.subject = subject
            self.verb = verb
            self.object = object
            self.target = target
        }
        // right now, this just runs on `target`, but in the future, this monad might 
        // gain another inhabitant...
        func forEach(_ body:(Target) throws -> ()) rethrows 
        {
            let _:Void? = try self.target.map(body)
        }
        @inlinable public
        func map<T>(_ transform:(Target) throws -> T) rethrows -> Constraint<T>
        {
            .init(self.subject, self.verb, self.object, target: try self.target.map(transform))
        }
        @inlinable public
        func flatMap<T>(_ transform:(Target) throws -> T?) rethrows -> Constraint<T>
        {
            .init(self.subject, self.verb, self.object, target: try self.target.flatMap(transform))
        }
    }
}

extension Generic.Constraint:Sendable where Target:Sendable {}
extension Generic.Constraint:Hashable where Target:Hashable {}
extension Generic.Constraint:Equatable where Target:Equatable {}

extension Generic.Verb 
{
    // https://github.com/apple/swift/blob/e7d56037e87787c3ee92d861e95e5ba95e0bcbd4/lib/SymbolGraphGen/JSON.cpp#L92
    enum Longform:String 
    {
        case superclass
        case conformance
        case sameType
    }
}
extension Generic.Constraint<SymbolIdentifier>
{
    init(lowering json:JSON) throws
    {
        self = try json.lint 
        {
            let verb:Generic.Verb = try $0.remove("kind") 
            {
                switch try $0.case(of: Generic.Verb.Longform.self)
                {
                case .superclass:   return .subclasses
                case .conformance:  return .implements
                case .sameType:     return .is
                }
            }
            return .init(
                try    $0.remove("lhs", as: String.self), verb, 
                try    $0.remove("rhs", as: String.self), 
                target: try $0.pop("rhsPrecise", SymbolIdentifier.init(from:)))
        }
    }
}
