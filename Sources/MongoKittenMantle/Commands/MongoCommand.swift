import BSON

public
protocol MongoCommand
{
    var bson:Document { get }
}
public
protocol MongoTransactableCommand:MongoCommand
{
}
public
protocol MongoAdministrativeCommand:MongoCommand
{
}