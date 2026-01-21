struct Config {
  let timeout: Int
  let retries: Int?
  let enabled: Bool

  static var arbitrary: Gen<Self> {
    Gen.zip(Gen<Int>.int, Gen.optional(Gen<Int>.int), Gen<Bool>.bool).map {
      Self(timeout: $0, retries: $1, enabled: $2)
    }
  }

  static var shrink: Shrink<Self> {
    Shrink { value in
      var results: [Self] = []
      for shrunkTimeout in Gen<Int>.int.shrink.shrink(value.timeout) {
        results.append(
          Self(timeout: shrunkTimeout, retries: value.retries, enabled: value.enabled)
        )
      }
      for shrunkRetries in Gen.optional(Gen<Int>.int).shrink.shrink(value.retries) {
        results.append(
          Self(timeout: value.timeout, retries: shrunkRetries, enabled: value.enabled)
        )
      }
      for shrunkEnabled in Gen<Bool>.bool.shrink.shrink(value.enabled) {
        results.append(
          Self(timeout: value.timeout, retries: value.retries, enabled: shrunkEnabled)
        )
      }
      return results
    }
  }
}

extension Config: Generatable {
}
