struct User {
  let name: String
  let age: Int

    public static var arbitrary: Gen<User> {
        Gen.zip(Gen<String>.string, Gen<Int>.int).map {
            User(name: $0, age: $1)
        }
    }

    public static var shrink: Shrink<User> {
        Shrink { value in
            var results: [User] = []
            for shrunkName in Gen<String>.string.shrink.shrink(value.name) {
                results.append(User(name: shrunkName, age: value.age))
            }
            for shrunkAge in Gen<Int>.int.shrink.shrink(value.age) {
                results.append(User(name: value.name, age: shrunkAge))
            }
            return results
        }
    }
}

extension User: Generatable {
}
