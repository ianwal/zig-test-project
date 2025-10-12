const std = @import("std");
const zig_test_project = @import("zig_test_project");
const builtin = @import("builtin");
const torben = @import("torben.zig");
const pdqhashing = @import("pdqhashing.zig");

const arithmetic = @cImport({
    @cInclude("torben.h");
});

const PDQFrameBufferHasher = struct {
    allocator: std.mem.Allocator,
    frameHeight: u32,
    frameWidth: u32,
    numRGBTriples: u32,

    fullLumaImageBuffer1: []f32,
    fullLumaImageBuffer2: []f32,
    buffer64x64: []f32,
    buffer16x64: []f32,
    buffer16x16: []f32,

    const Self = @This();
    const SCALED_DIMENSION = 64;

    fn init(a: std.mem.Allocator, frameHeight: u32, frameWidth: u32) !Self {
        const numRGBTriples: usize = @intCast(frameWidth * frameHeight);

        const fullLumaImageBuffer1 = try a.alloc(f32, numRGBTriples);
        errdefer a.free(fullLumaImageBuffer1);
        const fullLumaImageBuffer2 = try a.alloc(f32, numRGBTriples);
        errdefer a.free(fullLumaImageBuffer2);
        const buffer64x64 = try a.alloc(f32, 64 * 64);
        errdefer a.free(buffer64x64);
        const buffer16x64 = try a.alloc(f32, 16 * 64);
        errdefer a.free(buffer16x64);
        const buffer16x16 = try a.alloc(f32, 16 * 16);
        errdefer a.free(buffer16x16);

        return .{
            .allocator = a,
            .frameHeight = frameHeight,
            .frameWidth = frameWidth,
            .numRGBTriples = @intCast(numRGBTriples),
            .fullLumaImageBuffer1 = fullLumaImageBuffer1,
            .fullLumaImageBuffer2 = fullLumaImageBuffer2,
            .buffer64x64 = buffer64x64,
            .buffer16x64 = buffer16x64,
            .buffer16x16 = buffer16x16,
        };
    }

    fn create(a: std.mem.Allocator, frameHeight: u32, frameWidth: u32) !*Self {
        const self = try a.create(PDQFrameBufferHasher);
        self.* = try Self.init(a, frameHeight, frameWidth);
        return self;
    }

    fn deinit(self: *Self) void {
        self.allocator.free(self.fullLumaImageBuffer1);
        self.allocator.free(self.fullLumaImageBuffer2);
        self.allocator.destroy(self);
    }

    // Get PDQ Hash in Hash256 format
    fn hashFrame(self: *Self, buffer: []u8, hashResult: *pdqhashing.Hash256, hashQuality: *u32) anyerror!void {
        const MIN_HASHABLE_DIM = 5;
        if ((self.frameHeight < MIN_HASHABLE_DIM) or (self.frameWidth < MIN_HASHABLE_DIM)) {
            hashResult.clear();
            return error.Failed;
        }

        pdqhashing.fillFloatLumaFromRGB(buffer[0..], buffer[1..], buffer[2..], self.frameHeight, self.frameWidth, 3 * self.frameWidth, 3, self.fullLumaImageBuffer1);

        const buffer64x64 = @as(*[64][64]f32, @ptrCast(self.buffer64x64.ptr));
        const buffer16x64 = @as(*[16][64]f32, @ptrCast(self.buffer16x64.ptr));
        const buffer16x16 = @as(*[16][16]f32, @ptrCast(self.buffer16x16.ptr));

        pdqhashing.pdqHash256FromFloatLuma(self.fullLumaImageBuffer1, self.fullLumaImageBuffer2, @intCast(self.frameHeight), @intCast(self.frameWidth), buffer64x64, buffer16x64, buffer16x16, hashResult, hashQuality);
    }
};

pub fn main() !void {
    const foo = arithmetic.dct_matrix_64();
    std.debug.print("{s}\n", .{@typeName(@TypeOf(foo))});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const testfile = @embedFile("original-512x512.rgb");
    var hasher =
        try PDQFrameBufferHasher.create(allocator, 512, 512);
    defer allocator.destroy(hasher);
    var hash: pdqhashing.Hash256 = .{};
    var hashQuality: u32 = 100;
    const buf = try allocator.alloc(u8, testfile.len);
    @memcpy(buf, testfile);
    try hasher.hashFrame(buf, &hash, &hashQuality);
    const hex_str = hash.format() catch |err| {
        std.debug.print("Format error: {}\n", .{err});
        return; // Or handle as needed
    };
    std.debug.print("{s}\n", .{hex_str});
    // hasher.hashFrame();
    //for (0..1024) |i| {
    //if (!std.math.approxEqAbs(f32, foo[i], pdqhashing.dctMatrix64()[i], 0.000001)) {
    //    std.debug.print("Failed on {}. {} != {}\n", .{ i, foo[i], pdqhashing.dctMatrix64()[i] });
    //}
    //}
    // std.debug.print("{any}", .{pdqhashing.dctMatrix64()});
    return;

    // var writer_buffer: [8 * 1024]u8 = undefined;
    // var redirect_buffer: [8 * 1024]u8 = undefined;
    // var transfer_buffer: [8 * 1024]u8 = undefined;
    // var reader_buffer: [8 * 1024]u8 = undefined;

    // var writer = std.fs.File.stdout().writer(&writer_buffer);

    // const allocator = std.heap.c_allocator;
    // const uri = try std.Uri.parse("https://postman-echo.com/get");

    // var client: std.http.Client = .{ .allocator = allocator };

    // defer client.deinit();

    // var request = try client.request(.GET, uri, .{});

    // defer request.deinit();

    // try request.sendBodiless();

    // const response = try request.receiveHead(&redirect_buffer);

    // _ = try writer.interface.write(response.head.bytes);

    // const content_length = response.head.content_length;
    // const reader = request.reader.bodyReader(&transfer_buffer, .none, content_length);

    // var done = false;
    // var bytes_read: usize = 0;

    // while (!done) {
    //     const size = try reader.readSliceShort(&reader_buffer);

    //     if (size > 0) {
    //         bytes_read += size;
    //         _ = try writer.interface.write(reader_buffer[0..size]);
    //     }

    //     if (content_length) |c_len| {
    //         if (bytes_read >= c_len) {
    //             done = true;
    //         }
    //     }

    //     if (size < reader_buffer.len) {
    //         done = true;
    //     }
    // }

    // try writer.interface.flush();
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
