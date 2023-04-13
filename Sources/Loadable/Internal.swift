@_spi(Reflection) import CasePaths

// Taken from TCA
struct StableID: Hashable, Identifiable, Sendable {
  private let identifier: AnyHashableSendable?
  private let tag: UInt32?
  private let type: Any.Type

  init<Base>(base: Base) {
    self.tag = EnumMetadata(Base.self)?.tag(of: base)
    if let id = _identifiableID(base) ?? EnumMetadata.project(base).flatMap(_identifiableID) {
      self.identifier = AnyHashableSendable(id)
    } else {
      self.identifier = nil
    }
    self.type = Base.self
  }

  var id: Self { self }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.identifier == rhs.identifier
    && lhs.tag == rhs.tag
    && lhs.type == rhs.type
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(self.identifier)
    hasher.combine(self.tag)
    hasher.combine(ObjectIdentifier(self.type))
  }
}

// Taken from TCA
struct AnyHashableSendable: Hashable, @unchecked Sendable {
  let base: AnyHashable
  init<Base: Hashable & Sendable>(_ base: Base) {
    self.base = base
  }
}

func _identifiableID(_ value: Any) -> AnyHashable? {
  func open(_ value: some Identifiable) -> AnyHashable {
    value.id
  }
  guard let value = value as? any Identifiable else { return nil }
  return open(value)
}
