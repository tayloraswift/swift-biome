import JSON 

extension Generic 
{
    enum ConstraintVerb:String, Hashable, Sendable
    {
        case subclasses = "superclass"
        case implements = "conformance"
        case `is`       = "sameType"
    }
    
    struct Constraint<Link>
    {
        var subject:String
        var verb:ConstraintVerb 
        var link:Link?
        var object:String
        
        init(_ subject:String, _ verb:ConstraintVerb, _ object:String, link:Link?)
        {
            self.subject = subject
            self.verb = verb
            self.link = link
            self.object = object
        }
        
        func map<T>(_ transform:(Link) throws -> T) rethrows -> Constraint<T>
        {
            .init(self.subject, self.verb, self.object, link: try self.link.map(transform))
        }
        func flatMap<T>(_ transform:(Link) throws -> T?) rethrows -> Constraint<T>
        {
            .init(self.subject, self.verb, self.object, link: try self.link.flatMap(transform))
        }
    }
}

extension Generic.Constraint:Sendable where Link:Sendable {}
extension Generic.Constraint:Hashable where Link:Hashable {}
extension Generic.Constraint:Equatable where Link:Equatable {}

extension Generic.Constraint where Link == Symbol.ID 
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
                link: try $0.pop("rhsPrecise", Symbol.ID.init(from:)))
        }
    }
}
