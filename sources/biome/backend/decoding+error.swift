import JSON 

extension Biome 
{
    public 
    enum DecodingError<T>:Error 
    {
        case invalid(value:JSON?, key:String?)
        case unused(keys:[String])
        
        static 
        func undefined(key:String) -> Self 
        {
            .invalid(value: nil, key: key)
        }
    }
}
