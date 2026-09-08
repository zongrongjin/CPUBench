import SwiftUI
import UIKit

// Akamai BMP SDK -112 benchmark replica
// 5 stages of CPU-bound loops, measuring iteration count and results

let STAGE1_K: UInt32 = 0x44CC29

func stage1Count(_ iters: Int) -> Int {
    var c = 0
    for n in 1...iters {
        if ((Int(STAGE1_K) % n) * 11) % n == 0 {
            c += 1
        }
    }
    return c
}

func runBenchmark() -> [Int] {
    // Stage 1: modular arithmetic loop
    let t0 = CACurrentMediaTime()
    let s1iters = 29000  // fixed iteration count (290 * 100)
    let s1result = stage1Count(s1iters)
    let t1 = CACurrentMediaTime()

    // Stage 2: similar loop, different count
    let s2iters = 41000  // 410 * 100
    var s2acc = 0
    for i in 1...s2iters {
        s2acc = (s2acc &+ (i * 7)) & 0x7FFFFFFF
    }
    let t2 = CACurrentMediaTime()

    // Stage 3: multiplication-heavy loop
    let s3iters = 31400  // 314 * 100
    var s3acc: UInt64 = 1
    for i in 1...s3iters {
        s3acc = (s3acc &* UInt64(i | 1)) & 0xFFFFFFFF
    }
    let t3 = CACurrentMediaTime()

    // Stage 4: division-heavy loop
    let s4iters = 5900   // 59 * 100
    var s4acc = 0
    for i in 1...s4iters {
        s4acc = (s4acc &+ (1000000 / max(i, 1))) & 0x7FFFFFFF
    }
    let t4 = CACurrentMediaTime()

    // Total elapsed ms
    let totalMs = Int((t4 - t0) * 1000)

    // Return in BMP -112 format:
    // [stage1_result, stage1_iters/100, 59, stage2_iters/100,
    //  stage3_iters*100-900, stage3_iters/100, stage4_iters, stage4_iters/100, totalMs]
    return [
        s1result,
        s1iters / 100,   // = 290
        59,               // constant
        s2iters / 100,    // = 410
        s3iters - 900,    // = 30500
        s3iters / 100,    // = 314
        s4iters,          // = 5900
        s4iters / 100,    // = 59
        totalMs
    ]
}

// Adaptive benchmark: run increasing iterations until we hit a target time
func runAdaptiveBenchmark() -> String {
    var results: [[String: Any]] = []

    // Run 3 rounds with increasing load to profile the device
    for round in 1...3 {
        let scale = Double(round)

        let t0 = CACurrentMediaTime()

        // Stage 1
        let s1n = Int(29000.0 * scale)
        let s1r = stage1Count(s1n)
        let t1 = CACurrentMediaTime()
        let s1ms = Int((t1 - t0) * 1000)

        // Stage 2
        let s2n = Int(41000.0 * scale)
        var s2acc = 0
        for i in 1...s2n {
            s2acc = (s2acc &+ (i * 7)) & 0x7FFFFFFF
        }
        let t2 = CACurrentMediaTime()
        let s2ms = Int((t2 - t1) * 1000)

        // Stage 3
        let s3n = Int(31400.0 * scale)
        var s3acc: UInt64 = 1
        for i in 1...s3n {
            s3acc = (s3acc &* UInt64(i | 1)) & 0xFFFFFFFF
        }
        let t3 = CACurrentMediaTime()
        let s3ms = Int((t3 - t2) * 1000)

        // Stage 4
        let s4n = Int(5900.0 * scale)
        var s4acc2 = 0
        for i in 1...s4n {
            s4acc2 = (s4acc2 &+ (1000000 / max(i, 1))) & 0x7FFFFFFF
        }
        let t4 = CACurrentMediaTime()
        let s4ms = Int((t4 - t3) * 1000)

        let totalMs = Int((t4 - t0) * 1000)

        results.append([
            "round": round,
            "scale": scale,
            "s1": ["n": s1n, "result": s1r, "ms": s1ms],
            "s2": ["n": s2n, "ms": s2ms],
            "s3": ["n": s3n, "ms": s3ms],
            "s4": ["n": s4n, "ms": s4ms],
            "total_ms": totalMs
        ])
    }

    // Device info
    var sysinfo = utsname()
    uname(&sysinfo)
    let machine = withUnsafePointer(to: &sysinfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            String(cString: $0)
        }
    }

    let device = UIDevice.current
    let screen = UIScreen.main
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
        "screen_w": Int(screen.bounds.width),
        "screen_h": Int(screen.bounds.height),
        "screen_scale": screen.scale,
        "native_scale": screen.nativeScale,
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
