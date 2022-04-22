extension Symbol.Kind
{
    var orientation:URI.LexicalPath.Orientation 
    {
        switch self
        {
        case    .associatedtype, .typealias, .enum, .struct, .class, .actor, .protocol:
            return .straight
        case    .case, .initializer, .deinitializer, 
                .typeSubscript, .instanceSubscript, 
                .typeProperty, .instanceProperty, 
                .typeMethod, .instanceMethod, 
                .var, .func, .operator:
            return .gay
        }
    }
}
extension Symbol 
{
    var orientation:URI.LexicalPath.Orientation 
    {
        self.kind.orientation
    }
    
    enum Depth
    {
        case shallow 
        case deep
        case full
    }
    struct Pairing:Hashable
    {
        private 
        let _witness:UInt32
        private 
        let _victim:UInt32
        
        var witness:Int 
        {
            .init(self._witness)
        }
        var victim:Int?
        {
            self._victim == .max ? nil : .init(self._victim)
        }
        
        init(_ index:Int) 
        {
            self._witness = .init(index)
            self._victim = .max
        }
        init(witness:Int, victim:Int)
        {
            self._witness = .init(witness)
            self._victim = .init(victim)
            precondition(self._victim != .max)
        }
    }
    // 24B stride
    enum Group 
    {
        // this is three words long, but that’s probably okay because they 
        // live in small dictionaries 
        struct Victims 
        {
            var first:Int?
            var overflow:[Int]
            
            init(_ first:Int? = nil)
            {
                self.first = first
                self.overflow = []
            }
            
            mutating 
            func insert(_ next:Int?)
            {
                guard let victim:Int = next
                else 
                {
                    return 
                }
                if case nil = self.first 
                {
                    self.first = victim
                }
                else 
                {
                    self.overflow.append(victim)
                }
            }
        }
        
        case _deinitialized
        
        case big              (Pairing)
        case bigDeep         ([Int: Victims])
        case bigDeepDoubled  ([Int: Victims],   Pairing)
        case doubled          (Pairing,         Pairing)
        case deep            ([Int: Victims],  [Int: Victims])
        case littleDeepDoubled(Pairing,        [Int: Victims])
        case littleDeep                       ([Int: Victims])
        case little                            (Pairing)
        
        func depth(of symbol:(orientation:URI.LexicalPath.Orientation, index:Int)) -> Depth 
        {
            switch  (self, symbol.orientation) 
            {
            case    (.big,                          .straight), 
                    (.littleDeepDoubled,            .straight), 
                    (.doubled, _),
                    (.bigDeepDoubled,               .gay), 
                    (.little,                       .gay):
                return .shallow
            case    (   .bigDeep(let overloads),    .straight),
                    (      .deep(let overloads, _), .straight),
                    (      .deep(_, let overloads), .gay),
                    (.littleDeep(   let overloads), .gay):
                switch overloads[symbol.index]?.overflow.isEmpty
                {
                case nil:
                    fallthrough
                case true?: 
                    return .deep 
                case false?:
                    // should be *extremely* rare
                    return .full 
                }
            default: 
                fatalError("unreachable")
            }
        }
        
        mutating 
        func merge(_ value:Self) 
        {
            func overlay(_ next:Pairing, into stack:inout [Int: Victims])
            {
                stack[next.witness, default: .init()].insert(next.victim)
            }
            func overlay(_ first:Pairing, _ next:Pairing) -> [Int: Victims]
            {
                var stack:[Int: Victims] = [first.witness: .init(first.victim)]
                overlay(next, into: &stack)
                return stack
            }
            
            switch value 
            {
            case (.big(let next)):
                switch self 
                {
                case .little                              (let little):
                    self =                     .doubled(next,  little)
                case .littleDeep                          (let little):
                    self =           .littleDeepDoubled(next,  little)
                case .littleDeepDoubled       (let big,    let little):
                    self =           .deep(overlay(big, next), little)
                case .doubled                 (let big,    let little):
                    self = .bigDeepDoubled(overlay(big, next), little)
                
                case .big                     (let big):
                    self =        .bigDeep(overlay(big, next))
                
                case .deep                    (var stack,  let little):
                    self = ._deinitialized
                    overlay(next,           into: &stack)
                    self =                   .deep(stack,      little)
                case .bigDeepDoubled          (var stack,  let little):
                    self = ._deinitialized
                    overlay(next,           into: &stack)
                    self =         .bigDeepDoubled(stack,      little)
                case .bigDeep                 (var stack):
                    self = ._deinitialized
                    overlay(next,           into: &stack)
                    self =             .littleDeep(stack)
                case ._deinitialized:
                    fatalError("unreachable")
                }
            case (.little(let next)):
                switch self 
                {
                case .big                   (let big):
                    self =              .doubled(big,                 next)
                case .bigDeep               (let big):
                    self =       .bigDeepDoubled(big,                 next)
                case .bigDeepDoubled        (let big,     let little):
                    self =                 .deep(big, overlay(little, next))
                case .doubled               (let big,     let little):
                    self =    .littleDeepDoubled(big, overlay(little, next))
                
                case .little                             (let little):
                    self =                .littleDeep(overlay(little, next))
                
                case .deep                  (let big,     var stack):
                    self = ._deinitialized
                    overlay(next,                      into: &stack)
                    self =                 .deep(big,         stack)
                case .littleDeepDoubled     (let big,     var stack):
                    self = ._deinitialized
                    overlay(next,                      into: &stack)
                    self =    .littleDeepDoubled(big,         stack)
                case .littleDeep                         (var stack):
                    self = ._deinitialized
                    overlay(next,                      into: &stack)
                    self =                        .littleDeep(stack)
                case ._deinitialized:
                    fatalError("unreachable")
                }
            default: 
                fatalError("unsupported operation")
            }
        }
    }
}
