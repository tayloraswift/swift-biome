/// A link in a propogated error.
public 
protocol TraceableError:Error, CustomStringConvertible 
{
    static 
    var namespace:String 
    {
        get 
    }
    var next:Error? 
    {
        get 
    }
    var context:[String]
    {
        get 
    }
}
/// The root of a propogated error.
public 
protocol TraceableErrorRoot:TraceableError 
{
    var message:String 
    {
        get 
    }
}
public 
extension TraceableErrorRoot 
{
    var context:[String]
    {
        [self.message]
    }
    var next:Error? 
    {
        nil 
    }
}
extension TraceableError 
{
    private  
    var components:(header:String, messages:[String])
    {
        var namespace:String        = Self.namespace
        var messages:[String]       = self.context 
        
        var current:TraceableError  = self 
        while let error:Error        = current.next 
        {
            guard let next:TraceableError = error as? TraceableError 
            else 
            {
                // generic Swift.Error 
                namespace           = String.init(reflecting: Swift.type(of: error))
                messages.append(String.init(describing: error))
                break 
            }
            
            current                 = next
            namespace               = Swift.type(of: next).namespace 
            messages.append(contentsOf: next.context)
        }
        return (namespace, messages) 
    }
    public 
    var description:String 
    {
        func bold(_ string:String) -> String
        {
            "\u{1B}[1m\(string)\u{1B}[0m"
        }
        func color(_ string:String) -> String 
        {
            let color:(r:UInt8, g:UInt8, b:UInt8) = (r: 255, g:  51, b:  51)
            return "\u{1B}[38;2;\(color.r);\(color.g);\(color.b)m\(string)\u{1B}[39m"
        }
        
        let (header, messages):(String, [String])   = self.components 
        if let root:String          = messages.last 
        {
            var description:String  = "\(bold("\(color("\(header):")) \(root)"))\n"
            for note:String in messages.dropLast().reversed()
            {
                description        += "\(bold("note:")) \(note)\n"
            }
            return description
        }
        else 
        {
            return bold(color(header))
        }
    }
}
