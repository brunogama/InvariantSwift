## 1. Documentation
- [ ] 1.1 Update openspec/specs/pbt-plugins/spec.md notes to state current permissions and the policy
- [ ] 1.2 Add a short paragraph to README (or a dedicated SECURITY.md) explaining plugin permission expectations

## 2. Policy guard (CI optional)
- [ ] 2.1 Add a simple script that fails CI if `allowNetworkConnections` appears in Package.swift (unless an explicit opt-in flag is set)
- [ ] 2.2 Wire into CI as a non-blocking job first

## 3. Repo hygiene
- [ ] 3.1 Ensure .gitignore excludes `.DS_Store`, `__MACOSX`, and AppleDouble files
