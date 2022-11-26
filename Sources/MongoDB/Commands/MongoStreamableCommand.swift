import MongoSchema

public
protocol MongoStreamableCommand<Element>:MongoDatabaseCommand, MongoImplicitSessionCommand
    where Response == Mongo.Cursor<Element>
{
    associatedtype Element:MongoDecodable

    var batching:Int { get }
    var timeout:Mongo.Milliseconds? { get }
}
