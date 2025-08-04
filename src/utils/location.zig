const std = @import("std");
const testing = std.testing;

pub const GridLocation2D = struct {
    x: u32,
    y: u32,
};

pub const GridLocation3D = struct {
    x: u32,
    y: u32,
    z: u32,
};

pub const GridLocation = union(enum) {
    two_dimesional: GridLocation3D,
    three_dimensional: GridLocation2D,
};
