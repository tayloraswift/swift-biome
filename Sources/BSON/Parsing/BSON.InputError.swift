extension BSON
{
    /// A parser did not receive the expected amount of input.
    @frozen public
    struct InputError:Equatable, Error
    {
        @frozen public
        enum Expectation:Equatable
        {
            /// The input should have yielded end-of-input.
            case end
            /// The input should have yielded a terminator byte that never appeared.
            case byte(UInt8)
            /// The input should have yielded a particular number of bytes.
            case bytes(Int)
        }

        /// What the input should have yielded.
        public
        let expected:Expectation
        /// The number of bytes available in the input.
        public
        let encountered:Int

        @inlinable public
        init(expected:Expectation, encountered:Int = 0)
        {
            self.expected = expected
            self.encountered = encountered
        }
    }
}
extension BSON.InputError.Expectation:CustomStringConvertible
{
    public
    var description:String
    {
        switch self
        {
        case .end:
            return "end-of-input"
        case .byte(let byte):
            return "terminator byte (\(byte))"
        case .bytes(let count):
            return "\(count) byte(s)"
        }
    }
}
extension BSON.InputError:CustomStringConvertible
{
    public
    var description:String
    {
        self.encountered == 0 ?
            "expected \(self.expected)" :
            "expected \(self.expected), encountered \(self.encountered) byte(s)"
    }
}
