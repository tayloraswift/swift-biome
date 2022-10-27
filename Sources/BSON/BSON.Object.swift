extension BSON
{
    @frozen public 
    struct Object
    {
        public 
        typealias Seed = 
        (
            UInt8,
            UInt8,
            UInt8,
            UInt8,
            UInt8
        )
        public 
        typealias Ordinal = 
        (
            UInt8,
            UInt8,
            UInt8
        )

        public 
        let timestamp:UInt32 
        public 
        let seed:Seed
        public 
        let ordinal:Ordinal

        @inlinable public
        init(timestamp:UInt32, _ seed:Seed, _ ordinal:Ordinal)
        {
            self.timestamp = timestamp
            self.seed = seed
            self.ordinal = ordinal
        }
    }
}
