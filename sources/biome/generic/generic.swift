import JSON

struct Generic:Hashable, Sendable
{
    var name:String 
    var index:Int 
    var depth:Int 
}
extension Generic 
{
    init(from json:JSON) throws 
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
