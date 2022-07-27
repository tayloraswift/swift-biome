import Notebook 
import JSON

extension Notebook<Highlight, Never>
{
    init(from json:JSON) throws 
    {
        self.init(try json.as([JSON].self).lazy.map 
        {
            try $0.shape(2)
            {
                (
                    try $0.load(0, as: String.self),
                    try $0.load(1) { try $0.as(cases: Highlight.self) }
                )
            }
        })
    }
}
extension Notebook<Highlight, Int>
{
    init(from json:JSON) throws 
    {
        self.init(try json.as([JSON].self).lazy.map(Fragment.init(from:)))
    }
}

extension Notebook<Highlight, Int>.Fragment
{
    init(from json:JSON) throws 
    {
        self = try json.shape { 2 ... 3 ~= $0 } decode:
        {
            .init(try $0.load(0, as: String.self),
                color: try $0.load(1) { try $0.as(cases: Highlight.self) },
                link: try $0.count == 3 ? $0.load(2, as: Int.self) : nil
            )
        }
    }
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