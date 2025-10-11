const std = @import("std");
const zig_test_project = @import("zig_test_project");
const builtin = @import("builtin");
const torben = @import("torben.zig");
const pdqhashing = @import("pdqhashing.zig");

const arithmetic = @cImport({
    @cInclude("torben.h");
});

pub fn main() !void {
    const foo = arithmetic.dct_matrix_64();
    std.debug.print("{s}\n", .{@typeName(@TypeOf(foo))});
    for (0..1024) |i| {
        if (!std.math.approxEqAbs(f32, foo[i], pdqhashing.dctMatrix64()[i], 0.000001)) {
            std.debug.print("Failed on {}. {} != {}\n", .{ i, foo[i], pdqhashing.dctMatrix64()[i] });
        }
    }
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
