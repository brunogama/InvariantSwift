struct Config {
  let timeout: Int
  let retries: Int?
  let enabled: Bool

    public static var arbitrary: Gen<Config> {
        Gen.zip(Gen<Int>.int, Gen.optional(Gen<Int>.int), Gen<Bool>.bool).map {
            Config(timeout: $0, retries: $1, enabled: $2)
        }
    }

    public static var shrink: Shrink<Config> {
        Shrink { value in
            var results: [Config] = []
            for shrunkTimeout in Gen<Int>.int.shrink.shrink(value.timeout) {
                results.append(Config(timeout: shrunkTimeout, retries: value.retries, enabled: value.enabled))
            }
            for shrunkRetries in Gen.optional(Gen<Int>.int).shrink.shrink(value.retries) {
                results.append(Config(timeout: value.timeout, retries: shrunkRetries, enabled: value.enabled))
            }
            for shrunkEnabled in Gen<Bool>.bool.shrink.shrink(value.enabled) {
                results.append(Config(timeout: value.timeout, retries: value.retries, enabled: shrunkEnabled))
            }
            return results
        }
    }
}

extension Config: Generatable {
}
