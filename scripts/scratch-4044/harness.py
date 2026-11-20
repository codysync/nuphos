# Scratch-only evidence harness for nuphos/nuphos#4044, applied identically to the before and after trees.
import sys
p = sys.argv[1] + '/apps/ios/nuphos-ios/Services/AuthSession.swift'
s = open(p).read()
a = 'import SwiftUI\n'
assert s.count(a) >= 1
s = s.replace(a, a + '#if os(iOS)\nimport ActivityKit\n#endif\n', 1)
b = '    func restore() async {\n'
assert s.count(b) == 1
s = s.replace(b, b + '''        #if DEBUG
        if CommandLine.arguments.contains("-shot-splash") { try? await Task.sleep(for: .seconds(600)) }
        #if os(iOS)
        if CommandLine.arguments.contains("-shot-activity") {
            let state = TurnActivityAttributes.ContentState(sessions: [
                .init(id: "s1", teamId: "t", title: "Ship the new onboarding", phase: .running),
                .init(id: "s2", teamId: "t", title: "Fix the flaky upload test", phase: .running),
            ], more: 0, active: 2)
            do {
                _ = try Activity.request(attributes: TurnActivityAttributes(), content: .init(state: state, staleDate: nil))
            } catch {
                print("shot-activity failed: \\(error)")
            }
        }
        #endif
        #endif
''', 1)
open(p, 'w').write(s)
print('harness applied to', p)
