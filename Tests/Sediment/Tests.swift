import Sediment
import Testing

extension Tests
{
    mutating 
    func run() 
    {
        var sediment:Sediment<Int, String> = .init()
        var a:Validator = .init(name: "a"),
            b:Validator = .init(name: "b"),
            c:Validator = .init(name: "c")
        
        var time:Int = 0
        while time < 1024
        {
            let span:Range<Int> = time ..< time + .random(in: 1 ... 8)

            a.deposit(to: &sediment, time: span)
            b.deposit(to: &sediment, time: span)
            c.deposit(to: &sediment, time: span)

            time = span.upperBound
        }
        
        self.check(a, sediment: sediment)
        self.check(b, sediment: sediment)
        self.check(c, sediment: sediment)

        time = .random(in: 0 ..< time)

        let rollbacks:Sediment<Int, String>.Rollbacks = sediment.erode(until: time) 
        a.rollback(until: time, rollbacks: rollbacks)
        b.rollback(until: time, rollbacks: rollbacks)
        c.rollback(until: time, rollbacks: rollbacks)
        self.check(a, sediment: sediment)
        self.check(b, sediment: sediment)
        self.check(c, sediment: sediment)

        // cannot have duplicate timestamps
        time += 1
        while time < 1024
        {
            let span:Range<Int> = time ..< time + .random(in: 1 ... 8)

            a.deposit(to: &sediment, time: span)
            b.deposit(to: &sediment, time: span)
            c.deposit(to: &sediment, time: span)

            time = span.upperBound
        }
        self.check(a, sediment: sediment)
        self.check(b, sediment: sediment)
        self.check(c, sediment: sediment)
    }
    mutating 
    func check(_ validator:Validator, sediment:Sediment<Int, String>)
    {
        self.assert(sediment[validator.head].validate(),
            name: "validate")
        for (time, token):(Int, String) in validator.history
        {
            if  let index:Sediment<Int, String>.Index = self.unwrap(
                    sediment[validator.head].find(time),
                    name: "find@\(time)")
            {
                self.assert(sediment[index].value ==? token,
                    name: "value@\(time)")
            }
        }
    }
}
