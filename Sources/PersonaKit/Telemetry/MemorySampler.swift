import Darwin
import Foundation
import PersonaCore

/// Samples memory statistics using `host_statistics64(HOST_VM_INFO64)`.
public final class MemorySampler {
    private let totalBytes: UInt64

    public init() {
        var size: UInt64 = 0
        var sizeLen = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.memsize", &size, &sizeLen, nil, 0) == 0 {
            self.totalBytes = size
        } else {
            self.totalBytes = 16 * 1024 * 1024 * 1024 // Default fallback 16GB
        }
    }

    /// Returns RAM usage percentage (0.0 ... 100.0).
    public func sample() -> Double {
        var vmStat = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStat) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return 0.0
        }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let ps = UInt64(pageSize)

        let active = UInt64(vmStat.active_count) * ps
        let wired = UInt64(vmStat.wire_count) * ps
        let compressed = UInt64(vmStat.compressor_page_count) * ps

        return MemoryMath.usedPercent(active: active, wired: wired, compressed: compressed, total: totalBytes)
    }
}
