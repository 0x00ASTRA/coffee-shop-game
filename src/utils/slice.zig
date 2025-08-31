const std = @import("std");
const testing = std.testing;

/// Reverses a slice of any type in place.
/// This function uses a two-pointer approach to swap elements
/// from the beginning and end of the slice until the pointers meet in the middle.
pub fn reverse(comptime T: type, slice: []T) void {
    var i: usize = 0;
    var j: usize = slice.len - 1;

    while (i < j) {
        // Swap elements at indices i and j.
        const temp = slice[i];
        slice[i] = slice[j];
        slice[j] = temp;
        i += 1;
        j -= 1;
    }
}

test "reversing a slice of i64" {
    var my_slice: [5]i64 = .{ 1, 2, 3, 4, 5 };

    reverse(i64, &my_slice);

    try testing.expectEqualSlices(i64, &my_slice, &.{ 5, 4, 3, 2, 1 });
}
