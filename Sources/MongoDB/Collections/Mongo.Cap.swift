extension Mongo
{
    @frozen public
    struct Cap:Sendable
    {
        public
        let size:Int
        public
        let max:Int?

        @inlinable public
        init(size:Int, max:Int? = nil)
        {
            self.size = size
            self.max = max
        }
    }
}
