import Darwin
import Foundation
import PersonaCore

/// Samples host CPU load using `host_processor_info(PROCESSOR_CPU_LOAD_INFO)`.
public final class CPUSampler {
    private var prevTicks: [UInt32]?

    public init() {}

    /// Returns the CPU usage percent (0.0 ... 100.0) since the last sample, or 0.0 on the first sample.
    public func sample() -> Double {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return 0.0
        }

        let count = Int(numCPUInfo)
        var currentTicks = [UInt32](repeating: 0, count: count)
        for i in 0..<count {
            currentTicks[i] = UInt32(info[i])
        }

        // Deallocate vm memory returned by host_processor_info
        let vmSize = vm_size_t(count * MemoryLayout<integer_t>.size)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vmSize)

        defer { prevTicks = currentTicks }

        guard let prev = prevTicks, prev.count == currentTicks.count else {
            return 0.0
        }

        return CPUMath.usage(prev: prev, cur: currentTicks)
    }
}
