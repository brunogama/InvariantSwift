struct User {
  let name: String
  let age: Int

  static var arbitrary: Gen<Self> {
    Gen.zip(Gen<String>.string, Gen<Int>.int).map {
      Self(name: $0, age: $1)
    }
  }

  static var shrink: Shrink<Self> {
    Shrink { value in
      var results: [Self] = []
      for shrunkName in Gen<String>.string.shrink.shrink(value.name) {
        results.append(Self(name: shrunkName, age: value.age))
      }
      for shrunkAge in Gen<Int>.int.shrink.shrink(value.age) {
        results.append(Self(name: value.name, age: shrunkAge))
      }
      return results
    }
  }
}

extension User: Generatable {
}
