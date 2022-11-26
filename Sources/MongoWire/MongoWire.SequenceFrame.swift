import BSONTraversal

extension MongoWire
{
    public
    enum SequenceFrame:VariableLengthBSONFrame
    {
        public static
        let prefix:Int = 4
        public static
        let suffix:Int = 0
    }
}
