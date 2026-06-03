import Foundation

public protocol DateProvider {
    func now() -> Date
}

public struct SystemDateProvider: DateProvider {
    public init() {}

    public func now() -> Date {
        Date()
    }
}

public struct FixedDateProvider: DateProvider {
    private let value: Date

    public init(now: Date) {
        self.value = now
    }

    public func now() -> Date {
        value
    }
}
