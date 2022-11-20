extension Mongo
{
    @frozen public
    enum Authentication:Hashable, Sendable 
    {
        case sasl(SASL)
        case x509
    }
}
extension Mongo.Authentication:RawRepresentable
{
    @inlinable public
    var rawValue:String
    {
        switch self
        {
        case .sasl(let sasl):   return sasl.rawValue
        case .x509:             return "MONGODB-X509"
        }
    }
    @inlinable public
    init?(rawValue:String)
    {
        if let mechanism:SASL = .init(rawValue: rawValue)
        {
            self = .sasl(mechanism)
        }
        switch rawValue
        {
        case "MONGODB-X509":
            self = .x509
        default:
            return nil
        }
    }
}
extension Mongo.Authentication:CustomStringConvertible
{
    @inlinable public
    var description:String
    {
        self.rawValue
    }
}
