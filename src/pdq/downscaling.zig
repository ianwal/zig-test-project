// From Wikipedia: standard RGB to luminance (the 'Y' in 'YUV').
const luma_from_R_coeff = 0.299;
const luma_from_G_coeff = 0.587;
const luma_from_B_coeff = 0.114;

pub fn fillFloatLumaFromRGB(pRbase: [*]u8, pGbase: [*]u8, pBbase: [*]u8, numRows: u32, numCols: u32, rowStride: u32, colStride: u32, luma: [*]f32) void {
    var pRrow = pRbase;
    var pGrow = pGbase;
    var pBrow = pBbase;

    for (0..numRows) |i| {
        var pR = pRrow;
        var pG = pGrow;
        var pB = pBrow;
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

pub fn decimateFloat(in: [*]f32, inNumRows: u32, inNumCols: u32, out: [*]f32, outNumRows: u32, outNumCols: u32) void {
    for (0..outNumRows) |outi| {
        const ini: u32 = @intFromFloat((((@as(f32, @floatFromInt(outi)) + 0.5) * @as(f32, @floatFromInt(inNumRows))) / @as(f32, @floatFromInt(outNumRows))));
        for (0..outNumCols) |outj| {
            const inj: u32 = @intFromFloat(((@as(f32, @floatFromInt(outj)) + 0.5) * @as(f32, @floatFromInt(inNumCols))) / @as(f32, @floatFromInt(outNumCols)));
            out[outi * outNumCols + outj] = in[ini * inNumCols + inj];
        }
    }
}

pub fn scaleFloatLuma(fullBuffer1: [*]f32, fullBuffer2: [*]f32, oldNumRows: u32, oldNumCols: u32, numJaroszXYPasses: u32, scaledLuma: [*]f32, newNumRows: u32, newNumCols: u32) void {
    const windowSizeAlongRows = computeJaroszFilterWindowSize(oldNumCols, newNumCols);
    const windowSizeAlongCols = computeJaroszFilterWindowSize(oldNumRows, newNumRows);

    jaroszFilterFloat(fullBuffer1, fullBuffer2, oldNumRows, oldNumCols, windowSizeAlongRows, windowSizeAlongCols, numJaroszXYPasses);

    decimateFloat(fullBuffer1, oldNumRows, oldNumCols, scaledLuma, newNumRows, newNumCols);
}

pub fn scaleFloatRGB(fullBufferR1: [*]f32, fullBufferG1: [*]f32, fullBufferB1: [*]f32, fullBufferR2: [*]f32, fullBufferG2: [*]f32, fullBufferB2: [*]f32, oldNumRows: u32, oldNumCols: u32, numJaroszXYPasses: u32, scaledR: [*]f32, scaledG: [*]f32, scaledB: [*]f32, newNumRows: u32, newNumCols: u32) void {
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

pub fn box1DFloat(invec: [*]f32, outvec: [*]f32, vectorLen: u32, stride: u32, fullWindowSize: u32) void {
    const halfWindowSize = (fullWindowSize + 2) / 2;
    const phase1NReps = halfWindowSize - 1;
    const phase2NReps = fullWindowSize - halfWindowSize + 1;
    const phase3NReps = vectorLen - fullWindowSize;
    const phase4NReps = halfWindowSize - 1;

    var li: u32 = 0;
    var ri: u32 = 0;
    var oi: u32 = 0;

    var sum: f32 = 0;
    var currentWindowSize: f32 = 0;

    // PHASE 1: ACCUMULATE FIRST SUM NO WRITES
    for (0..phase1NReps) |_| {
        sum += invec[ri];
        currentWindowSize += 1;
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

pub fn computeJaroszFilterWindowSize(oldDimension: u32, newDimension: u32) u32 {
    return (oldDimension + 2 * newDimension - 1) / (2 * newDimension);
}

pub fn jaroszFilterFloat(buffer1: [*]f32, buffer2: [*]f32, numRows: u32, numCols: u32, windowSizeAlongRows: u32, windowSizeAlongCols: u32, nreps: u32) void {
    for (0..nreps) |_| {
        for (0..numRows) |i| {
            box1DFloat(buffer1[i * numCols ..], buffer2[i * numCols ..], numCols, 1, windowSizeAlongRows);
        }
        for (0..numCols) |j| {
            box1DFloat(buffer2[j..], buffer1[j..], numRows, numCols, windowSizeAlongCols);
        }
    }
}
