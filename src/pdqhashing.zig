const torben = @import("torben.zig");
const downscaling = @import("downscaling.zig");
const std = @import("std");

const Hash256 = struct {
    w: u16[16],

    fn clear(self: *Hash256) void {
        // TODO
        self;
    }

    fn setBit(self: *Hash256, k: i32) void {
        self.w[(k & 255) >> 4] |= 1 << (k & 15);
    }
};

// From Wikipedia: standard RGB to luminance (the 'Y' in 'YUV').
const luma_from_R_coeff = 0.299;
const luma_from_G_coeff = 0.587;
const luma_from_B_coeff = 0.114;

pub fn fillFloatLumaFromRGB(pRbase: *u8, pGbase: *u8, pBbase: *u8, numRows: i32, numCols: i32, rowStride: i32, colStride: i32, luma: *f32) void {
    var pRrow: *u8 = pRbase;
    var pGrow: *u8 = pGbase;
    var pBrow: *u8 = pBbase;

    for (0..numRows) |i| {
        var pR: *u8 = pRrow;
        var pG: *u8 = pGrow;
        var pB: *u8 = pBrow;
        for (0..numCols) |j| {
            const yval: f32 = luma_from_R_coeff * (*pR) + luma_from_G_coeff * (*pG) + luma_from_B_coeff * (*pB);
            luma[i * numCols + j] = yval;
            pR += colStride;
            pG += colStride;
            pB += colStride;
        }
        pRrow += rowStride;
        pGrow += rowStride;
        pBrow += rowStride;
    }
}

const MIN_HASHABLE_DIM = 5;

pub fn pdqHash256FromFloatLuma(fullBuffer1: *f32, fullBuffer2: *f32, numRows: i32, numCols: i32, buffer64x64: [64][64]f32, buffer16x64: [16][64]f32, buffer16x16: [16][16]f32, hash: *Hash256, quality: *i32) void {
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

pub fn pdqFloat256FromFloatLuma(fullBuffer1: *f32, fullBuffer2: *f32, numRows: i32, numCols: i32, buffer64x64: [64][64]f32, buffer16x64: [16][64]f32, outputBuffer16x16: [16][16]f32, quality: *i32) void {
    if ((numRows == 64) and (numCols == 64)) {
        // e.g., for video-frame processing when we've already used ffmpeg
        // to downsample for us.
        var k: i32 = 0;
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

        downscaling.jaroszFilterFloat(fullBuffer1, fullBuffer2, numRows, numCols, windowSizeAlongRows, windowSizeAlongCols, PDQ_NUM_JAROSZ_XY_PASSES);

        downscaling.decimateFloat(fullBuffer1, numRows, numCols, &buffer64x64[0][0], 64, 64);
    }

    // Quality metric. Reuse the 64x64 image-domain downsample since we already have it.
    // TODO:
    // quality.* = pdqImageDomainQualityMetric(buffer64x64);

    // 2D DCT
    // dct64to16(buffer6x64, buffer16x64, outputBuffer16x16);
    buffer16x64;
    outputBuffer16x16;
    quality;
}

/// Each bit of the 16x16 output hash is for whether the given frequency
/// component is greater than the median frequency component or not.
pub fn pdqBuffer16x16ToBits(dctOutput16x16: [16][16]f32, hash: *Hash256) void {
    const dctMedian = torben.torben(dctOutput16x16[0][0], 16 * 16);

    hash.clear();
    for (0..16) |i| {
        for (0..16) |j| {
            if (dctOutput16x16[i][j] > dctMedian) {
                hash.setBit(i * 16 + j);
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
pub fn dctMatrix64() [16 * 64]f32 {
    const numRows = 16;
    const numCols = 64;
    const matrixScaleFactor = std.math.sqrt(2.0 / @as(f32, numCols));

    var dctMatrix: [numRows * numCols]f32 = undefined;
    for (0..numRows) |i| {
        for (0..numCols) |j| {
            dctMatrix[i * numCols + j] = matrixScaleFactor * std.math.cos((std.math.pi / 2.0 / @as(f32, numCols)) * (@as(f32, @floatFromInt(i)) + 1.0) * (2.0 * @as(f32, @floatFromInt(j)) + 1.0));
        }
    }
    return dctMatrix;
}
