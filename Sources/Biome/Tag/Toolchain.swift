import Versions 

@frozen public 
enum Toolchain 
{
    case nightly(Date)
    case release(SemanticVersion.Masked)
}