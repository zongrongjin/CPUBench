import SwiftUI
import UIKit

// Akamai BMP SDK -112 benchmark replica
// Prevent compiler from optimizing away loops

@inline(never)
func blackhole<T>(_ x: T) {
    withExtendedLifetime(x) {}
}

let STAGE1_K: UInt32 = 0x44CC29

@inline(never)
func stage1Count(_ iters: Int) -> Int {
    var c = 0
    for n in 1...iters {
        if ((Int(STAGE1_K) % n) * 11) % n == 0 {
            c += 1
        }
    }
    blackhole(c)
    return c
}

@inline(never)
func stage2Run(_ iters: Int) -> Int {
    var acc = 0
    for i in 1...iters {
        acc = (acc &+ (i * 7)) & 0x7FFFFFFF
    }
    blackhole(acc)
    return acc
}

@inline(never)
func stage3Run(_ iters: Int) -> UInt64 {
    var acc: UInt64 = 1
    for i in 1...iters {
        acc = (acc &* UInt64(i | 1)) & 0xFFFFFFFF
    }
    blackhole(acc)
    return acc
}

@inline(never)
func stage4Run(_ iters: Int) -> Int {
    var acc = 0
    for i in 1...iters {
        acc = (acc &+ (1000000 / max(i, 1))) & 0x7FFFFFFF
    }
    blackhole(acc)
    return acc
}

@inline(never)
func runAdaptiveBenchmark() -> String {
    var results: [[String: Any]] = []

    for round in 1...3 {
        let scale = Double(round)

        let t0 = CACurrentMediaTime()

        let s1n = Int(29000.0 * scale)
        let s1r = stage1Count(s1n)
        let t1 = CACurrentMediaTime()
        let s1us = Int((t1 - t0) * 1_000_000)

        let s2n = Int(41000.0 * scale)
        let _ = stage2Run(s2n)
        let t2 = CACurrentMediaTime()
        let s2us = Int((t2 - t1) * 1_000_000)

        let s3n = Int(31400.0 * scale)
        let _ = stage3Run(s3n)
        let t3 = CACurrentMediaTime()
        let s3us = Int((t3 - t2) * 1_000_000)

        let s4n = Int(5900.0 * scale)
        let _ = stage4Run(s4n)
        let t4 = CACurrentMediaTime()
        let s4us = Int((t4 - t3) * 1_000_000)

        let totalUs = Int((t4 - t0) * 1_000_000)

        results.append([
            "round": round,
            "scale": scale,
            "s1": ["n": s1n, "result": s1r, "us": s1us],
            "s2": ["n": s2n, "us": s2us],
            "s3": ["n": s3n, "us": s3us],
            "s4": ["n": s4n, "us": s4us],
            "total_us": totalUs
        ])
    }

    var sysinfo = utsname()
    uname(&sysinfo)
    let machine = withUnsafePointer(to: &sysinfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            String(cString: $0)
        }
    }

    let device = UIDevice.current
    let mem = ProcessInfo.processInfo.physicalMemory
    let cpuCount = ProcessInfo.processInfo.processorCount
    let activeCount = ProcessInfo.processInfo.activeProcessorCount

    let info: [String: Any] = [
        "machine": machine,
        "model": device.model,
        "systemVersion": device.systemVersion,
        "mem_bytes": mem,
        "cpu_count": cpuCount,
        "active_cpu": activeCount,
        "benchmarks": results
    ]

    if let jsonData = try? JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys]),
       let jsonStr = String(data: jsonData, encoding: .utf8) {
        return jsonStr
    }
    return "JSON encoding failed"
}

struct ContentView: View {
    @State private var resultText = "Running benchmark..."
    @State private var done = false

    var body: some View {
        ScrollView {
            Text(resultText)
                .font(.system(size: 11, design: .monospaced))
                .padding()
                .accessibilityIdentifier("benchResult")
        }
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                let r = runAdaptiveBenchmark()
                DispatchQueue.main.async {
                    resultText = r
                    done = true
                }
            }
        }
    }
}
