infix operator ==? :ComparisonPrecedence
infix operator ..? :ComparisonPrecedence

extension Assert
{
    public
    struct Equivalence<T>:CustomStringConvertible  
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
}

@inlinable public
func ..? <LHS, RHS>(lhs:LHS, rhs:RHS) -> Assert.Equivalence<[LHS.Element]>?
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
@inlinable public
func ==? <T>(lhs:T, rhs:T) -> Assert.Equivalence<T>?
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
