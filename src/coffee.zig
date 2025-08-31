const flavor = @import("flavor.zig");
const FlavorProfile = flavor.FlavorProfile;
const Color = @import("utils/rendering.zig").Color;

/// Represents the diffgrowth stages of a coffee seed.
pub const GrowthStage = enum {
    none,
    seed,
    seedling,
    young,
    flowering,
    fruiting,
    dead,
};

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

pub const BrewSize = enum {
    espresso,
    sm,
    med,
    lg,
    xl,
    xxl,
};

pub const CoffeeState = enum {
    seed,
    beans,
    brew,
};

pub const Coffee = struct {
    name: []const u8,
    id: u64,
    acidity: f32,
    bitterness: f32,
    strength: f32,
    flavor: FlavorProfile,
};
