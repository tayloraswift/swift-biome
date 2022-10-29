extension Assert
{
    public
    struct OptionalUnwrap<Wrapped>:CustomStringConvertible 
    {
        public
        init()
        {
        }
        public 
        var description:String
        {
            "expected non-nil value of type \(Wrapped.self)"
        }
    }
}
