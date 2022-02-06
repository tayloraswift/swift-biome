import Glibc
import JSON 

enum Demangle 
{
    enum Rule<Location> 
    {
        typealias Codepoint = Grammar.Encoding<Location, Unicode.Scalar> 
    }
}
extension Demangle.Rule 
{
    enum MangledName:ParsingRule 
    {
        typealias Terminal = Unicode.Scalar 
        
        enum Element:Grammar.TerminalClass 
        {
            typealias Terminal      = Unicode.Scalar 
            typealias Construction  = Character 
            static 
            func parse(terminal:Unicode.Scalar) -> Character?
            {
                switch terminal
                {
                // A-Z, a-z, 0-9, _
                case "0" ... "9", "A" ... "Z", "a" ... "z", "_": 
                    return .init(terminal)
                default: 
                    return nil
                }
            }
        }
        
        static 
        func parse<Diagnostics>(_ input:inout ParsingInput<Diagnostics>) throws -> String
            where   Diagnostics:ParsingDiagnostics, 
                    Diagnostics.Source.Index == Location, Diagnostics.Source.Element == Terminal
        {
            let prefix:String = input.parse(as: Element.self, in: String.self)
            try input.parse(as: Codepoint.Colon.self)
            let suffix:String = input.parse(as: Element.self, in: String.self)
            return prefix + suffix
        }
    }
}
extension Demangle 
{
    private 
    typealias Function = @convention(c) 
    (
        _ name:UnsafePointer<UInt8>?,
        _ count:Int,
        _ output:UnsafeMutablePointer<UInt8>?,
        _ capacity:UnsafeMutablePointer<Int>?,
        _ flags:UInt32
    ) -> UnsafeMutablePointer<Int8>?
    
    private static 
    var function:Function = 
    {
        guard let swift:UnsafeMutableRawPointer = dlopen(nil, RTLD_NOW)
        else 
        {
            fatalError("could not load swift runtime")
        }
        guard let symbol:UnsafeMutableRawPointer = dlsym(swift, "swift_demangle") 
        else 
        {
            fatalError("could not load symbll 'swift_demangle'")
        }
        return unsafeBitCast(symbol, to: Function.self)
    }()
    
    static 
    subscript(mangled:String) -> String
    {
        guard let string:UnsafeMutablePointer<Int8> = self.function("$\(mangled)", mangled.utf8.count, nil, nil, 0)
        else 
        {
            print("warning: could not demangle symbol '\(mangled)'")
            return mangled 
        }
        defer 
        {
            string.deallocate()
        }
        return String.init(cString: string)
    }
}
