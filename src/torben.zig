const std = @import("std");

/// The following code is public domain.
/// Algorithm by Torben Mogensen, implementation by N. Devillard.
pub fn torben(m: []const f32) f32 {
    var less: i32 = undefined;
    var greater: i32 = undefined;
    var equal: i32 = undefined;
    var min: f32 = undefined;
    var max: f32 = undefined;
    var guess: f32 = undefined;
    var maxltguess: f32 = undefined;
    var mingtguess: f32 = undefined;
    const n = m.len;

    max = m[0];
    min = max;
    for (m[1..]) |val| {
        if (val < min) {
            min = val;
        }
        if (val > max) {
            max = val;
        }
    }

    while (true) {
        guess = (min + max) / 2;
        less = 0;
        greater = 0;
        equal = 0;
        maxltguess = min;
        mingtguess = max;
        for (m[0..]) |val| {
            if (val < guess) {
                less += 1;
                if (val > maxltguess) {
                    maxltguess = val;
                }
            } else if (val > guess) {
                greater += 1;
                if (val < mingtguess) {
                    mingtguess = val;
                }
            } else {
                equal += 1;
            }
        }

        if ((less <= (n + 1) / 2) and (greater <= (n + 1) / 2)) {
            break;
        } else if (less > greater) {
            max = maxltguess;
        } else {
            min = mingtguess;
        }
    }

    if (less >= ((n + 1) / 2)) {
        return maxltguess;
    } else if (less + equal >= ((n + 1) / 2)) {
        return guess;
    } else {
        return mingtguess;
    }
}

test "torben: test 1 element" {
    const arr = [_]f32{10};
    try std.testing.expectEqual(10, torben(&arr));
}

test "torben: test 2 elements" {
    const arr = [_]f32{ 10, 20 };
    try std.testing.expectEqual(10, torben(&arr));
}

test "torben: test 3 elements" {
    const arr = [_]f32{ 10, 20, 30 };
    try std.testing.expectEqual(20, torben(&arr));
}

test "torben: test 4 elements" {
    const arr = [_]f32{ 10, 20, 30, 40 };
    try std.testing.expectEqual(20, torben(&arr));
}

test "torben: test 5 elements out of order" {
    const arr = [_]f32{ 1, 5, 2, 4, 3, 1 };
    try std.testing.expectEqual(2, torben(&arr));
}
