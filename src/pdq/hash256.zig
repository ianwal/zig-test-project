const std = @import("std");

pub const Hash256 = struct {
    w: [16]u16 = std.mem.zeroes([16]u16),

    // 16-bit words are essential for the MIH data structure.
    // Read more at https://fburl.com/pdq-hashing-mih
    const HASH256_NUM_BITS = 256;
    const HASH256_NUM_WORDS = 16;
    const HASH256_TEXT_LENGTH = 65;

    pub fn clear(self: *Hash256) void {
        self.w = std.mem.zeroes([16]u16);
    }

    pub fn setBit(self: *Hash256, k: u32) void {
        const uk: u32 = @intCast(k); // Assumes k >= 0; add checks if necessary
        const idx: usize = @intCast((uk & 0xFF) >> 4);
        const bit_pos: u4 = @truncate(uk & 0x0F);
        self.w[idx] |= (@as(u16, 1) << bit_pos);
    }

    /// Convert the hash to a hex string.
    pub fn format(self: *const Hash256) ![64]u8 {
        var result: [64]u8 = undefined;
        _ = try std.fmt.bufPrint(&result, "{x:04}{x:04}{x:04}{x:04}{x:04}{x:04}{x:04}{x:04}{x:04}{x:04}{x:04}{x:04}{x:04}{x:04}{x:04}{x:04}", .{
            self.w[15], self.w[14], self.w[13], self.w[12],
            self.w[11], self.w[10], self.w[9],  self.w[8],
            self.w[7],  self.w[6],  self.w[5],  self.w[4],
            self.w[3],  self.w[2],  self.w[1],  self.w[0],
        });
        return result;
    }
};
