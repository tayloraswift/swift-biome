import JSON 

extension Generic.Constraint<Int> 
{
    init(from json:JSON) throws 
    {
        self = try json.shape { 3 ... 4 ~= $0 } decode:
        {
            .init(
                try $0.load(0, as: String.self),
                try $0.load(1) { try $0.as(cases: Generic.Verb.self) },
                try $0.load(2, as: String.self),
                target: try $0.count == 4 ? $0.load(3, as: Int.self) : nil
            )
        }
    }
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