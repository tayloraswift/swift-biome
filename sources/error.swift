extension Entrapta 
{
    enum Error:Swift.Error 
    {
        case extensionTargetDoesNotExist 
        case extensionTargetIsLeafNode(LeafNode)
        
        case cannotOverloadLeafNode(LeafNode)
        case cannotOverloadInternalNode(InternalNode)
        
        case ancestorNodeDoesNotExist
        case ancestorNodeIsLeafNode(LeafNode)
        
        case other(message:String, help:String?)
        
        init(_ message:String, help:String? = nil) 
        {
            self = .other(message: message, help: help)
        }
    }
}
extension Entrapta.Error:CustomStringConvertible 
{
    var description:String 
    {
        switch self 
        {
        case .extensionTargetDoesNotExist: 
            return "the extension target does not exist"
        case .extensionTargetIsLeafNode(let leaf):
            return "the extension target is a leaf node (containing \(leaf.pages.map(\.kind)))"
        
        case .cannotOverloadLeafNode(let leaf):
            return "its path points to a leaf node (containing \(leaf.pages.map(\.kind))), which can only be overloaded with subscripts, functions, or properties"
        case .cannotOverloadInternalNode(let node): 
            return "its path points to an internal node (containing \(node.page.kind)), which cannot be overloaded"
        
        case .ancestorNodeDoesNotExist:
            return "its ancestor node does not exist"
        case .ancestorNodeIsLeafNode(let leaf):
            return "its ancestor node is a leaf node (containing \(leaf.pages.map(\.kind)))"
        
        case .other(message: let message, help: let help):
            return "error: \(message)\(help.map{ "\nnote: \($0)" } ?? "")"
        }
    }
}
