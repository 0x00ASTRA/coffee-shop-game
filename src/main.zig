const std = @import("std");

pub fn main() !void {
    std.debug.print("it builds!\n", .{});
}

test {
    const farming = @import("farming.zig");
    _ = farming;
    @import("std").testing.refAllDecls(@This());
}
