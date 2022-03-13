enum SwiftConstraintVerb:Hashable, Sendable
{
    case subclasses
    case implements
    case `is`
}
struct SwiftConstraint<Link>
{
    var subject:String
    var verb:SwiftConstraintVerb 
    var link:Link?
    var object:String
    
    init(_ subject:String, _ verb:SwiftConstraintVerb, _ object:String, link:Link?)
    {
        self.subject = subject
        self.verb = verb
        self.link = link
        self.object = object
    }
    
    func map<T>(_ transform:(Link) throws -> T) rethrows -> SwiftConstraint<T>
    {
        .init(self.subject, self.verb, self.object, link: try self.link.map(transform))
    }
    func flatMap<T>(_ transform:(Link) throws -> T?) rethrows -> SwiftConstraint<T>
    {
        .init(self.subject, self.verb, self.object, link: try self.link.flatMap(transform))
    }
}
extension SwiftConstraint:Sendable where Link:Sendable {}
extension SwiftConstraint:Hashable where Link:Hashable {}
extension SwiftConstraint:Equatable where Link:Equatable {}
