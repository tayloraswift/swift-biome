extension Assert
{
    public
    struct True:CustomStringConvertible  
    {
        public
        init()
        {
        }
        public 
        var description:String
        {
            "expected true"
        }
    }
}
