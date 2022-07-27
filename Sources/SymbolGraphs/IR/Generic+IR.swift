import JSON 

extension Generic 
{
    init(from json:JSON) throws 
    {
        (self.name, self.index, self.depth) = try json.shape(3)
        {
            (
                try $0.load(0, as: String.self),
                try $0.load(1, as: Int.self),
                try $0.load(2, as: Int.self)
            )
        }
    }
    var serialized:JSON 
    {
        [
            .string(self.name),
            .number(self.index),
            .number(self.depth)
        ]
    }
}
extension Generic.Constraint<Int> 
{
    var serialized:JSON 
    {
        if let target:Int = self.target
        {
            return 
                [
                    .string(self.subject), 
                    .number(self.verb.rawValue), 
                    .string(self.object), 
                    .number(target),
                ]
        }
        else 
        {
            return 
                [
                    .string(self.subject), 
                    .number(self.verb.rawValue), 
                    .string(self.object), 
                ]
        }
    }
}
