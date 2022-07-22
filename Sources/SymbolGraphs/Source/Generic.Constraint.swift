import JSON 

extension Generic 
{
    @frozen public
    enum ConstraintVerb:String, Hashable, Sendable
    {
        case subclasses = "superclass"
        case implements = "conformance"
        case `is`       = "sameType"
    }
    @frozen public 
    struct Constraint<Target>
    {
        public 
        var subject:String
        public 
        var verb:ConstraintVerb 
        public 
        var target:Target?
        public 
        var object:String
        
        @inlinable public 
        init(_ subject:String, _ verb:ConstraintVerb, _ object:String, target:Target?)
        {
            self.subject = subject
            self.verb = verb
            self.object = object
            self.target = target
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

extension Generic.Constraint where Target == SymbolIdentifier
{
    init(from json:JSON) throws
    {
        self = try json.lint 
        {
            let verb:Generic.ConstraintVerb = try $0.remove("kind") 
            {
                try $0.case(of: Generic.ConstraintVerb.self)
            }
            return .init(
                try    $0.remove("lhs", as: String.self), verb, 
                try    $0.remove("rhs", as: String.self), 
                target: try $0.pop("rhsPrecise", SymbolIdentifier.init(from:)))
        }
    }
}
