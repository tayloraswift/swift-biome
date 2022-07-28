import JSON 

extension Generic 
{
    init(from json:JSON) throws 
    {
        let tuple:[JSON] = try json.as([JSON].self, count: 3)
        self.name  = try tuple.load(0)
        self.index = try tuple.load(1)
        self.depth = try tuple.load(2)
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

