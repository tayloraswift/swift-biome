infix operator ==? :ComparisonPrecedence
infix operator ..? :ComparisonPrecedence

public
struct SourceLocation
{
    public
    let function:String
    public
    let file:String
    public
    let line:Int
    public
    let column:Int

    @inlinable public
    init(function:String, file:String, line:Int, column:Int)
    {
        self.function = function
        self.file = file
        self.line = line
        self.column = column        
    }
}
extension SourceLocation:CustomStringConvertible
{
    public
    var description:String
    {
        "\(file):\(line):\(column)"
    }
}

public
struct AssertionFailure<Base>:Error, CustomStringConvertible
{
    public
    let location:SourceLocation
    public
    let base:Base 

    @inlinable public
    init(_ base:Base, location:SourceLocation)
    {
        self.base = base
        self.location = location
    }
    public 
    var description:String
    {
        """
        \(self.location): \(self.base)
        """
    }
}
public
struct AssertBooleanFailure:CustomStringConvertible  
{
    @inlinable public
    init()
    {
    }
    public 
    var description:String
    {
        "expected true"
    }
}
public
struct AssertEquivalenceFailure<T>:CustomStringConvertible  
{
    public
    let lhs:T
    public
    let rhs:T

    @inlinable public
    init(lhs:T, rhs:T)
    {
        self.lhs = lhs
        self.rhs = rhs
    }
    public 
    var description:String
    {
        """
        expected equal values
        {
            lhs: \(lhs),
            rhs: \(rhs)
        }
        """
    }
}
public
struct AssertOptionalUnwrapFailure<Wrapped>:Error, CustomStringConvertible 
{
    @inlinable public
    init()
    {
    }
    public 
    var description:String
    {
        "expected non-nil value of type \(Wrapped.self)"
    }
}
public
struct AssertThrownErrorFailure<Expected>:Error, CustomStringConvertible
    where Expected:Error & Equatable
{
    public
    let thrown:(any Error)?
    public
    let expected:Expected

    @inlinable public
    init(thrown:(any Error)?, expected:Expected)
    {
        self.thrown = thrown
        self.expected = expected
    }
    public 
    var description:String
    {
        if let thrown:any Error = self.thrown
        {
            return "expected thrown error '\(self.expected)', but caught '\(thrown)'"
        }
        else
        {
            return "expected thrown error '\(self.expected)'"
        }
    }
}

public
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
public
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

public
protocol UnitTests
{
    var passed:Int { get set }
    var failed:[any Error] { get set }
}
extension UnitTests
{
    public
    func summarize()
    {
        print("passed: \(self.passed) test(s)")
        print("failed: \(self.failed.count) test(s)")
        for (ordinal, failure):(Int, any Error) in self.failed.enumerated()
        {
            print("\(ordinal). \(failure)")
        }
    }
}
extension UnitTests
{
    @inlinable public mutating 
    func assert<T>(_ error:AssertEquivalenceFailure<T>?, 
        function:String = #function, 
        file:String = #file, 
        line:Int = #line, 
        column:Int = #column) 
    {
        if let error:AssertEquivalenceFailure<T>
        {
            self.failed.append(AssertionFailure<AssertEquivalenceFailure<T>>.init(error,
                location: .init(function: function, file: file, line: line, column: column)))
        }
        else 
        {
            self.passed += 1
        }
    }
    @inlinable public mutating 
    func assert(_ test:Bool, 
        function:String = #function,
        file:String = #file,
        line:Int = #line,
        column:Int = #column)  
    {
        if test 
        {
            self.passed += 1
        }
        else
        {
            self.failed.append(AssertionFailure<AssertBooleanFailure>.init(.init(),
                location: .init(function: function, file: file, line: line, column: column)))
        }
    }
    @inlinable public mutating
    func unwrap<Wrapped>(_ optional:Wrapped?, 
        file:String = #file, 
        function:String = #function, 
        line:Int = #line, 
        column:Int = #column) throws -> Wrapped
    {
        if let wrapped:Wrapped = optional
        {
            return wrapped 
        }
        else 
        {
            let error:AssertOptionalUnwrapFailure<Wrapped> = .init()
            self.failed.append(AssertionFailure<AssertOptionalUnwrapFailure<Wrapped>>.init(error,
                location: .init(function: function, file: file, line: line, column: column)))
            throw error
        }
    }
}
extension UnitTests
{
    @inlinable public mutating 
    func assert<Failure>(failure:Failure, 
        function:String = #function, 
        file:String = #file, 
        line:Int = #line, 
        column:Int = #column,
        body:() throws -> ())
        where Failure:Error & Equatable
    {
        let error:AssertThrownErrorFailure<Failure>
        do
        {
            try body()
            error = .init(thrown: nil, expected: failure)
        }
        catch failure as Failure
        {
            self.passed += 1
            return
        }
        catch let other
        {
            error = .init(thrown: other, expected: failure)
        }

        self.failed.append(AssertionFailure<AssertThrownErrorFailure<Failure>>.init(error,
            location: .init(function: function, file: file, line: line, column: column)))
    }
}