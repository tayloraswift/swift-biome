extension Assert
{
    public
    struct Success:CustomStringConvertible
    {
        public
        let caught:any Error

        public
        init(caught:any Error)
        {
            self.caught = caught
        }
        public 
        var description:String
        {
            "caught error '\(self.caught)'"
        }
    }
}
