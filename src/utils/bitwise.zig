/// Bitwise and Bitflag Operation Helpers
//

/// Performs a bitwise AND operation on two bitflag instances.
pub fn bitwiseAnd(comptime T: type, a: T, b: T) T {
    const Integer = @typeInfo(T).@"struct".backing_integer.?;
    return @bitCast(@as(Integer, @bitCast(a)) & @as(Integer, @bitCast(b)));
}

/// Performs a bitwise OR operation on two bitflag instances.
pub fn bitwiseOr(comptime T: type, a: T, b: T) T {
    const Integer = @typeInfo(T).@"struct".backing_integer.?;
    return @bitCast(@as(Integer, @bitCast(a)) | @as(Integer, @bitCast(b)));
}

/// Performs a bitwise XOR operation on two bitflag instances.
pub fn bitwiseXor(comptime T: type, a: T, b: T) T {
    const Integer = @typeInfo(T).@"struct".backing_integer.?;
    return @bitCast(@as(Integer, @bitCast(a)) ^ @as(Integer, @bitCast(b)));
}

/// Performs a bitwise NOT operation on a bitflag instance.
pub fn bitwiseNot(comptime T: type, a: T) T {
    const Integer = @typeInfo(T).@"struct".backing_integer.?;
    return @bitCast(~@as(Integer, @bitCast(a)));
}

/// Performs a bitwise left shift on a bitflag instance.
pub fn bitwiseShiftLeft(comptime T: type, a: T, shift_amount: anytype) T {
    const Integer = @typeInfo(T).@"struct".backing_integer.?;
    return @bitCast(@as(Integer, @bitCast(a)) << @as(@TypeOf(shift_amount), shift_amount));
}

/// Performs a bitwise right shift on a bitflag instance.
pub fn bitwiseShiftRight(comptime T: type, a: T, shift_amount: anytype) T {
    const Integer = @typeInfo(T).@"struct".backing_integer.?;
    return @bitCast(@as(Integer, @bitCast(a)) >> @as(@TypeOf(shift_amount), shift_amount));
}

/// Sets the specified flags, returning the new value. (Equivalent to OR)
pub fn setFlags(comptime T: type, base: T, flags_to_set: T) T {
    return bitwiseOr(T, base, flags_to_set);
}

/// Clears the specified flags, returning the new value. (Equivalent to AND NOT)
pub fn clearFlags(comptime T: type, base: T, flags_to_clear: T) T {
    return bitwiseAnd(T, base, bitwiseNot(T, flags_to_clear));
}

/// Toggles the specified flags, returning the new value. (Equivalent to XOR)
pub fn toggleFlags(comptime T: type, base: T, flags_to_toggle: T) T {
    return bitwiseXor(T, base, flags_to_toggle);
}

/// Checks if all of the specified flags are set.
pub fn hasFlags(comptime T: type, base: T, flags_to_check: T) bool {
    return bitwiseAnd(T, base, flags_to_check) == flags_to_check;
}

// =============================================
//  ######## ########  ######  ########  ######
//     ##    ##       ##    ##    ##    ##    ##
//     ##    ##       ##          ##    ##
//     ##    ######    ######     ##     ######
//     ##    ##             ##    ##          ##
//     ##    ##       ##    ##    ##    ##    ##
//     ##    ########  ######     ##     ######
// =============================================
//
const std = @import("std");
const TestingBitflags = packed struct(u8) {
    one: bool = false,
    two: bool = false,
    three: bool = false,
    four: bool = false,
    _padding: u4 = 0,
};

test "bitwiseAnd" {
    const base_flags: TestingBitflags = .{ .one = true, .three = true };
    const and_flags: TestingBitflags = .{ .one = true, .two = true };
    const new_flags = bitwiseAnd(TestingBitflags, base_flags, and_flags);
    const expected_flags: TestingBitflags = .{ .one = true };
    try std.testing.expect(new_flags == expected_flags);
}

test "bitwiseOr" {
    const base_flags: TestingBitflags = .{ .one = true, .three = true };
    const or_flags: TestingBitflags = .{ .two = true };
    const new_flags = bitwiseOr(TestingBitflags, base_flags, or_flags);
    const expected_flags: TestingBitflags = .{ .one = true, .two = true, .three = true };
    try std.testing.expect(new_flags == expected_flags);
}

test "bitwiseXor" {
    const base_flags: TestingBitflags = .{ .one = true, .three = true };
    const xor_flags: TestingBitflags = .{ .one = true, .two = true };
    const new_flags = bitwiseXor(TestingBitflags, base_flags, xor_flags);
    const expected_flags: TestingBitflags = .{ .two = true, .three = true };
    try std.testing.expect(new_flags == expected_flags);
}

test "bitwiseNot" {
    const base_flags: TestingBitflags = .{ .one = true, .three = true }; // 0b00000101
    const new_flags = bitwiseNot(TestingBitflags, base_flags);
    const expected_flags: TestingBitflags = .{ .two = true, .four = true, ._padding = 0b1111 }; // 0b11111010
    try std.testing.expect(new_flags == expected_flags);
}

test "bitwiseShiftLeft" {
    const base_flags: TestingBitflags = .{ .one = true }; // 0b00000001
    const new_flags = bitwiseShiftLeft(TestingBitflags, base_flags, 1);
    const expected_flags: TestingBitflags = .{ .two = true }; // 0b00000010
    try std.testing.expect(new_flags == expected_flags);
}

test "bitwiseShiftRight" {
    const base_flags: TestingBitflags = .{ .two = true }; // 0b00000010
    const new_flags = bitwiseShiftRight(TestingBitflags, base_flags, 1);
    const expected_flags: TestingBitflags = .{ .one = true }; // 0b00000001
    try std.testing.expect(new_flags == expected_flags);
}

test "setFlags, clearFlags, hasFlags" {
    const flags1: TestingBitflags = .{ .one = true };
    const flags2: TestingBitflags = .{ .three = true };
    const flags3: TestingBitflags = .{ .one = true, .three = true };

    // Set flags
    var current_flags = setFlags(TestingBitflags, flags1, flags2);
    try std.testing.expect(current_flags == flags3);

    // Check flags
    try std.testing.expect(hasFlags(TestingBitflags, current_flags, flags1));
    try std.testing.expect(hasFlags(TestingBitflags, current_flags, flags2));
    try std.testing.expect(hasFlags(TestingBitflags, current_flags, flags3));
    try std.testing.expect(!hasFlags(TestingBitflags, current_flags, .{ .two = true }));

    // Clear flags
    current_flags = clearFlags(TestingBitflags, current_flags, flags1);
    try std.testing.expect(current_flags == flags2);
    try std.testing.expect(!hasFlags(TestingBitflags, current_flags, flags1));
}

test "toggleFlags" {
    var flags: TestingBitflags = .{ .one = true, .three = true };
    const toggle: TestingBitflags = .{ .one = true, .two = true };

    flags = toggleFlags(TestingBitflags, flags, toggle);
    const expected: TestingBitflags = .{ .two = true, .three = true };
    try std.testing.expect(flags == expected);
}
