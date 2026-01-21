enum Status {
  case active
  case inactive
  case pending

  static var arbitrary: Gen<Self> {
    Gen.oneOf([Gen.pure(Self.active), Gen.pure(Self.inactive), Gen.pure(Self.pending)])
  }
}

extension Status: Generatable {
}
