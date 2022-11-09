// import NIOCore

// struct ByteBufferVector
// {
//     var buffer:ByteBuffer
// }
// extension ByteBufferVector:RandomAccessCollection
// {
//     var startIndex:Int
//     {
//         self.buffer.readerIndex
//     }
//     var endIndex:Int
//     {
//         self.buffer.writerIndex
//     }
//     subscript(index:Int) -> UInt8
//     {
//         if let byte:UInt8 = self.buffer.getInteger(at: position, as: UInt8.self)
//         {
//             return byte
//         }
//         else
//         {
//             fatalError("index out of range")
//         }
//     }
// }
// extension ByteBufferVector:RangeReplaceableCollection
// {
//     @inlinable public
//     init()
//     {
//         self.buffer = .init()
//     }
//     @inlinable public
//     init(preallocated:ByteBuffer)
//     {
//         self.buffer = preallocated
//     }

//     @inlinable public mutating
//     func reserveCapacity(_ capacity:Int) 
//     {
//         self.buffer.reserveCapacity(capacity)
//     }

//     @inlinable public mutating
//     func replaceSubrange<C: Collection>(_ subrange: Range<Index>, with newElements: C)
//         where ByteBufferView.Element == C.Element
//     {
//         precondition(subrange.startIndex >= self.startIndex && subrange.endIndex <= self.endIndex,
//             "subrange out of bounds")

//         if newElements.count == subrange.count 
//         {
//             self._buffer.setBytes(newElements, at: subrange.startIndex)
//         }
//         else if newElements.count < subrange.count {
//             // Replace the subrange.
//             self._buffer.setBytes(newElements, at: subrange.startIndex)

//             // Remove the unwanted bytes between the newly copied bytes and the end of the subrange.
//             // try! is fine here: the copied range is within the view and the length can't be negative.
//             try! self._buffer.copyBytes(at: subrange.endIndex,
//                                         to: subrange.startIndex.advanced(by: newElements.count),
//                                         length: subrange.endIndex.distance(to: self._buffer.writerIndex))

//             // Shorten the range.
//             let removedBytes = subrange.count - newElements.count
//             self._buffer.moveWriterIndex(to: self._buffer.writerIndex - removedBytes)
//             self._range = self._range.dropLast(removedBytes)
//         } else {
//             // Make space for the new elements.
//             // try! is fine here: the copied range is within the view and the length can't be negative.
//             try! self._buffer.copyBytes(at: subrange.endIndex,
//                                         to: subrange.startIndex.advanced(by: newElements.count),
//                                         length: subrange.endIndex.distance(to: self._buffer.writerIndex))

//             // Replace the bytes.
//             self._buffer.setBytes(newElements, at: subrange.startIndex)

//             // Widen the range.
//             let additionalByteCount = newElements.count - subrange.count
//             self._buffer.moveWriterIndex(forwardBy: additionalByteCount)
//             self._range = self._range.startIndex ..< self._range.endIndex.advanced(by: additionalByteCount)

//         }
//     }
// }
