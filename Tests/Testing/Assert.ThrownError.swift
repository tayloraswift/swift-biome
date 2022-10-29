extension Assert
{
    public
    struct ThrownError<Expected>:CustomStringConvertible
        where Expected:Error & Equatable
    {
        public
        let thrown:(any Error)?
        public
        let expected:Expected

        public
        init(thrown:(any Error)?, expected:Expected)
        {
            self.thrown = thrown
            self.expected = expected
        }
        public 
        var description:String
        {
            if let thrown:any Error = self.thrown
            {
                return "expected thrown error '\(self.expected)', but caught '\(thrown)'"
            }
            else
            {
                return "expected thrown error '\(self.expected)'"
            }
        }
    }
}
