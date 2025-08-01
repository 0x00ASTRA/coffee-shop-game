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
    @import("std").testing.refAllDecls(@This());
}
