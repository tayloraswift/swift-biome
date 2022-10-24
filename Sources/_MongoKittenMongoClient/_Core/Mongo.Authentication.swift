extension Mongo
{
    /// The authentication details to use with the database
    public 
    enum Authentication:Equatable, Sendable 
    {
        /// Unauthenticated
        case unauthenticated

        /// Automatically select the mechanism
        case auto(username:String, password:String)

        /// SCRAM-SHA1 mechanism
        case scramSha1(username:String, password:String)

        /// SCRAM-SHA256 mechanism
        case scramSha256(username:String, password:String)

        /// Deprecated MongoDB Challenge Response mechanism
        case mongoDBCR(username:String, password:String)
    }
}
