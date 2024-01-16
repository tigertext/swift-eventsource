import Foundation

struct DataIter: IteratorProtocol {
    var data: Data
    var position: Data.Index { data.startIndex }

    mutating func next() -> UInt8? {
        data.popFirst()
    }
}

@objcMembers public class UTF8LineParser: NSObject {
    private let lf = Unicode.Scalar(0x0A)
    private let cr = Unicode.Scalar(0x0D)
    private let replacement = String(Unicode.UTF8.decode(Unicode.UTF8.encodedReplacementCharacter))
    private let queue = DispatchQueue(label: "UTF8LineParser.private-queue", attributes: .concurrent)
    private var _remainder: Data = Data()
    private var _currentString: String = ""
    private var _seenCr = false
    
    var utf8Parser = Unicode.UTF8.ForwardParser()
    var seenCr: Bool {
        get {
            var seenCr = false
            queue.sync {
                seenCr = _seenCr
            }
            return seenCr
        } set {
            queue.async(flags: .barrier) {
                _seenCr = newValue
            }
        }
    }

    var currentString: String {
        get {
            var currentString = ""
            queue.sync { 
                currentString = _currentString
            }
            return currentString
        } set {
            queue.async(flags: .barrier) {
                _currentString = newValue
            }
        }
    }
    
    var remainder: Data {
        get {
            var remainder = Data()
            queue.sync { 
                remainder = _remainder
            }
            return remainder
        } set {
            queue.async(flags: .barrier) {
                _remainder = newValue
            }
        }
    }

    public func append(_ body: Data) -> [String] {
        let data = remainder + body
        var dataIter = DataIter(data: data)
        var remainderPos = data.endIndex
        var lines: [String] = []

        Decode: while true {
            switch utf8Parser.parseScalar(from: &dataIter) {
            case .valid(let scalarResult):
                let scalar = Unicode.UTF8.decode(scalarResult)

                if seenCr && scalar == lf {
                    seenCr = false
                    continue
                }

                seenCr = scalar == cr
                if scalar == cr || scalar == lf {
                    lines.append(currentString)
                    currentString = ""
                } else {
                    currentString.append(String(scalar))
                }
            case .emptyInput:
                break Decode
            case .error(let len):
                seenCr = false
                if dataIter.position == data.endIndex {
                    // Error at end of block, carry over in case of split code point
                    remainderPos = data.index(data.endIndex, offsetBy: -len)
                    // May as well break here as next will be .emptyInput
                    break Decode
                } else {
                    // Invalid character, replace with replacement character
                    currentString.append(replacement)
                }
            }
        }

        remainder = data.subdata(in: remainderPos..<data.endIndex)
        return lines
    }

    public func closeAndReset() {
        seenCr = false
        currentString = ""
        remainder = Data()
    }
}
