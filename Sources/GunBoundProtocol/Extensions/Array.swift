public extension Array {

    mutating func popFirst() -> Element? {
        guard let first = self.first else { return nil }
        self.removeFirst()
        return first
    }
}
