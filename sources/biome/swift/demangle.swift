#if os(Linux)
import Glibc
#elseif os(macOS)
import Darwin
#endif 

enum Demangle 
{
    #if os(Linux) || os(macOS)
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
            fatalError("could not load symbol 'swift_demangle'")
        }
        return unsafeBitCast(symbol, to: Function.self)
    }()
    
    static 
    subscript(mangled:[UInt8]) -> String
    {
        // '$s' 
        let prefixed:[UInt8] = [0x24, 0x73] + mangled
        guard let string:UnsafeMutablePointer<Int8> = self.function(prefixed, prefixed.count, nil, nil, 0)
        else 
        {
            print("warning: could not demangle symbol '\(String.init(decoding: mangled, as: Unicode.UTF8.self))'")
            return String.init(decoding: mangled, as: Unicode.UTF8.self) 
        }
        defer 
        {
            string.deallocate()
        }
        return String.init(cString: string)
    }
    #else 
    static 
    subscript(mangled:String) -> String
    {
        print("warning: could not demangle symbol '\(mangled)' (demangling not supported on this platform)")
        return mangled
    }
    #endif
}
