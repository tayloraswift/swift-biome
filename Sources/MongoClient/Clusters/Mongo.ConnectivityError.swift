extension Mongo
{
    public
    struct ConnectivityError:Error, Sendable
    {
        public
        let selector:InstanceSelector
        public
        let errors:[any Error]
    }
}
extension Mongo.ConnectivityError:CustomStringConvertible
{
    public
    var description:String
    {
        var description:String =
        """
        Could not connect to any hosts matching selector '\(self.selector)'!
        """
        if !self.errors.isEmpty
        {
            description +=
            """

            Note: Some hosts could not be reached because:
            """
            for (ordinal, error):(Int, any Error) in self.errors.enumerated()
            {
                description +=
                """

                \(ordinal). \(error)
                """
            }
        }
        return description
    }
}
