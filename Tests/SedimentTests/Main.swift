import Sediment 

infix operator ==? :ComparisonPrecedence
infix operator ..? :ComparisonPrecedence

struct OptionalUnwrapFailure<Wrapped>:Error, CustomStringConvertible 
{
    var description:String
    {
        """
        expected non-nil value of type \(Wrapped.self)
        """
    }
}
struct AssertionFailure:Error, CustomStringConvertible 
{
    var description:String
    {
        """
        expected true
        """
    }
}
struct AssertEquivalenceFailure<T>:Error, CustomStringConvertible  
{
    let lhs:T
    let rhs:T

    var description:String
    {
        """
        expected equal values: 
        {
            lhs: \(lhs),
            rhs: \(rhs)
        }
        """
    }
}
func ..? <LHS, RHS>(lhs:LHS, rhs:RHS) -> AssertEquivalenceFailure<[LHS.Element]>?
    where LHS:Sequence, RHS:Sequence, LHS.Element == RHS.Element, LHS.Element:Equatable
{
    let rhs:[LHS.Element] = .init(rhs)
    let lhs:[LHS.Element] = .init(lhs)
    if  lhs.elementsEqual(rhs) 
    {
        return nil 
    }
    else 
    {
        return .init(lhs: lhs, rhs: rhs)
    }
}
func ==? <T>(lhs:T, rhs:T) -> AssertEquivalenceFailure<T>?
    where T:Equatable
{
    if  lhs == rhs
    {
        return nil 
    }
    else 
    {
        return .init(lhs: lhs, rhs: rhs)
    }
}

struct Validator
{
    let name:String
    var head:Sediment<Int, String>.Head?
    var history:[(Int, String)]
    var counter:Int

    init(name:String)
    {
        self.name = name
        self.head = nil
        self.history = []
        self.counter = 0
    }

    mutating 
    func deposit(to sediment:inout Sediment<Int, String>, time:Range<Int>)
    {
        if .random()
        {
            let token:String = "\(self.name).\(self.counter)"
            self.counter += 1
            self.head = sediment.deposit(token, time: time.lowerBound, over: self.head)
            self.history.append(contentsOf: time.map { ($0, token) })
        }
        else if let token:String = self.history.last?.1 
        {
            self.history.append(contentsOf: time.map { ($0, token) })
        }
    }
    mutating
    func rollback(until time:Int, rollbacks:Sediment<Int, String>.Rollbacks)
    {
        if let index:Int = self.history.firstIndex(where: { time < $0.0 })
        {
            self.history.removeSubrange(index...)
        }
        self.head = self.head.flatMap { rollbacks[$0] }
    }
}


@main 
struct Main 
{
    mutating 
    func assert<T>(_ error:AssertEquivalenceFailure<T>?, 
        file:String = #file, 
        function:String = #function, 
        line:Int = #line, 
        column:Int = #column) 
    {
        if let error:AssertEquivalenceFailure<T>
        {
            print("\(file):\(line):\(column): \(error)")
            self.failed.append(error)
        }
        else 
        {
            self.passed += 1
        }
    }
    mutating 
    func assert(_ test:Bool, 
        file:String = #file, 
        function:String = #function, 
        line:Int = #line, 
        column:Int = #column)  
    {
        if test 
        {
            self.passed += 1
        }
        else
        {
            print("\(file):\(line):\(column): test failed")
            self.failed.append(AssertionFailure.init())
        }
    }
    func unwrap<Wrapped>(_ optional:Wrapped?, 
        file:String = #file, 
        function:String = #function, 
        line:Int = #line, 
        column:Int = #column) -> Wrapped?
    {
        if let wrapped:Wrapped = optional
        {
            return wrapped 
        }
        else 
        {
            print("\(file):\(line):\(column): optional unwrap failed")
            return nil
        }
    }

    var passed:Int 
    var failed:[any Error]

    init() 
    {
        self.passed = 0
        self.failed = []
    }

    static 
    func main() 
    {
        var tests:Self = .init()
        for i:Int in 0 ..< 500
        {
            print("performing fuzzing iteration \(i)")
            tests.main()
        }
        print("passed: \(tests.passed)")
        print("failed: \(tests.failed.count)")
    }
    mutating 
    func main() 
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
        self.assert(sediment[validator.head].validate())
        for (time, token):(Int, String) in validator.history
        {
            if  let index:Sediment<Int, String>.Index = 
                    self.unwrap(sediment[validator.head].find(time))
            {
                self.assert(sediment[index].value ==? token)
            }
        }
    }
}