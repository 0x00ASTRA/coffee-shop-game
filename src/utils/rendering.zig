/// Utility types relating to rendering
///
const std = @import("std");

const Color = union(enum) {
    rgb: struct { r: u8, g: u8, b: u8 },
    rgba: struct { r: u8, g: u8, b: u8, a: u8 },
};
