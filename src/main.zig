const std = @import("std");
const pdq = @import("pdq/lib.zig");

const arithmetic = @cImport({
    @cInclude("torben.h");
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const testfile = @embedFile("original-512x512.rgb");
    var hasher =
        try pdq.framehasher.PDQFrameBufferHasher.create(allocator, 512, 512);
    defer allocator.destroy(hasher);
    var hash: pdq.Hash256 = .{};
    var hashQuality: u32 = 100;
    const buf = try allocator.alloc(u8, testfile.len);
    @memcpy(buf, testfile);
    try hasher.hashFrame(buf, &hash, &hashQuality);
    const hex_str = hash.format() catch |err| {
        std.debug.print("Format error: {}\n", .{err});
        return;
    };
    std.debug.print("{s}\n", .{hex_str});
}
