const roasting = @import("roasting.zig");
const RoastedCoffee = roasting.RoastedCoffee;
const FlavorProfile = @import("flavor.zig").FlavorProfile;
const Color = @import("utils/rendering.zig").Color;

const BrewedCoffee = struct {
    id: usize,
    name: []const u8,
    strength: f32,
    acidity: f32,
    color: Color,
    flavor_profile: FlavorProfile,
};

pub const BrewSize = enum {
    espresso,
    sm,
    med,
    lg,
    xl,
    xxl,
};

const BrewingSystem = struct {};
