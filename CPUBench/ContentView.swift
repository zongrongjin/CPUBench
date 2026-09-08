import SwiftUI
import UIKit
import Foundation

// Time-bounded benchmark: run each stage for 2ms, count iterations.
// Release compiler optimizes loop bodies but can't eliminate the loops
// because termination depends on CACurrentMediaTime() (runtime syscall).

@inline(never)
func stage1Timed() -> (Int, Int) {
    let K = 4508713 // 0x44CC29
    let deadline = CACurrentMediaTime() + 0.002
    var count = 0
    var n = 1
    while n <= 999999 {
        if n & 63 == 0 && CACurrentMediaTime() >= deadline { break }
        if ((K % n) * 11) % n == 0 { count += 1 }
        n += 1
    }
    return (count, n - 1)
}

@inline(never)
func stage2Timed() -> (Int, Int) {
    let deadline = CACurrentMediaTime() + 0.002
    var count = 0
    var n = 1
    while n <= 999999 {
        if n & 63 == 0 && CACurrentMediaTime() >= deadline { break }
        let d9 = 33.34 + Double(n) * Double(n + 1) / 2.0
        if d9 * 19.239 / 3.56 < 10000.0 { count += 1 }
        n += 1
    }
    return (count, n - 1)
}

@inline(never)
func stage3Timed() -> (Int, Int) {
    let deadline = CACurrentMediaTime() + 0.002
    var count = 0
    var n = 1
    while n <= 999999 {
        if n & 63 == 0 && CACurrentMediaTime() >= deadline { break }
        if sqrt(Double(n)) > 30.0 { count += 1 }
        n += 1
    }
    return (count, n - 1)
}

@inline(never)
func stage4Timed() -> (Int, Int) {
    let deadline = CACurrentMediaTime() + 0.002
    var count = 0
    var n = 1
    while n <= 999999 {
        if n & 63 == 0 && CACurrentMediaTime() >= deadline { break }
        let x = Double(n) / 1000000.0
        if acos(x) + asin(x) + atan(x) > 1.5 { count += 1 }
        n += 1
    }
    return (count, n - 1)
}

@inline(never)
func stage5Timed() -> Int {
    let deadline = CACurrentMediaTime() + 0.002
    var n = 1
    while n <= 999999 {
        if n & 63 == 0 && CACurrentMediaTime() >= deadline { break }
        n += 1
    }
    return n - 1
}

@inline(never)
func runBenchmark() -> String {
    var rounds: [[String: Any]] = []
    var field112: [String] = []

    for round in 1...4 {
        let (s1c, s1i) = stage1Timed()
        let (s2c, s2i) = stage2Timed()
        let (s3c, s3i) = stage3Timed()
        let (s4c, s4i) = stage4Timed()
        let s5i = stage5Timed()

        let f = "\(s1c),\(s1i/100),\(s2c),\(s2i/100),\(s3i-900),\(s3i/100),\(s4i),\(s4i/100),\(s5i)"
        field112.append(f)

        rounds.append([
            "round": round,
            "s1": ["count": s1c, "iters": s1i],
            "s2": ["count": s2c, "iters": s2i],
            "s3": ["count": s3c, "iters": s3i],
            "s4": ["count": s4c, "iters": s4i],
            "s5": ["iters": s5i],
        ])
    }

    var sysinfo = utsname()
    uname(&sysinfo)
    let machine = withUnsafePointer(to: &sysinfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            String(cString: $0)
        }
    }

    let info: [String: Any] = [
        "machine": machine,
        "model": UIDevice.current.model,
        "systemVersion": UIDevice.current.systemVersion,
        "cpu_count": ProcessInfo.processInfo.activeProcessorCount,
        "field_112": field112,
        "rounds": rounds
    ]

    if let jsonData = try? JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys]),
       let jsonStr = String(data: jsonData, encoding: .utf8) {
        return jsonStr
    }
    return "JSON encoding failed"
}

struct ContentView: View {
    @State private var resultText = "Running benchmark..."

    var body: some View {
        ScrollView {
            Text(resultText)
                .font(.system(size: 10, design: .monospaced))
                .padding()
                .accessibilityIdentifier("benchResult")
        }
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                let r = runBenchmark()
                DispatchQueue.main.async {
                    resultText = r
                }
            }
        }
    }
}
