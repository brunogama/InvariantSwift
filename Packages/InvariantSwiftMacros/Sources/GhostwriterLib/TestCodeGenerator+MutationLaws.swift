import InvariantSwiftExpansionSupport

extension PatternDefinitions {
  static let optionSetMembershipMutation = PatternDefinition.body(
    "OptionSet insertion and removal preserve membership semantics.",
    parameters: ["set", "element"]
  ) { _ in
    [
      .ifStatement(
        condition: not(member("element", "isEmpty")),
        body: [
          binding(
            "wasMember",
            id("set").method("contains", arguments: [.unlabeled(id("element"))])
          ),
          .varBinding(name: "modified", initializer: id("set")),
          binding(
            "insertion",
            id("modified").method("insert", arguments: [.unlabeled(id("element"))])
          ),
          expect(
            id("modified").method("contains", arguments: [.unlabeled(id("element"))]),
            "Inserted element must be a member"
          ),
          expect(
            binary(member("insertion", "inserted"), "==", not(id("wasMember"))),
            "inserted must report whether the element was absent"
          ),
          binding(
            "removed",
            id("modified").method("remove", arguments: [.unlabeled(id("element"))])
          ),
          expect(binary(id("removed"), "!=", id("nil")), "Removal must find inserted element"),
          expect(
            not(id("modified").method("contains", arguments: [.unlabeled(id("element"))])),
            "Removed element must no longer be a member"
          ),
        ]
      )
    ]
  }
}
