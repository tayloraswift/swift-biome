public
protocol MongoQueryCommand<Element>:MongoDatabaseCommand
    where Response == Mongo.Cursor<Element>
{
    associatedtype Element:MongoDecodable

    var batching:Int { get }
    var timeout:Mongo.Duration? { get }
}
