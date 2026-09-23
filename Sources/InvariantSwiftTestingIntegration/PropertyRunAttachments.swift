import Testing

/// Records a Swift Testing attachment where the toolchain provides them.
///
/// `Testing.Attachment` arrived in Swift 6.2. Calling it unconditionally meant this
/// library did not compile at all on anything older, with "module 'Testing' has no
/// member named 'Attachment'" at every call site. That is not hypothetical: the CI
/// runners resolve `swift` to 6.1, so any package depending on this one failed to
/// build there.
///
/// Older compilers get no attachments, which is the feature being unavailable rather
/// than anything going wrong, and everything else about the run is unchanged.
func recordAttachment(
  _ value: String,
  named name: String,
  location: Testing.SourceLocation
) {
  #if compiler(>=6.2)
  Testing.Attachment.record(value, named: name, sourceLocation: location)
  #else
  _ = (value, name, location)
  #endif
}
