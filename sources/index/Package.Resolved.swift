import Biome 
import JSON

extension Package 
{
    public 
    struct Resolved
    {
        // needed for compatibility with older spm tools
        @usableFromInline
        struct Legacy:Decodable
        {
            @usableFromInline
            let object:Object
        }
        @usableFromInline
        struct Object:Decodable 
        {
            struct State:Decodable 
            {
                let revision:String, 
                    version:String?, 
                    branch:String?
            }
            @usableFromInline 
            struct Pin:Decodable 
            {
                let id:ID?, 
                    package:ID?,
                    location:String?, 
                    state:State 
                    
                enum CodingKeys:String, CodingKey 
                {
                    case id = "identity" 
                    case package 
                    case location 
                    case state 
                }
            }
            
            @usableFromInline 
            let pins:[Pin]
        }
        
        public
        var pins:[ID: MaskedVersion]
        
        @inlinable public
        init<UTF8>(parsing json:UTF8) throws 
            where UTF8:Collection, UTF8.Element == UInt8
        {
            let json:JSON = try Grammar.parse(json, as: JSON.Rule<UTF8.Index>.Root.self)
            if  let object:Object = try? .init(from: json)
            {
                self.init(pins: object.pins)
            }
            else 
            {
                let wrapper:Legacy = try .init(from: json)
                self.init(pins: wrapper.object.pins)
            }
        }
        @usableFromInline 
        init(pins:[Object.Pin])
        {
            self.pins = [:]
            for pin:Object.Pin in pins 
            {
                guard let id:ID = pin.id ?? pin.package 
                else 
                {
                    continue 
                }
                // these strings are slightly different from the ones we 
                // parse from url queries 
                if let string:String = pin.state.version
                {
                    // always 3 components 
                    let numbers:[Substring] = string.split(separator: ".")
                    if  numbers.count == 3, 
                        let major:UInt16 = .init(numbers[0]),
                        let minor:UInt16 = .init(numbers[1]),
                        let patch:UInt16 = .init(numbers[2])
                    {
                        self.pins[id] = .patch(major, minor, patch)
                    }
                }
                else if let string:String = pin.state.branch
                {
                    let words:[Substring] = string.split(separator: "-")
                    if  words.count == 7, 
                        words[0] == "swift", 
                        words[1] == "DEVELOPMENT", 
                        words[2] == "SNAPSHOT", 
                        let year:UInt16 = .init(words[3]), 
                        let month:UInt16 = .init(words[4]), 
                        let day:UInt16 = .init(words[5]), 
                        let letter:Unicode.Scalar = words[6].unicodeScalars.first,
                        "a" ... "z" ~= letter
                    {
                        self.pins[id] = .hourly(year: year, month: month, day: day, 
                            letter: .init(ascii: letter))
                        continue 
                    }
                    
                    let numbers:[Substring] = string.split(separator: ".")
                    if  numbers.count == 4, 
                        let major:UInt16 = .init(numbers[0]),
                        let minor:UInt16 = .init(numbers[1]),
                        let patch:UInt16 = .init(numbers[2]),
                        let edition:UInt16 = .init(numbers[3])
                    {
                        self.pins[id] = .edition(major, minor, patch, edition)
                        continue 
                    }
                }
            }
        }
    }
}
