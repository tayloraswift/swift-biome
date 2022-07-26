import JSON 

extension Generic 
{
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
