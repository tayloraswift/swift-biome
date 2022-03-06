extension Biome
{
    public 
    enum ResourceVersionError:Error 
    {
        case missing
    }
    public 
    struct ResourceTypeError:Error 
    {
        let expected:String, 
            encountered:String 
        init(_ encountered:String, expected:String)
        {
            self.expected       = expected
            self.encountered    = encountered
        }
    }
}
