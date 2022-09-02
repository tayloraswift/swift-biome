enum Selection<Element>
{
    case one(Element)
    case many([Element])
}
extension Selection?
{
}