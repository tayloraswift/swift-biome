import HTML 

protocol HTMLConvertible<RenderedHTML>
{
    associatedtype RenderedHTML:Collection<HTML.Element<Never>>

    var html:RenderedHTML { get }
}