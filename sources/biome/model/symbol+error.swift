extension Biome 
{
    public 
    enum SymbolIdentifierError:Error 
    {
        // global errors 
        case duplicate(symbol:Symbol.ID, in:Module.ID, bystander:Module.ID?)
        case undefined(symbol:Symbol.ID)
        // local errors
        
        /// unique id is completely empty
        case empty
        /// unique id does not start with a supported language prefix (‘c’ or ‘s’)
        // case unsupportedLanguage(code:UInt8)
    }
    public 
    enum SymbolExtensionError:Error 
    {
        case mismatch(decoded:Module.ID, expected:Module.ID, in:Symbol.ID)
    }
    enum SymbolAvailabilityError:Error 
    {
        case duplicate(domain:Symbol.Domain, in:Symbol.ID)
    }
    enum LinkingError:Error 
    {
        case constraints(on:Int, is:Edge.Kind, of:Int)
        case duplicate(Int, have:Int, is:Edge.Kind, of:Int)
        
        
        case members([Int], in:Symbol.Kind, Int) 
        case conformers([(index:Int, conditions:[Language.Constraint])], in:Symbol.Kind, Int) 
        case conformances([(index:Int, conditions:[Language.Constraint])], in:Symbol.Kind, Int) 
        case requirements([Int], in:Symbol.Kind, Int) 
        case subclasses([Int], in:Symbol.Kind, Int) 
        case superclass(Int, in:Symbol.Kind, Int) 
        
        case defaultImplementationOf([Int], Symbol.Kind, Int) 
        case specializationOf(Int, Symbol.Kind, Int) 
        case requirementOf(Int, Symbol.Kind, Int) 
        case overrideOf(Int, Symbol.Kind, Int) 
        
        case island(associatedtype:Int)
        case orphaned(symbol:Int)
        case junction(symbol:Int)
    }
}
