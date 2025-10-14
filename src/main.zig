const std = @import("std");
const pdq = @import("pdq/lib.zig");

fn print_cli_help() void {
    std.debug.print("Usage: {{image filename}} {{width}} {{height}}\n", .{});
    std.debug.print("Supported image types are: {{RGB}}\n", .{});
    std.debug.print("Options:\n", .{});
    std.debug.print("image filename : The filename of the image to hash with PDQ.\n", .{});
    std.debug.print("width : The width of the image.\n", .{});
    std.debug.print("height : The height of the image.\n", .{});
    std.debug.print("Example usage:\n  pdq-hash-image foo.rgb 1024 768\n", .{});
}

fn hash_rgb_image(
    allocator: std.mem.Allocator,
    img: []u8,
    img_width: u32,
    img_height: u32,
) !struct { pdq.Hash256, u32 } {
    var hasher =
        try pdq.framehasher.PDQFrameBufferHasher.create(allocator, img_width, img_height);
    defer allocator.destroy(hasher);

    var pdqHash: pdq.Hash256 = .{};
    var pdqHashQuality: u32 = undefined;
    try hasher.hashFrame(img, &pdqHash, &pdqHashQuality);

    return .{ pdqHash, pdqHashQuality };
}

fn hash_file(
    allocator: std.mem.Allocator,
    file_path: []const u8,
    img_width: u32,
    img_height: u32,
) !struct { pdq.Hash256, u32 } {
    const img = try std.fs.cwd().readFileAlloc(allocator, file_path, std.math.maxInt(usize));
    defer allocator.free(img);
    return try hash_rgb_image(allocator, img, img_width, img_height);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();

    var args_it = try std.process.argsWithAllocator(allocator);
    defer args_it.deinit();

    if (args_it.inner.count != 4) {
        print_cli_help();
        std.log.err("Invalid number of CLI arguments.", .{});
        return error.InvalidNumOfArgs;
    }

    // Skip the executable name.
    _ = args_it.skip();

    // Parse args

    const file_path = args_it.next().?;

    const width: u32 = try std.fmt.parseInt(
        u32,
        args_it.next().?,
        0,
    );

    const height: u32 = try std.fmt.parseInt(
        u32,
        args_it.next().?,
        0,
    );

    // PDQ hash the image

    const res = try hash_file(allocator, file_path, width, height);
    const hash = try res.@"0".format();
    const hashQuality = res.@"1";

    // Serialize the PDQ hash to JSON

    var out = std.io.Writer.Allocating.init(allocator);
    defer out.deinit();

    var w: std.json.Stringify = .{ .writer = &out.writer, .options = .{ .whitespace = .indent_2 } };

    try w.beginObject();
    try w.objectField("hash");
    try w.write(hash);
    try w.objectField("quality");
    try w.write(hashQuality);
    try w.endObject();

    _ = try std.fs.File.stdout().write(out.written());
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
