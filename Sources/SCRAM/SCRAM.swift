/// A namespace for [SCRAM](https://www.rfc-editor.org/rfc/rfc5802)-related types.
public
enum SCRAM
{
    static
    func escape(name:some StringProtocol) -> String
    {
        var escaped:String = ""
            escaped.reserveCapacity(name.utf8.count)
        for character:Character in name
        {
            switch character
            {
            case "=":       escaped += "=3D"
            case ",":       escaped += "=2C"
            case let other: escaped.append(other)
            }
        }
        return escaped
    }
}
