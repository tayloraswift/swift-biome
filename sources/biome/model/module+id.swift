extension Biome.Module 
{
    public
    struct ID:Hashable, Sendable
    {
        let string:String 
        
        init<S>(_ string:S) where S:StringProtocol 
        {
            self.string = .init(string)
        }
        
        var title:Substring 
        {
            self.string.drop { $0 == "_" } 
        }
        
        func graphIdentifier(bystander:Self?) -> String
        {
            bystander.map { "\(self.string)@\($0.string)" } ?? self.string
        }
    }
}
