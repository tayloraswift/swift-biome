import BSONTraversal

extension BSON
{
    public
    struct HeaderError<Frame>:Equatable, Error where Frame:VariableLengthBSONFrame
    {
        public
        let length:Int

        public
        init(length:Int)
        {
            self.length = length
        }
    }
}
extension BSON.HeaderError:CustomStringConvertible
{
    public
    var description:String
    {
        """
        length declared in header (\(self.length)) is less than \
        the minimum for '\(Frame.self)' (\(Frame.prefix + Frame.suffix) bytes)
        """
    }
}
