import SymbolGraphs
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
                self.pins[pin.id] = 
                    (try? .init(parsing:   branch)) ?? 
                    (try? .init(toolchain: branch))
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
    init<UTF8>(parsing utf8:UTF8) throws where UTF8:Collection<UInt8>
    {
        try self.init(from: try JSON.init(parsing: utf8))
    }
}
