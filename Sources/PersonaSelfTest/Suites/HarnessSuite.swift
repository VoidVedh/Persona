import Foundation

public enum HarnessSuite {
    public static func run(_ t: Harness) {
        t.suite("harness") {
            t.expect(1 + 1 == 2, "basic addition")
            t.expectEqual("persona", "persona", "string equality")
            t.expectThrows("expected throwing block") {
                struct SampleError: Error {}
                throw SampleError()
            }
            if ProcessInfo.processInfo.environment["SELFTEST_FORCE_FAIL"] == "1" {
                t.expect(false, "forced failure for selftest verification")
            }
        }
    }
}
