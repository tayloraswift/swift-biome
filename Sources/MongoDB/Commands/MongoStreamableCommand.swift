import BSONDecoding

public
protocol MongoStreamableCommand<Element>:MongoDatabaseCommand, MongoImplicitSessionCommand
    where Response == Mongo.Cursor<Element>
{
    associatedtype Element:BSONDocumentDecodable & Sendable

    var batching:Int { get }
    var timeout:Mongo.Milliseconds? { get }
}
