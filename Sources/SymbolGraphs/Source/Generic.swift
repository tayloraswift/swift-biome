import JSON

@frozen public 
struct Generic:Hashable, Sendable
{
    public
    var name:String 
    public
    var index:Int 
    public
    var depth:Int 
}
extension Generic 
{
    init(lowering json:JSON) throws 
    {
        (self.name, self.index, self.depth) = try json.lint 
        {
            (
                name:  try $0.remove("name", as: String.self),
                index: try $0.remove("index", as: Int.self),
                depth: try $0.remove("depth", as: Int.self)
            )
        }
    }
}
