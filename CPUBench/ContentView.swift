import SwiftUI
import UIKit

let STAGE1_K: UInt32 = 0x44CC29

@_optimize(none)
func stage1Count(_ iters: Int) -> Int {
    var c = 0
    for n in 1...iters {
        if ((Int(STAGE1_K) % n) * 11) % n == 0 {
            c += 1
        }
    }
    return c
}

@_optimize(none)
func stage2Run(_ iters: Int) -> Int {
    var acc = 0
    for i in 1...iters {
        acc = (acc &+ (i * 7)) & 0x7FFFFFFF
    }
    return acc
}

@_optimize(none)
func stage3Run(_ iters: Int) -> UInt64 {
    var acc: UInt64 = 1
    for i in 1...iters {
        acc = (acc &* UInt64(i | 1)) & 0xFFFFFFFF
    }
    return acc
}

@_optimize(none)
func stage4Run(_ iters: Int) -> Int {
    var acc = 0
    for i in 1...iters {
        acc = (acc &+ (1000000 / max(i, 1))) & 0x7FFFFFFF
    }
    return acc
}

@inline(never)
func runBenchmark() -> String {
    var results: [[String: Any]] = []

    for round in 1...4 {
        let t0 = CACurrentMediaTime()

        let s1r = stage1Count(29000)
        let t1 = CACurrentMediaTime()
        let s1us = Int((t1 - t0) * 1_000_000)

        let s2r = stage2Run(41000)
        let t2 = CACurrentMediaTime()
        let s2us = Int((t2 - t1) * 1_000_000)

        let s3r = stage3Run(31400)
        let t3 = CACurrentMediaTime()
        let s3us = Int((t3 - t2) * 1_000_000)

        let s4r = stage4Run(5900)
        let t4 = CACurrentMediaTime()
        let s4us = Int((t4 - t3) * 1_000_000)

        let totalUs = Int((t4 - t0) * 1_000_000)

        results.append([
            "round": round,
            "s1": ["result": s1r, "us": s1us],
            "s2": ["result": s2r, "us": s2us],
            "s3": ["result": Int(s3r), "us": s3us],
            "s4": ["result": s4r, "us": s4us],
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
    let cpuCount = ProcessInfo.processInfo.activeProcessorCount

    let info: [String: Any] = [
        "machine": machine,
        "model": device.model,
        "systemVersion": device.systemVersion,
        "mem_bytes": mem,
        "cpu_count": cpuCount,
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

    var body: some View {
        ScrollView {
            Text(resultText)
                .font(.system(size: 11, design: .monospaced))
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
