const std = @import("std");

pub fn main() !void {
    std.debug.print("it builds!\n", .{});
}

test {
    const farming = @import("farming.zig");
    _ = farming;
    const storage = @import("storage.zig");
    _ = storage;
    const economy = @import("economy.zig");
    _ = economy;
    const flavor = @import("flavor.zig");
    _ = flavor;

    const bitwise_utils = @import("utils/bitwise.zig");
    _ = bitwise_utils;
    @import("std").testing.refAllDecls(@This());
}
