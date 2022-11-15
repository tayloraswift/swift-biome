extension Mongo
{
    public
    struct InstanceSelectorError:Equatable, Error
    {
        public
        let selector:InstanceSelector

        init(_ selector:InstanceSelector)
        {
            self.selector = selector
        }
    }
}
extension Mongo.InstanceSelectorError:CustomStringConvertible
{
    public
    var description:String
    {
        "could not connect to any hosts matching selector '\(self.selector)'"
    }
}
