const std = @import("std");
const hashing = @import("hashing.zig");
const Hash256 = @import("hash256.zig").Hash256;

pub const PDQFrameBufferHasher = struct {
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

    pub fn init(a: std.mem.Allocator, frameHeight: u32, frameWidth: u32) !Self {
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

    pub fn create(a: std.mem.Allocator, frameHeight: u32, frameWidth: u32) !*Self {
        const self = try a.create(PDQFrameBufferHasher);
        self.* = try Self.init(a, frameHeight, frameWidth);
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.fullLumaImageBuffer1);
        self.allocator.free(self.fullLumaImageBuffer2);
        self.allocator.destroy(self);
    }

    // Get PDQ Hash in Hash256 format
    pub fn hashFrame(self: *Self, buffer: []u8, hashResult: *Hash256, hashQuality: *u32) anyerror!void {
        const MIN_HASHABLE_DIM = 5;
        if ((self.frameHeight < MIN_HASHABLE_DIM) or (self.frameWidth < MIN_HASHABLE_DIM)) {
            hashResult.clear();
            return error.Failed;
        }

        hashing.fillFloatLumaFromRGB(buffer[0..], buffer[1..], buffer[2..], self.frameHeight, self.frameWidth, 3 * self.frameWidth, 3, self.fullLumaImageBuffer1);

        const buffer64x64 = @as(*[64][64]f32, @ptrCast(self.buffer64x64.ptr));
        const buffer16x64 = @as(*[16][64]f32, @ptrCast(self.buffer16x64.ptr));
        const buffer16x16 = @as(*[16][16]f32, @ptrCast(self.buffer16x16.ptr));

        hashing.pdqHash256FromFloatLuma(self.fullLumaImageBuffer1, self.fullLumaImageBuffer2, @intCast(self.frameHeight), @intCast(self.frameWidth), buffer64x64, buffer16x64, buffer16x16, hashResult, hashQuality);
    }
};
