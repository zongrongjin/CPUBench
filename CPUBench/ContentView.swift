import SwiftUI
import UIKit
import Foundation

// ── Minimal stack-based VM ──
// Compiler optimizes the interpreter dispatch loop,
// but can't optimize the bytecode operations (runtime data).
// Same overhead pattern as Promon's VM protecting the real SDK.

let OP_PUSH_N:    UInt8 = 0   // push iteration counter n
let OP_PUSH_K:    UInt8 = 1   // push constant by index
let OP_MOD:       UInt8 = 2   // a % b (integer)
let OP_MUL:       UInt8 = 3   // a * b
let OP_ADD:       UInt8 = 4   // a + b
let OP_DIV:       UInt8 = 5   // a / b (float)
let OP_EQZ:       UInt8 = 6   // == 0 ? 1 : 0
let OP_GT:        UInt8 = 7   // a > b ? 1 : 0
let OP_SQRT:      UInt8 = 8
let OP_ACOS:      UInt8 = 9
let OP_ASIN:      UInt8 = 10
let OP_ATAN:      UInt8 = 11
let OP_RET:       UInt8 = 12  // return TOS as bool (nonzero = true)
let OP_NOP:       UInt8 = 13  // stage5: always true
let OP_IDIV:      UInt8 = 14  // integer division

let K_44CC29: Double = 4508713
let K_11:     Double = 11
let K_30:     Double = 30
let K_1M:     Double = 1000000
let K_1_5:    Double = 1.5
let K_33_34:  Double = 33.34
let K_2:      Double = 2
let K_1:      Double = 1
let K_19_239: Double = 19.239
let K_3_56:   Double = 3.56
let K_10000:  Double = 10000

let constants: [Double] = [
    K_44CC29, K_11, K_30, K_1M, K_1_5,
    K_33_34, K_2, K_1, K_19_239, K_3_56, K_10000
]
//  indices:  0      1     2     3     4      5      6    7     8       9      10

// stage1: ((0x44CC29 % n) * 11) % n == 0
let stage1: [UInt8] = [
    OP_PUSH_K, 0,    // K
    OP_PUSH_N,       // n
    OP_MOD,          // K % n
    OP_PUSH_K, 1,    // 11
    OP_MUL,          // (K%n)*11
    OP_PUSH_N,       // n
    OP_MOD,          // ((K%n)*11) % n
    OP_EQZ,          // == 0
    OP_RET,
]

// stage2: 33.34 + n*(n+1)/2 ; result*19.239/3.56 < 10000
// Equivalent: GT(10000, (33.34 + n*(n+1)/2) * 19.239 / 3.56)
let stage2: [UInt8] = [
    OP_PUSH_K, 10,   // 10000
    OP_PUSH_K, 5,    // 33.34
    OP_PUSH_N,       // n
    OP_PUSH_N,       // n
    OP_PUSH_K, 7,    // 1
    OP_ADD,          // n+1
    OP_MUL,          // n*(n+1)
    OP_PUSH_K, 6,    // 2
    OP_DIV,          // n*(n+1)/2
    OP_ADD,          // 33.34 + ...
    OP_PUSH_K, 8,    // 19.239
    OP_MUL,          // * 19.239
    OP_PUSH_K, 9,    // 3.56
    OP_DIV,          // / 3.56
    OP_GT,           // 10000 > result => result < 10000
    OP_RET,
]

// stage3: sqrt(n) > 30
let stage3: [UInt8] = [
    OP_PUSH_N,
    OP_SQRT,
    OP_PUSH_K, 2,    // 30
    OP_GT,
    OP_RET,
]

// stage4: acos(n/1e6) + asin(n/1e6) + atan(n/1e6) > 1.5
let stage4: [UInt8] = [
    OP_PUSH_N, OP_PUSH_K, 3, OP_DIV, OP_ACOS,
    OP_PUSH_N, OP_PUSH_K, 3, OP_DIV, OP_ASIN,
    OP_ADD,
    OP_PUSH_N, OP_PUSH_K, 3, OP_DIV, OP_ATAN,
    OP_ADD,
    OP_PUSH_K, 4,    // 1.5
    OP_GT,
    OP_RET,
]

// stage5: empty loop, always true
let stage5: [UInt8] = [
    OP_NOP,
    OP_RET,
]

@inline(never)
func vmExec(program: [UInt8], n: Int) -> Bool {
    var stack = [Double]()
    stack.reserveCapacity(8)
    var ip = 0

    while ip < program.count {
        let op = program[ip]
        ip += 1

        switch op {
        case 0:  // PUSH_N
            stack.append(Double(n))
        case 1:  // PUSH_K
            stack.append(constants[Int(program[ip])])
            ip += 1
        case 2:  // MOD
            let b = Int(stack.removeLast())
            let a = Int(stack.removeLast())
            stack.append(Double(b != 0 ? a % b : 0))
        case 3:  // MUL
            let b = stack.removeLast()
            let a = stack.removeLast()
            stack.append(a * b)
        case 4:  // ADD
            let b = stack.removeLast()
            let a = stack.removeLast()
            stack.append(a + b)
        case 5:  // DIV
            let b = stack.removeLast()
            let a = stack.removeLast()
            stack.append(b != 0 ? a / b : 0)
        case 6:  // EQZ
            stack.append(stack.removeLast() == 0 ? 1 : 0)
        case 7:  // GT
            let b = stack.removeLast()
            let a = stack.removeLast()
            stack.append(a > b ? 1 : 0)
        case 8:  // SQRT
            stack.append(sqrt(stack.removeLast()))
        case 9:  // ACOS
            stack.append(acos(stack.removeLast()))
        case 10: // ASIN
            stack.append(asin(stack.removeLast()))
        case 11: // ATAN
            stack.append(atan(stack.removeLast()))
        case 12: // RET
            return (stack.last ?? 0) != 0
        case 13: // NOP (always true)
            return true
        default:
            break
        }
    }
    return false
}

@inline(never)
func runStage(_ program: [UInt8]) -> (count: Int, iters: Int) {
    let deadline = CACurrentMediaTime() + 0.002  // 2ms
    let maxIters = 999999
    var count = 0
    var n = 1

    while n <= maxIters {
        if n % 64 == 0 && CACurrentMediaTime() >= deadline { break }
        if vmExec(program: program, n: n) {
            count += 1
        }
        n += 1
    }
    return (count, n - 1)
}

@inline(never)
func runBenchmark() -> String {
    let stages = [stage1, stage2, stage3, stage4, stage5]
    var results: [[String: Any]] = []

    for round in 1...4 {
        var roundResult: [[String: Any]] = []
        let t0 = CACurrentMediaTime()

        for (i, prog) in stages.enumerated() {
            let tStart = CACurrentMediaTime()
            let (count, iters) = runStage(prog)
            let tEnd = CACurrentMediaTime()
            let us = Int((tEnd - tStart) * 1_000_000)

            roundResult.append([
                "stage": i + 1,
                "count": count,
                "iters": iters,
                "us": us
            ])
        }

        let totalUs = Int((CACurrentMediaTime() - t0) * 1_000_000)
        results.append([
            "round": round,
            "stages": roundResult,
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

    // Format -112 style output for easy comparison
    // -112 = s1_count, s1_iters/100, s2_count, s2_iters/100,
    //        s3_iters-900, s3_iters/100, s4_iters, s4_iters/100, s5_iters
    var field112_samples: [String] = []
    for r in results {
        let ss = r["stages"] as! [[String: Any]]
        let s1c = ss[0]["count"] as! Int
        let s1i = ss[0]["iters"] as! Int
        let s2c = ss[1]["count"] as! Int
        let s2i = ss[1]["iters"] as! Int
        let s3i = ss[2]["iters"] as! Int
        let s4i = ss[3]["iters"] as! Int
        let s5i = ss[4]["iters"] as! Int
        let f = "\(s1c),\(s1i/100),\(s2c),\(s2i/100),\(s3i-900),\(s3i/100),\(s4i),\(s4i/100),\(s5i)"
        field112_samples.append(f)
    }

    let info: [String: Any] = [
        "machine": machine,
        "model": UIDevice.current.model,
        "systemVersion": UIDevice.current.systemVersion,
        "cpu_count": ProcessInfo.processInfo.activeProcessorCount,
        "field_112": field112_samples,
        "benchmarks": results
    ]

    if let jsonData = try? JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys]),
       let jsonStr = String(data: jsonData, encoding: .utf8) {
        return jsonStr
    }
    return "JSON encoding failed"
}

struct ContentView: View {
    @State private var resultText = "Running VM benchmark..."

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
