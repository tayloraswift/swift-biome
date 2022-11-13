extension SCRAM
{
    @frozen public
    struct Challenge
    {
        public
        let iterations:Int
        public
        let nonce:Nonce
        public
        let salt:String

        private
        init(iterations:Int, nonce:Nonce, salt:String)
        {
            self.iterations = iterations
            self.nonce = nonce
            self.salt = salt
        }
    }
}

extension SCRAM.Challenge
{
    public
    init(from message:SCRAM.Message) throws
    {
        var iterations:Int? = nil
        var nonce:String? = nil
        var salt:String? = nil

        for (attribute, value):(SCRAM.Attribute, Substring) in message.fields()
        {
            switch attribute
            {
            case .random:
                nonce = .init(value)
            case .salt:
                salt = .init(value)
            case .iterations:
                iterations = .init(value)
            default:
                continue
            }
        }
        guard let iterations:Int
        else
        {
            throw SCRAM.ChallengeError.attribute(missing: .iterations)
        }
        guard let nonce:String
        else
        {
            throw SCRAM.ChallengeError.attribute(missing: .random)
        }
        guard let salt:String
        else
        {
            throw SCRAM.ChallengeError.attribute(missing: .salt)
        }
        
        self.init(iterations: iterations, nonce: .init(nonce), salt: salt)
    }
}
