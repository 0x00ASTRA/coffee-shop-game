const std = @import("std");
const FlavorProfile = @import("flavor.zig").FlavorProfile;
const CoffeeBeans = @import("coffee.zig").CoffeeBeans;
/// Represents the different roast levels of coffee beans,
/// categorized from light to dark.
pub const RoastLevel = enum {
    white, // bitter, nutty flavor
    //-- Light Roasts (High acidity, bright, preserves origin flavors)
    cinnamon,
    new_england,

    //-- Medium Roasts (Balanced flavor, aroma, and acidity)
    american,
    city,

    //-- Medium-Dark Roasts (Richer body, hints of caramel, slight bittersweet notes)
    full_city,
    vienna,

    //-- Dark Roasts (Oily surface, strong roasty flavor, low acidity)
    french,
    italian,
    spanish,
    black,

    /// Returns a string representation of the roast level.
    pub fn toString(self: RoastLevel) []const u8 {
        return switch (self) {
            .white => "White",
            .cinnamon => "Cinnamon",
            .new_england => "New England",
            .american => "American",
            .city => "City",
            .full_city => "Full City",
            .vienna => "Vienna",
            .french => "French",
            .italian => "Italian",
            .spanish => "Spanish",
            .black => "Black",
        };
    }
};

pub const RoastedCoffee = struct {
    id: u32,
    seed_id: u32,
    name: []const u8,
    roast_lvl: RoastLevel,
    acidity: f32,
    bitterness: f32,
    strength: f32,
    flavor: FlavorProfile,
};

pub const RoastingSystem = struct {
    allocator: std.mem.Allocator,
    roasts: std.ArrayList(RoastedCoffee),
    roasts_map: std.AutoHashMap(u32, RoastedCoffee),

    pub fn init(allocator: std.mem.Allocator) !*RoastingSystem {
        const self = try allocator.create(RoastingSystem);
        var roasts = std.ArrayList(RoastedCoffee).init(allocator);
        var roasts_map = std.AutoHashMap(u32, RoastedCoffee).init(allocator);
        _ = roasts_map.get(0);
        try roasts.ensureTotalCapacity(50);
        self.* = .{
            .allocator = allocator,
            .roasts = roasts,
            .roasts_map = roasts_map,
        };
    }

    pub fn deinit(self: *RoastingSystem) void {
        for (self.roasts.items) |item| {
            std.debug.assert(item.name.len > 0); // sanity check
            self.allocator.free(item.name);
        }
        self.roasts.deinit();
        // var iter = self.roasts_map.iterator();
        // while (iter.next()) |item| {
        //     std.debug.assert(item.value_ptr.name.len > 0);
        //     self.allocator.free(item.value_ptr.name);
        // }
        self.allocator.destroy(self);
    }

    pub fn newRoast(self: *RoastingSystem, allocator: std.mem.Allocator, opts: struct {
        seed_id: u32,
        name: []const u8,
        roast_lvl: RoastLevel,
        acidity: f32,
        bitterness: f32,
        strength: f32,
        flavor: FlavorProfile,
    }) !RoastedCoffee {
        const roast: RoastedCoffee = .{
            .id = self.roasts.items.len,
            .seed_id = opts.seed_id,
            .name = try self.allocator.dupe(opts.name),
            .roast_lvl = opts.roast_lvl,
            .acidity = opts.acidity,
            .bitterness = opts.bitterness,
            .strength = opts.strength,
            .flavor = opts.flavor,
        };
        try self.roasts.append(roast);
        try self.roasts_map.put(roast.id, roast);
        return .{
            .id = roast.id,
            .seed_id = roast.seed_id,
            .name = try allocator.dupe(roast.name),
            .roast_lvl = roast.roast_lvl,
            .acidity = roast.acidity,
            .bitterness = roast.bitterness,
            .strength = roast.strength,
            .flavor = roast.flavor,
        };
    }

    pub fn getRoast(self: *RoastingSystem, allocator: std.mem.Allocator, id: u32) ?RoastedCoffee {
        const roast = self.roasts_map.get(id);
        if (roast) {
            return RoastedCoffee{
                .name = try allocator.dupe(u8, roast.?.name),
                .seed_id = roast.?.seed_id,
                .id = roast.?.id,
                .flavor = roast.?.flavor,
                .acidity = roast.?.acidity,
                .bitterness = roast.?.id,
                .strength = roast.?.strength,
                .roast_lvl = roast.?.roast_lvl,
            };
        }
        return null;
    }

    pub fn roastCoffeeBeans(self: *RoastingSystem, beans: CoffeeBeans, roasting_curve: RoastingCurve, duration: i64) u32 {}
};

pub const RoastingCurve = struct {
    timestamps: []i64,
    roast_lvls: []RoastLevel,
};
