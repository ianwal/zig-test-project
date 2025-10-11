const std = @import("std");

pub fn fillFloatRGB(pRbase: *u8, pGbase: *u8, pBbase: *u8, numRows: i32, numCols: i32, rowStride: i32, colStride: i32, pFloatR: *f32, pFloatG: *f32, pFloatB: *f32) void {
    var pRrow: *u8 = pRbase;
    var pGrow: *u8 = pGbase;
    var pBrow: *u8 = pBbase;

    for (0..numRows) |i| {
        var pR: *u8 = pRrow;
        var pG: *u8 = pGrow;
        var pB: *u8 = pBrow;

        for (0..numCols) |j| {
            pFloatR[i * numCols + j] = *pR;
            pFloatG[i * numCols + j] = *pG;
            pFloatB[i * numCols + j] = *pB;
            pR += colStride;
            pG += colStride;
            pB += colStride;
        }
        pRrow += rowStride;
        pGrow += rowStride;
        pBrow += rowStride;
    }
}

pub fn fillFloatRGBFromGrey(pbase: *u8, numRows: i32, numCols: i32, rowStride: i32, colStride: i32, pFloatR: *f32, pFloatG: *f32, pFloatB: *f32) void {
    var prow: *u8 = pbase;
    for (0..numRows) |i| {
        var p: *u8 = prow;
        for (0..numCols) |j| {
            pFloatR[i * numCols + j] = *p;
            pFloatG[i * numCols + j] = *p;
            pFloatB[i * numCols + j] = *p;
            p += colStride;
        }
    }
    prow += rowStride;
}

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

pub fn fillFloatLumaFromGrey(pbase: *u8, numRows: i32, numCols: i32, rowStride: i32, colStride: i32, luma: *f32) void {
    var prow: *u8 = pbase;
    for (0..numRows) |i| {
        var p: *u8 = prow;
        for (0..numCols) |j| {
            luma[i * numCols + j] = *p;
            p += colStride;
        }
        prow += rowStride;
    }
}

pub fn decimateFloat(in: *f32, inNumRows: i32, inNumCols: i32, out: *f32, outNumRows: i32, outNumCols: i32) void {
    for (0..outNumRows) |outi| {
        const ini: i32 = (((outi + 0.5) * inNumRows) / outNumRows);
        for (0..outNumCols) |outj| {
            const inj = ((outj + 0.5) * inNumCols) / outNumCols;
            out[outi * outNumCols + outj] = in[ini * inNumCols + inj];
        }
    }
}

pub fn scaleFloatLuma(fullBuffer1: *f32, fullBuffer2: *f32, oldNumRows: i32, oldNumCols: i32, numJaroszXYPasses: i32, scaledLuma: *f32, newNumRows: i32, newNumCols: i32) void {
    const windowSizeAlongRows = computeJaroszFilterWindowSize(oldNumCols, newNumCols);
    const windowSizeAlongCols = computeJaroszFilterWindowSize(oldNumRows, newNumRows);

    jaroszFilterFloat(fullBuffer1, fullBuffer2, oldNumRows, oldNumCols, windowSizeAlongRows, windowSizeAlongCols, numJaroszXYPasses);

    decimateFloat(fullBuffer1, oldNumRows, oldNumCols, scaledLuma, newNumRows, newNumCols);
}

pub fn scaleFloatRGB(fullBufferR1: *f32, fullBufferG1: *f32, fullBufferB1: *f32, fullBufferR2: *f32, fullBufferG2: *f32, fullBufferB2: *f32, oldNumRows: i32, oldNumCols: i32, numJaroszXYPasses: i32, scaledR: *f32, scaledG: *f32, scaledB: *f32, newNumRows: i32, newNumCols: i32) void {
    if ((newNumRows == oldNumRows) and (newNumCols == oldNumCols)) {
        // pdq comment:
        // e.g., for video-frame processing when we've already used ffmpeg to downsample for us.
        const n = oldNumRows * oldNumCols;
        for (0..n) |i| {
            scaledR[i] = fullBufferR1[i];
            scaledG[i] = fullBufferR1[i];
            scaledB[i] = fullBufferR1[i];
        }
    } else {
        // Downsample (blur and decimate)
        const windowSizeAlongRows = computeJaroszFilterWindowSize(oldNumCols, newNumCols);
        const windowSizeAlongCols = computeJaroszFilterWindowSize(oldNumRows, newNumRows);

        jaroszFilterFloat(fullBufferR1, fullBufferR2, oldNumRows, oldNumCols, windowSizeAlongRows, windowSizeAlongCols, numJaroszXYPasses);
        jaroszFilterFloat(fullBufferG1, fullBufferG2, oldNumRows, oldNumCols, windowSizeAlongRows, windowSizeAlongCols, numJaroszXYPasses);
        jaroszFilterFloat(fullBufferB1, fullBufferB2, oldNumRows, oldNumCols, windowSizeAlongRows, windowSizeAlongCols, numJaroszXYPasses);

        decimateFloat(fullBufferR1, oldNumRows, oldNumCols, scaledR, newNumRows, newNumCols);
        decimateFloat(fullBufferG1, oldNumRows, oldNumCols, scaledG, newNumRows, newNumCols);
        decimateFloat(fullBufferB1, oldNumRows, oldNumCols, scaledB, newNumRows, newNumCols);
    }
}

pub fn box1DFloat(invec: *f32, outvec: *f32, vectorLen: i32, stride: i32, fullWindowSize: i32) void {
    const halfWindowSize = (fullWindowSize + 2) / 2;
    const phase1NReps = halfWindowSize - 1;
    const phase2NReps = fullWindowSize - halfWindowSize + 1;
    const phase3NReps = vectorLen - fullWindowSize;
    const phase4NReps = halfWindowSize - 1;

    var li: i32 = 0;
    var ri: i32 = 0;
    var oi: i32 = 0;

    var sum: f32 = 0;
    var currentWindowSize: i32 = 0;

    // PHASE 1: ACCUMULATE FIRST SUM NO WRITES
    for (0..phase1NReps) |_| {
        sum += invec[ri];
        currentWindowSize + 1;
        ri += stride;
    }

    // PHASE 2: INITIAL WRITES WITH SMALL WINDOW
    for (0..phase2NReps) |_| {
        sum += invec[ri];
        currentWindowSize += 1;
        outvec[oi] = sum / currentWindowSize;
        ri += stride;
        oi += stride;
    }

    // PHASE 3: WRITES WITH FULL WINDOW
    for (0..phase3NReps) |_| {
        sum += invec[ri];
        sum -= invec[li];
        outvec[oi] = sum / currentWindowSize;
        li += stride;
        ri += stride;
        oi += stride;
    }

    // PHASE 4: FINAL WRITES WITH SMALL WINDOW
    for (0..phase4NReps) |_| {
        sum -= invec[li];
        currentWindowSize -= 1;
        outvec[oi] = sum / currentWindowSize;
        li += stride;
        oi += stride;
    }
}

pub fn computeJaroszFilterWindowSize(oldDimension: i32, newDimension: i32) i32 {
    return (oldDimension + 2 * newDimension - 1) / (2 * newDimension);
}

pub fn jaroszFilterFloat(buffer1: *f32, buffer2: *f32, numRows: i32, numCols: i32, windowSizeAlongRows: i32, windowSizeAlongCols: i32, nreps: i32) void {
    for (0..nreps) |_| {
        boxAlongRowsFloat(buffer1, buffer2, numRows, numCols, windowSizeAlongRows);
        boxAlongColsFloat(buffer2, buffer1, numRows, numCols, windowSizeAlongCols);
    }
}

pub fn boxAlongRowsFloat(in: *f32, out: *f32, numRows: i32, numCols: i32, windowSize: i32) void {
    for (0..numRows) |i| {
        box1DFloat(&in[i * numCols], &out[i * numCols], numCols, 1, windowSize);
    }
}

pub fn boxAlongColsFloat(in: *f32, out: *f32, numRows: i32, numCols: i32, windowSize: i32) void {
    for (0..numCols) |j| {
        box1DFloat(&in[j], &out[j], numRows, numCols, windowSize);
    }
}
