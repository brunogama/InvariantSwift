enum Status {
  case active
  case inactive
  case pending

    public static var arbitrary: Gen<Status> {
        Gen.oneOf([Gen.pure(Status.active), Gen.pure(Status.inactive), Gen.pure(Status.pending)])
    }
}

extension Status: Generatable {
}
