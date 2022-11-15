extension SCRAM
{
    public
    struct ServerResponseError:Error
    {
        public
        let missing:Attribute
    }
}
extension SCRAM.ServerResponseError:CustomStringConvertible
{
    public
    var description:String
    {
        "missing expected attribute '\(self.missing)'"
    }
}
