extension Mongo
{
    public
    struct NamespaceError:Error
    {
        public
        let string:String

        public
        init(invalid string:String)
        {
            self.string = string
        }
    }
}
extension Mongo.NamespaceError:CustomStringConvertible
{
    public 
    var description:String
    {
        "invalid namespace '\(self.string)'"
    }
}
