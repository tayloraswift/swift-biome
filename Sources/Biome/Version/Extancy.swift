enum Extancy
{
    case unavailable(until:Version)
    case extant
    case extinct(since:Version)
}
