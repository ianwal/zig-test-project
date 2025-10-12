const torben = @import("torben.zig");
const downscaling = @import("downscaling.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Hash256 = struct {
    w: [16]u16 = std.mem.zeroes([16]u16),

    // ----------------------------------------------------------------
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

pub fn fillFloatLumaFromRGB(
    pRbase: []const u8,
    pGbase: []const u8,
    pBbase: []const u8,
    numRows: u32,
    numCols: u32,
    rowStride: u32,
    colStride: u32,
    luma: []f32,
) void {
    // From Wikipedia: standard RGB to luminance (the 'Y' in 'YUV').
    const luma_from_R_coeff: f32 = 0.299;
    const luma_from_G_coeff: f32 = 0.587;
    const luma_from_B_coeff: f32 = 0.114;

    var row: u32 = 0;
    while (row < numRows) : (row += 1) {
        var col: u32 = 0;
        while (col < numCols) : (col += 1) {
            const base_index: usize = @intCast(row * rowStride + col * colStride);

            const yval: f32 =
                luma_from_R_coeff * @as(f32, @floatFromInt(pRbase[base_index])) +
                luma_from_G_coeff * @as(f32, @floatFromInt(pGbase[base_index])) +
                luma_from_B_coeff * @as(f32, @floatFromInt(pBbase[base_index]));

            luma[@intCast(row * numCols + col)] = yval;
        }
    }
}

const MIN_HASHABLE_DIM = 5;

pub fn pdqHash256FromFloatLuma(fullBuffer1: []f32, fullBuffer2: []f32, numRows: u32, numCols: u32, buffer64x64: *[64][64]f32, buffer16x64: *[16][64]f32, buffer16x16: *[16][16]f32, hash: *Hash256, quality: *u32) void {
    if ((numRows < MIN_HASHABLE_DIM) or (numCols < MIN_HASHABLE_DIM)) {
        hash.clear();
        quality.* = 0;
        return;
    }

    pdqFloat256FromFloatLuma(fullBuffer1, fullBuffer2, numRows, numCols, buffer64x64, buffer16x64, buffer16x16, quality);

    // Output bits
    pdqBuffer16x16ToBits(buffer16x16, hash);
}

// Tent filter.
const PDQ_NUM_JAROSZ_XY_PASSES = 2;

pub fn pdqFloat256FromFloatLuma(fullBuffer1: []f32, fullBuffer2: []f32, numRows: u32, numCols: u32, buffer64x64: *[64][64]f32, buffer16x64: *[16][64]f32, outputBuffer16x16: *[16][16]f32, quality: *u32) void {
    if ((numRows == 64) and (numCols == 64)) {
        // e.g., for video-frame processing when we've already used ffmpeg
        // to downsample for us.
        // std.debug.print("Rows and colums are correct size. Skipping downsample.\n", .{});
        var k: usize = 0;
        for (0..64) |i| {
            for (0..64) |j| {
                buffer64x64[i][j] = fullBuffer1[k];
                k += 1;
            }
        }
    } else {
        // Downsample (blur and decimate)
        const windowSizeAlongRows = downscaling.computeJaroszFilterWindowSize(numCols, 64);
        const windowSizeAlongCols = downscaling.computeJaroszFilterWindowSize(numRows, 64);

        downscaling.jaroszFilterFloat(fullBuffer1.ptr, fullBuffer2.ptr, numRows, numCols, windowSizeAlongRows, windowSizeAlongCols, PDQ_NUM_JAROSZ_XY_PASSES);

        downscaling.decimateFloat(fullBuffer1.ptr, numRows, numCols, buffer64x64[0][0..], 64, 64);
    }

    // Quality metric. Reuse the 64x64 image-domain downsample since we already have it.
    quality.* = pdqImageDomainQualityMetric(buffer64x64);

    // 2D DCT
    dct64To16(buffer64x64, buffer16x64, outputBuffer16x16);
}

/// Each bit of the 16x16 output hash is for whether the given frequency
/// component is greater than the median frequency component or not.
pub fn pdqBuffer16x16ToBits(dctOutput16x16: *[16][16]f32, hash: *Hash256) void {
    const flat16x16: []const f32 = @as([*]const f32, @ptrCast(&dctOutput16x16[0][0]))[0 .. 16 * 16];

    const dctMedian = torben.torben(flat16x16);

    hash.clear();
    for (0..16) |i| {
        for (0..16) |j| {
            if (dctOutput16x16[i][j] > dctMedian) {
                hash.setBit(@as(u32, @intCast(i * 16 + j)));
            }
        }
    }
}

// ----------------------------------------------------------------
// Christoph Zauner 'Implementation and Benchmarking of Perceptual
// Image Hash Functions' 2010
//
// See comments on dct64To16. Input is (0..63)x(0..63); output is
// (1..16)x(1..16) with the latter indexed as (0..15)x(0..15).
//
// * numRows is 16.
// * numCols is 64.
// * Storage is row-major
// * Element i,j at row i column j is at offset i*16+j.
const dctMatrix64 = blk: {
    const num_rows: usize = 16;
    const num_cols: usize = 64;
    var matrix: [num_rows][num_cols]f32 = undefined;
    const matrix_scale_factor: f64 = @sqrt(2.0 / @as(f64, @floatFromInt(num_cols)));
    const pi: f64 = std.math.pi;
    var i: usize = 0;
    while (i < num_rows) : (i += 1) {
        var j: usize = 0;
        @setEvalBranchQuota(10000);
        while (j < num_cols) : (j += 1) {
            const angle: f64 = (pi / 2.0 / @as(f64, @floatFromInt(num_cols))) * (@as(f64, @floatFromInt(i + 1)) * @as(f64, @floatFromInt(2 * j + 1)));
            matrix[i][j] = @floatCast(matrix_scale_factor * std.math.cos(angle));
        }
    }
    break :blk matrix;
};

// ----------------------------------------------------------------
// This is all heuristic (see the PDQ hashing doc). Quantization matters since
// we want to count *significant* gradients, not just the some of many small
// ones. The constants are all manually selected, and tuned as described in the
// document.
pub fn pdqImageDomainQualityMetric(buffer64x64: *[64][64]f32) u32 {
    var gradientSum: u32 = 0;

    for (0..63) |i| {
        for (0..64) |j| {
            const u = buffer64x64[i][j];
            const v = buffer64x64[i + 1][j];
            const d = ((u - v) * 100) / 255;
            gradientSum += @intFromFloat(@abs(d));
        }
    }

    for (0..64) |i| {
        for (0..63) |j| {
            const u = buffer64x64[i][j];
            const v = buffer64x64[i][j + 1];
            const d = ((u - v) * 100) / 255;
            gradientSum += @intFromFloat(@abs(d));
        }
    }

    // Heuristic scaling factor.
    var quality = @divTrunc(gradientSum, 90);
    if (quality > 100) {
        quality = 100;
    }

    return quality;
}

pub fn dct64To16(A: *[64][64]f32, T: *[16][64]f32, B: *[16][16]f32) void {
    const D = dctMatrix64;

    var i: usize = 0;
    while (i < 16) : (i += 1) {
        var j: usize = 0;
        while (j < 64) : (j += 1) {
            const pd: [*]const f32 = @ptrCast(&D[i][0]);
            var pa: [*]f32 = @ptrCast(&A[0][j]);
            var sumk: f32 = 0.0;

            var kk: usize = 0;
            while (kk < 64) : (kk += 16) {
                sumk += pd[kk + 0] * pa[0 << 6];
                sumk += pd[kk + 1] * pa[1 << 6];
                sumk += pd[kk + 2] * pa[2 << 6];
                sumk += pd[kk + 3] * pa[3 << 6];
                sumk += pd[kk + 4] * pa[4 << 6];
                sumk += pd[kk + 5] * pa[5 << 6];
                sumk += pd[kk + 6] * pa[6 << 6];
                sumk += pd[kk + 7] * pa[7 << 6];
                sumk += pd[kk + 8] * pa[8 << 6];
                sumk += pd[kk + 9] * pa[9 << 6];
                sumk += pd[kk + 10] * pa[10 << 6];
                sumk += pd[kk + 11] * pa[11 << 6];
                sumk += pd[kk + 12] * pa[12 << 6];
                sumk += pd[kk + 13] * pa[13 << 6];
                sumk += pd[kk + 14] * pa[14 << 6];
                sumk += pd[kk + 15] * pa[15 << 6];
                pa += 1024;
            }
            T[i][j] = sumk;
        }
    }

    var row: usize = 0;
    while (row < 16) : (row += 1) {
        var j: usize = 0;
        while (j < 16) : (j += 1) {
            var sumk: f32 = 0.0;
            const pd: [*]const f32 = @ptrCast(&D[j][0]);
            const pt: [*]const f32 = @ptrCast(&T[row][0]);
            var k: usize = 0;
            while (k < 64) : (k += 1) {
                sumk += pt[k] * pd[k];
            }
            B[row][j] = sumk;
        }
    }
}
