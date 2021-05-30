# entrapta 

*Entrapta* is an experimental tool to generate richly-linked, Apple-style API reference websites for Swift projects which can be deployed with Github Pages. 

## usage 

```bash
# build a deployable website 
entrapta sources/*.swift 
    --directory     "directory/to/build/website/in" 
    --url-prefix    "https://adora.github.io/repository-name" 
    --github        "https://github.com/adora/repository-name"
    --title         "HTML Title to Display"

# build a local website 
entrapta sources/*.swift 
    --directory     "directory/to/build/website/in" 
    # url-prefix must be an absolute path
    --url-prefix    "$PWD/directory/to/build/website/in"
    --github        "https://github.com/adora/repository-name"
    --title         "HTML Title to Display"
    --local
```

## syntax 

*Entrapta* collects three-slash (`///`) documentation comments in your project. An *Entrapta*-readable doccoment looks like this:

```
/// static func JPEG.Format.recognize(_:precision:)
/// required 
///     Detects this color format, given a set of component keys and a bit depth.
/// - components    : Swift.Set<JPEG.Component.Key>
///     The set of given component keys.
/// - precision     : Swift.Int
///     The given bit depth.
/// - ->            : Self?
///     A color format instance.
```

The full syntax is this:

```
Whitespace              ::= ' ' ' ' *
Endline                 ::= ' ' * '\n'

FunctionIdentifiers     ::= ( <Identifier> '.' ) * '(' <Operator> ')'
                          | ( <Identifier> '.' ) * <Identifier>

Identifiers             ::= <Identifier> ( '.' <Identifier> ) * 
Identifier              ::= <Swift Identifier Head> <Swift Identifier Character> *
Operator                ::= <Swift Operator Head> <Swift Operator Character> *
                          | <Swift Dot Operator Head> <Swift Dot Operator Character> *

FrameworkField          ::= <FrameworkField.Keyword> <Whitespace> <Identifier> <Endline>
FrameworkField.Keyword  ::= 'module'
                          | 'plugin'

DependencyField         ::= 'import' <Whitespace> <Identifier> <Endline>
                          | 'import' <Whitespace> <DependencyField.Keyword> <Whitespace> 
                            <Identifier> '.' <Identifiers> <Endline>
DependencyField.Keyword ::= 'protocol'
                          | 'class'
                          | 'struct'
                          | 'enum'
                          | 'typealias'

LexemeField             ::= ( <LexemeField.Keyword> <Whitespace> ) ? 
                            'operator' <Whitespace> <Operator> 
                            ( <Whitespace> ? ':' <Whitespace> ? <Identifier> ) ?
                            <Endline>
                          
FunctionField           ::= <FunctionField.Keyword> <Whitespace> <FunctionIdentifiers> <TypeParameters> ? '?' ? 
                            '(' ( <Identifier> ':' ) * ')' 
                            ( <Whitespace> <FunctionField.Throws> ) ? <Endline>
                          | 'case' <Whitespace> <FunctionIdentifiers> <Endline>
FunctionField.Keyword   ::= 'init'
                          | 'required' <Whitespace> 'init'
                          | 'convenience' <Whitespace> 'init'
                          | 'func'
                          | 'mutating' <Whitespace> 'func'
                          | 'prefix' <Whitespace> 'func'
                          | 'postfix' <Whitespace> 'func'
                          | 'static' <Whitespace> 'func'
                          | 'static' <Whitespace> 'prefix' <Whitespace> 'func'
                          | 'static' <Whitespace> 'postfix' <Whitespace> 'func'
                          | 'case' 
                          | 'indirect' <Whitespace> 'case' 
FunctionField.Throws    ::= 'throws' 
                          | 'rethrows'

SubscriptField          ::= 'subscript' <Whitespace> <Identifiers> <TypeParameters> ? 
                            '[' ( <Identifier> ':' ) * ']' <Whitespace> ? <Accessors> <Endline> 

TypeParameters          ::= '<' <Whitespace> ? <Identifier> <Whitespace> ? 
                            ( ',' <Whitespace> ? <Identifier> <Whitespace> ? ) * '>'
                                                        
PropertyField           ::= <PropertyField.Keyword> <Whitespace> <Identifiers> 
                            <Whitespace> ? ':' <Whitespace> ? <Type> 
                            ( <Whitespace> ? <MemberMutability> ) ? <Endline> 
PropertyField.Keyword   ::= 'let'
                          | 'var'
                          | 'class' <Whitespace> 'var'
                          | 'static' <Whitespace> 'let'
                          | 'static' <Whitespace> 'var'
  
Accessors               ::= '{' <Whitespace> ? 'get' 
                            ( ( <Whitespace> 'nonmutating' ) ? <Whitespace> 'set' ) ? <Whitespace> ? '}'

AssociatedtypeField     ::= 'associatedtype' <Whitespace> <Identifiers> 
                            ( <Whitespace> ? '=' <Whitespace> ? <Type> ) ? <Endline>
                            
TypealiasField          ::= 'typealias' <Whitespace> <Identifiers> <TypeParameters> ?
                            <Whitespace> ? '=' <Whitespace> ? <Type> <Endline>

TypeField               ::= <TypeField.Keyword> <Whitespace> <Identifiers> <TypeParameters> ? <Endline>
TypeField.Keyword       ::= 'protocol'
                          | 'class'
                          | 'struct'
                          | 'enum'
                          | 'extension'

ConformanceField        ::= ':' <Whitespace> ? <ProtocolCompositionType> 
                            ( <Whitespace> <WhereClauses> ) ? <Endline>

ImplementationField     ::= '?:' <Whitespace> ? <ProtocolCompositionType> 
                            ( <Whitespace> <WhereClauses> ) ? <Endline>
                          | '?' <Whitespace> ? <WhereClauses> <Endline>

ConstraintsField        ::= <WhereClauses> <Endline>
WhereClauses            ::= 'where' <Whitespace> <WhereClause> 
                            ( <Whitespace> ? ',' <Whitespace> ? <WhereClause> ) * 
WhereClause             ::= <Identifiers> <Whitespace> ? <WherePredicate>
WherePredicate          ::= ':' <Whitespace> ? <ProtocolCompositionType> 
                          | '==' <Whitespace> ? <Type>

AttributeField          ::= '@' <Whitespace> ? <DeclarationAttribute> <Endline>
DeclarationAttribute    ::= 'frozen'
                          | 'inlinable'
                          | 'discardableResult'
                          | 'resultBuilder'
                          | 'propertyWrapper'
                          | 'specialized' <Whitespace> <WhereClauses>
                          | ':'  <Whitespace> ? <Type>

ParameterField          ::= '-' <Whitespace> ? <ParameterName> <Whitespace> ? 
                            ':' <Whitespace> ? <FunctionParameter> <Endline>
ParameterName           ::= <Identifier> 
                          | '->'

DispatchField           ::= <DispatchField.Keyword> ( <Whitespace> <DispatchField.Keyword> ) * <Endline>

RequirementField        ::= 'required' <Endline>
                          | 'defaulted' ( <Whitespace> <WhereClauses> ) ? <Endline>

TopicKey                ::= [a-zA-Z0-9\-] *
TopicField              ::= '#' <Whitespace> ? '[' <BalancedToken> * ']' <Whitespace> ? 
                            '(' <Whitespace> ? <TopicKey> 
                            ( <Whitespace> ? ',' <Whitespace> ? <TopicKey> ) * <Whitespace> ? ')' <Endline>

TopicMembershipField    ::= '#' <Whitespace> ? '(' <Whitespace> ? 
                            ( <Integer Literal> <Whitespace> ? ':' <Whitespace> ? ) ? 
                            <TopicKey> <Whitespace> ? ')' <Endline>

ParagraphField          ::= <ParagraphLine> <ParagraphLine> *
ParagraphLine           ::= '    ' ' ' * [^\s] . * '\n'

Field                   ::= <FrameworkField>
                          | <AssociatedtypeField>
                          | <AttributeField>
                          | <ConformanceField>
                          | <ConstraintsField>
                          | <DispatchField>
                          | <ImplementationField>
                          | <FunctionField>
                          | <LexemeField>
                          | <ParameterField>
                          | <PropertyField>
                          | <RequirementField>
                          | <SubscriptField>
                          | <TopicField>
                          | <TopicMembershipField>
                          | <TypealiasField>
                          | <TypeField>
                          | <ParagraphField>
                          | <Separator>
Separator               ::= <Endline>
Separator               ::= <Endline>

Type                    ::= <UnwrappedType> '?' *
UnwrappedType           ::= <NamedType>
                          | <CompoundType>
                          | <FunctionType>
                          | <CollectionType>
                          | <ProtocolCompositionType>
NamedType               ::= <TypeIdentifier> ( '.' <TypeIdentifier> ) *
TypeIdentifier          ::= <Identifier> <TypeArguments> ?
TypeArguments           ::= '<' <Whitespace> ? <Type> <Whitespace> ? ( ',' <Whitespace> ? <Type> <Whitespace> ? ) * '>'
CompoundType            ::= '(' <Whitespace> ? ( <LabeledType> <Whitespace> ? 
                            ( ',' <Whitespace> ? <LabeledType> <Whitespace> ? ) * ) ? ')'
LabeledType             ::= ( <Identifier> <Whitespace> ? ':' <Whitespace> ? ) ? <Type> 
FunctionType            ::= ( <Attribute> <Whitespace> ) * <FunctionParameters> <Whitespace> ? 
                            ( 'throws' <Whitespace> ? ) ? '->' <Whitespace> ? <Type>
FunctionParameters      ::= '(' <Whitespace> ? ( <FunctionParameter> <Whitespace> ? 
                            ( ',' <Whitespace> ? <FunctionParameter> <Whitespace> ? ) * ) ? ')'
FunctionParameter       ::= ( <Attribute> <Whitespace> ) ? ( 'inout' <Whitespace> ) ? 
                            <Type> ( <Whitespace> ? '...' ) ?
Attribute               ::= '@' <Identifier>
CollectionType          ::= '[' <Whitespace> ? <Type> <Whitespace> ? ( ':' <Whitespace> ? <Type> <Whitespace> ? ) ? ']'
ProtocolCompositionType ::= <Identifiers> ( <Whitespace> ? '&' <Whitespace> ? <Identifiers> ) *

BalancedToken           ::= [^\[\]\(\)\{\}]
                          | '(' <BalancedToken> * ')'
                          | '[' <BalancedToken> * ']'
                          | '{' <BalancedToken> * '}'
```

Paragraph fields have their own mini-markdown syntax and an abbreviated link syntax for local and standard-library symbols.

```
ParagraphGrammar.Token  ::= <ParagraphLink> 
                          | <ParagraphSymbolLink>
                          | <ParagraphSubscript>
                          | <ParagraphSuperscript>
                          | '***'
                          | '**'
                          | '*'
                          | .
ParagraphSubscript      ::= '~' [^~] * '~'
ParagraphSuperscript    ::= '^' [^\^] * '^'
ParagraphInlineType     ::= '[[`' <Type> '`]]'
ParagraphSymbolLink     ::= '[' <SymbolPath> <SymbolPath> * ( <Identifier> '`' ) * ']'
SymbolPath              ::= '`' ( '(' <Identifiers> ').' ) ? <SymbolTail> 
                            ( <Whitespace> ? '#' <Whitespace> ? 
                                '(' <Whitespace> ? <TopicKey> <Whitespace> ? ')' ) ?
                            '`'
SymbolTail              ::= <FunctionIdentifiers> ? '(' <SymbolLabel> * ')' 
                          | <Identifiers>         ? '[' <SymbolLabel> * ']'
                          | <Identifiers>
SymbolLabel             ::= <Identifier> '...' ? ':'
ParagraphLink           ::= '[' [^\]] * '](' [^\)] ')'
```

Some Swift language features aren’t supported yet (`weak` variables, `static` subscripts, etc).

## themes 

Right now there is only one theme available, `big-sur.css`. You can see a deployed example of it [here](https://kelvin13.github.io/jpeg/JPEG/). The Apple *San Francisco* font is proprietary, so it is not possible (nor would it be interesting) to emulate the Apple API reference theme. 
