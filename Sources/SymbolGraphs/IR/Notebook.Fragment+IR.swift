import Notebook 
import JSON

extension Notebook<Highlight, Int>.Fragment
{
    var serialized:JSON 
    {
        if let link:Int = self.link
        {
            return [.string(self.text), .number(self.color.rawValue), .number(link)]
        }
        else 
        {
            return [.string(self.text), .number(self.color.rawValue)]
        }
    }
}
extension Notebook<Highlight, Never>.Fragment
{
    var serialized:JSON 
    {
        [.string(self.text), .number(self.color.rawValue)]
    }
}