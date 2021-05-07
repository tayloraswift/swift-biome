# entrapta 

*Entrapta* is an experimental tool to generate richly-linked, Apple-style API reference websites for Swift projects which can be deployed with Github Pages. 

## usage 

```bash
# build a deployable website 
entrapta sources/*.swift 
    --directory     "directory/to/build/website/in" 
    # no trailing slash... the world has progressed past the need for trailing slashes
    --url-prefix    "https://adora.github.io/repository-name" 
    --github        "https://github.com/adora/repository-name"
    --project       "HTML Title to Display"

# build a local website 
entrapta sources/*.swift 
    --directory     "directory/to/build/website/in" 
    # url-prefix must be an absolute path
    --url-prefix    "$PWD/directory/to/build/website/in"
    --url-suffix    "/index.html" 
    --github        "https://github.com/adora/repository-name"
    --project       "HTML Title to Display"
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
Identifier              ::= <Swift Identifier Head> <Swift Identifier Character> *
EncapsulatedOperator    ::= '(' <Swift Operator Head> <Swift Operator Character> * ')'

ModuleField             ::= <ModuleField.Keyword> <Whitespace> <Identifier> <Endline>
ModuleField.Keyword     ::= 'module'
                          | 'plugin'

FunctionField           ::= <FunctionField.Keyword> <Whitespace> <Identifiers> <TypeParameters> ? '?' ? 
                            '(' ( <FunctionField.Label> ':' ) * ')' <Endline>
                          | 'case' <Whitespace> <Identifiers> <Endline>
FunctionField.Keyword   ::= 'init'
                          | 'func'
                          | 'mutating' <Whitespace> 'func'
                          | 'static' <Whitespace> 'func'
                          | 'case' 
                          | 'indirect' <Whitespace> 'case' 
FunctionField.Label     ::= <Identifier> 
                          | <Identifier> ? '...'
Identifiers             ::= <Identifier> ( '.' <Identifier> ) * ( '.' <EncapsulatedOperator> ) ?

TypeParameters          ::= '<' <Whitespace> ? 
                            <Identifier> <Whitespace> ? ( ',' <Whitespace> ? <Identifier> <Whitespace> ? ) * 
                            '>'

SubscriptField          ::= 'subscript' <Whitespace> <Identifiers> '[' ( <Identifier> ':' ) * ']' 
                            <Whitespace> ? <MemberMutability> <Endline> 

MemberField             ::= <MemberField.Keyword> <Whitespace> <Identifiers> 
                            ( <Whitespace> ? ':' <Whitespace> ? <Type> ) ? 
                            ( <Whitespace> ? <MemberMutability> ) ? <Endline> 
MemberField.Keyword     ::= 'let'
                          | 'var'
                          | 'static' <Whitespace> 'let'
                          | 'static' <Whitespace> 'var'
                          | 'associatedtype'
MemberMutability        ::= '{' <Whitespace> ? 'get' 
                            ( ( <Whitespace> 'nonmutating' ) ? <Whitespace> 'set' ) ? <Whitespace> ? 
                            '}'

TypeField               ::= <TypeField.Keyword> <Whitespace> <Identifiers> <TypeParameters> ? 
                            ( <Whitespace> ? '=' <Whitespace> ? <Type> ) ? <Endline>
TypeField.Keyword       ::= 'protocol'
                          | 'class'
                          | 'struct'
                          | 'enum'
                          | 'typealias'
  
Type                ::= <UnwrappedType> '?' *
UnwrappedType       ::= <NamedType>
                      | <CompoundType>
                      | <FunctionType>
                      | <CollectionType>
                      | <ProtocolCompositionType>
NamedType           ::= <TypeIdentifier> ( '.' <TypeIdentifier> ) *
TypeIdentifier      ::= <Identifier> <TypeArguments> ?
TypeArguments       ::= '<' <Whitespace> ? <Type> <Whitespace> ? ( ',' <Whitespace> ? <Type> <Whitespace> ? ) * '>'
CompoundType        ::= '(' <Whitespace> ? ( <LabeledType> <Whitespace> ? 
                        ( ',' <Whitespace> ? <LabeledType> <Whitespace> ? ) * ) ? ')'
LabeledType         ::= ( <Identifier> <Whitespace> ? ':' <Whitespace> ? ) ? <Type> 
FunctionType        ::= ( <Attribute> <Whitespace> ) * <FunctionParameters> <Whitespace> ? 
                        ( 'throws' <Whitespace> ? ) ? '->' <Whitespace> ? <Type>
FunctionParameters  ::= '(' <Whitespace> ? ( <FunctionParameter> <Whitespace> ? 
                        ( ',' <Whitespace> ? <FunctionParameter> <Whitespace> ? ) * ) ? ')'
FunctionParameter   ::= ( <Attribute> <Whitespace> ) ? ( 'inout' <Whitespace> ) ? <Type>
Attribute           ::= '@' <Identifier>
CollectionType      ::= '[' <Whitespace> ? <Type> <Whitespace> ? ( ':' <Whitespace> ? <Type> <Whitespace> ? ) ? ']'
ProtocolCompositionType ::= <Identifiers> ( <Whitespace> ? '&' <Whitespace> ? <Identifiers> ) *




ConformanceField    ::= ':' <Whitespace> ? <ProtocolCompositionType> ( <Whitespace> <WhereClauses> ) ? <Endline>

ImplementationField ::= '?:' <Whitespace> ? <Identifiers> ( <Whitespace> <WhereClauses> ) ? <Endline>

ConstraintsField    ::= <WhereClauses> <Endline>
WhereClauses        ::= 'where' <Whitespace> <WhereClause> ( <Whitespace> ? ',' <Whitespace> ? <WhereClause> ) * 
WhereClause         ::= <Identifiers> <Whitespace> ? <WherePredicate>
WherePredicate      ::= ':' <Whitespace> ? <ProtocolCompositionType> 
                      | '==' <Whitespace> ? <Type>

AttributeField      ::= '@' <Whitespace> ? <DeclarationAttribute> <Endline>
DeclarationAttribute::= 'frozen'
                      | 'inlinable'
                      | 'propertyWrapper'
                      | 'specialized' <Whitespace> <WhereClauses>
                      | ':'  <Whitespace> ? <Type>

ParameterField      ::= '-' <Whitespace> ? <ParameterName> <Whitespace> ? ':' <Whitespace> ? 
                        <FunctionParameter> <Endline>
ParameterName       ::= <Identifier> 
                      | '->'
                      
ThrowsField         ::= 'throws' <Endline>
                      | 'rethrows' <Endline>
                      
RequirementField    ::= 'required' <Endline>
                      | 'defaulted' ( <Whitespace> <WhereClauses> ) ? <Endline>

TopicKey            ::= [a-zA-Z0-9\-] *
TopicField          ::= '#' <Whitespace>? '[' <BalancedContent> * ']' <Whitespace>? 
                        '(' <Whitespace> ? <TopicKey> 
                        ( <Whitespace> ? ',' <Whitespace> ? <TopicKey> ) * <Whitespace> ? ')' <Endline>
TopicElementField   ::= '##' <Whitespace>? '(' <Whitespace> ? 
                        ( <ASCIIDigit> * <Whitespace> ? ':' <Whitespace> ? ) ? <TopicKey> <Whitespace> ? ')' <Endline>

ParagraphField      ::= <ParagraphLine> <ParagraphLine> *
ParagraphLine       ::= '    ' ' ' * [^\s] . * '\n'

Field               ::= <ModuleField>
                      | <FunctionField>
                      | <SubscriptField>
                      | <MemberField>
                      | <TypeField>
                      | <TypealiasField>
                      | <AnnotationField>
                      | <AttributeField>
                      | <ConstraintsField>
                      | <ThrowsField>
                      | <RequirementField>
                      | <ParameterField>
                      | <TopicField>
                      | <TopicElementField>
                      | <ParagraphField>
                      | <Separator>
Separator           ::= <Endline>
```

Paragraph fields have their own mini-markdown syntax and an abbreviated link syntax for local and standard-library symbols.

```
ParagraphToken          ::= <ParagraphLink> 
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
SymbolPath              ::= '`' ( '(' <Identifiers> ').' ) ? <SymbolTail> '`'
SymbolTail              ::= <Identifiers> ? '[' ( <FunctionLabel> ':' ) * ']'
                          | <Identifiers> ( '(' ( <FunctionLabel> ':' ) * ')' ) ?
ParagraphLink           ::= '[' [^\]] * '](' [^\)] ')'
```

Some Swift language features aren’t supported yet (`weak` variables, `static` subscripts, etc).

## themes 

Right now there is only one theme available, `big-sur.css`. You can see a deployed example of it [here](https://kelvin13.github.io/jpeg/JPEG/). The Apple *San Francisco* font is proprietary, so it is not possible (nor would it be interesting) to emulate the Apple API reference theme. 
