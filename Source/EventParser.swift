import Foundation

@objcMembers public class EventParser: NSObject {
    private struct Constants {
        static let dataLabel: Substring = "data"
        static let idLabel: Substring = "id"
        static let eventLabel: Substring = "event"
        static let retryLabel: Substring = "retry"
    }

    private weak var handler: EventHandler?
    // Concurrent queue
    private let queue = DispatchQueue(label: "EventParser.private-queue", attributes: .concurrent)
    private var _data: String = ""
    private var _eventType: String = ""
    private var _lastEventIdBuffer: String?
    private var _lastEventId: String
    private var _currentRetry: TimeInterval

    private var data: String {
        get {
            var data = ""
            queue.sync { 
                data = _data
            }
            return data
        } set {
            queue.async(flags: .barrier) {
                _data = newValue
            }
        }
    }

    private var eventType: String {
        get {
            var eventType = ""
            queue.sync { 
                eventType = _eventType
            }
            return eventType
        } set {
            queue.async(flags: .barrier) {
                _eventType = newValue
            }
        }
    }
    
    private var lastEventIdBuffer: String? {
        get {
            var lastEventIdBuffer = String?.none
            queue.sync { 
                lastEventIdBuffer = _lastEventIdBuffer
            }
            return lastEventId
        } set {
            queue.async(flags: .barrier) {
                _lastEventIdBuffer = newValue
            }
        }
    }

    private var lastEventId: String {
        get {
            var lastEventId = ""
            queue.sync { 
                lastEventId = _lastEventId
            }
            return lastEventId
        } set {
            queue.async(flags: .barrier) {
                _lastEventId = newValue
            }
        }
    }
    
    private var currentRetry: TimeInterval {
        get {
            var currentRetry = TimeInterval()
            queue.sync { 
                currentRetry = _currentRetry
            }
            return currentRetry
        } set {
            queue.async(flags: .barrier) {
                _currentRetry = newValue
            }
        }
    }

    public init(handler: EventHandler, initialEventId: String, initialRetry: TimeInterval) {
        self.handler = handler
        self._lastEventId = initialEventId
        self._currentRetry = initialRetry
    }

    public func parse(line: String) {
        let splitByColon = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)

        switch (splitByColon[0], splitByColon[safe: 1]) {
        case ("", nil): // Empty line
            dispatchEvent()
        case let ("", .some(comment)): // Line starting with ':' is a comment
            handler?.onComment(comment: String(comment))
        case let (field, data):
            processField(field: field, value: dropLeadingSpace(str: data ?? ""))
        }
    }

    public func getLastEventId() -> String { lastEventId }

    @discardableResult public func reset() -> TimeInterval {
        data = ""
        eventType = ""
        lastEventIdBuffer = nil
        return currentRetry
    }

    private func dropLeadingSpace(str: Substring) -> Substring {
        if str.first == " " {
            return str[str.index(after: str.startIndex)...]
        }
        return str
    }

    private func processField(field: Substring, value: Substring) {
        switch field {
        case Constants.dataLabel:
            data.append(contentsOf: value)
            data.append(contentsOf: "\n")
        case Constants.idLabel:
            // See https://github.com/whatwg/html/issues/689 for reasoning on not setting lastEventId if the value
            // contains a null code point.
            if !value.contains("\u{0000}") {
                lastEventIdBuffer = String(value)
            }
        case Constants.eventLabel:
            eventType = String(value)
        case Constants.retryLabel:
            if value.allSatisfy(("0"..."9").contains), let reconnectionTime = Int64(value) {
                currentRetry = Double(reconnectionTime) * 0.001
            }
        default:
            break
        }
    }

    private func dispatchEvent() {
        lastEventId = lastEventIdBuffer ?? lastEventId
        lastEventIdBuffer = nil
        guard !data.isEmpty
        else {
            eventType = ""
            return
        }
        // remove the last LF
        _ = data.popLast()
        let messageEvent = MessageEvent(data: data, lastEventId: lastEventId)
        handler?.onMessage(eventType: eventType.isEmpty ? "message" : eventType, messageEvent: messageEvent)
        data = ""
        eventType = ""
    }
}

private extension Array {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        index >= startIndex && index < endIndex ? self[index] : nil
    }
}
