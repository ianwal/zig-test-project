const std = @import("std");
const pdq = @import("pdq/lib.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();

    const testfile = try std.fs.cwd().readFileAlloc(allocator, "original-512x512.rgb", std.math.maxInt(usize));
    defer allocator.free(testfile);

    var hasher =
        try pdq.framehasher.PDQFrameBufferHasher.create(allocator, 512, 512);
    defer allocator.destroy(hasher);

    var pdqHash: pdq.Hash256 = .{};
    var pdqHashQuality: u32 = undefined;
    try hasher.hashFrame(testfile, &pdqHash, &pdqHashQuality);

    const hex_str = pdqHash.format() catch |err| {
        std.debug.print("Format error: {}\n", .{err});
        return;
    };
    std.debug.print("PDQ Hash: {s}\n", .{hex_str});
}

test "functional test: image pdq hash" {
    var allocator = std.testing.allocator;

    const testfile = try std.fs.cwd().readFileAlloc(allocator, "original-512x512.rgb", std.math.maxInt(usize));
    defer allocator.free(testfile);

    var hasher =
        try pdq.framehasher.PDQFrameBufferHasher.create(allocator, 512, 512);
    defer hasher.deinit();

    var pdqHash: pdq.Hash256 = .{};
    var pdqHashQuality: u32 = undefined;
    try hasher.hashFrame(testfile, &pdqHash, &pdqHashQuality);

    const hex_str = try pdqHash.format();
    try std.testing.expectEqualStrings("d8f8f0cec0f4a84f0637022a278f67f0b36e2ed596621e1d33e6339c4e9c9b22", &hex_str);
}
