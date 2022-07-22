import Versions 
import JSON

public 
struct PackageResolution
{
    public
    var pins:[Pin.ID: MaskedVersion]

    public
    init(pins:[Pin])
    {
        self.pins = [:]
        for pin:Pin in pins 
        {
            // these strings are slightly different from the ones we 
            // parse from url queries 
            switch pin.state.requirement 
            {
            case .version(let version):
                self.pins[pin.id] = version
            case .branch(let branch):
                self.pins[pin.id] = .init(branch) ?? .init(toolchain: branch)
            }
        }
    }
    public 
    init(from json:JSON) throws 
    {
        let pins:[Pin] = try json.lint   
        {
            switch try $0.remove("version", as: Int.self)
            {
            case 1:
                return try $0.remove("object") 
                {
                    try $0.lint 
                    { 
                        try $0.remove("pins", as: [JSON].self) 
                        {
                            try $0.map(Pin.init(from:))
                        }
                    }
                }
            case 2:
                return  try $0.remove("pins", as: [JSON].self)
                {
                            try $0.map(Pin.init(from:))
                }
            default: 
                fatalError("unsupported Package.resolved format") 
            }
        }
        self.init(pins: pins)
    }
    @inlinable public
    init<UTF8>(parsing json:UTF8) throws 
        where UTF8:Collection, UTF8.Element == UInt8
    {
        try self.init(from: try Grammar.parse(json, as: JSON.Rule<UTF8.Index>.Root.self))
    }
}
