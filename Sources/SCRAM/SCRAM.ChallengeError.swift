extension SCRAM
{
    public
    enum ChallengeError:Error
    {
        case attribute(missing:Attribute)
        case nonce(Nonce, sent:Nonce)
    }
}
extension SCRAM.ChallengeError:CustomStringConvertible
{
    public
    var description:String
    {
        switch self
        {
        case .attribute(missing: let attribute):
            return "missing expected attribute '\(attribute)'"
        
        case .nonce(let received, sent: let sent):
            return "received nonce '\(received)' is inconsistent with sent nonce '\(sent)'"
        }
    }
}
