extension Mongo
{
    public
    typealias Namespace = Namespaced<Collection>
}
extension Mongo.Namespace
{
    @inlinable public
    var collection:Mongo.Collection
    {
        self.name
    }
}
