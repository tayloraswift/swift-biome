extension Entrapta 
{
    struct Error:Swift.Error 
    {
        let message:String 
        let help:String?
        
        init(_ message:String, help:String? = nil) 
        {
            self.message    = message 
            self.help       = help
        }
    }
}
extension Entrapta.Error 
{
    static 
    func ignored(_ page:Page, because reason:String) -> Self 
    {
        .init("ignored page '\(page.path.joined(separator: "."))' because \(reason)")
    }
}
extension Entrapta.Error:CustomStringConvertible 
{
    var description:String 
    {
        "error: \(message)\(help.map{ "\nnote: \($0)" } ?? "")"
    }
}
