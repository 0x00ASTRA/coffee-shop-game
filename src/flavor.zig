const FloralFlags = packed struct(u8) {
    jasmine: bool = false,
    rose: bool = false,
    chamomile: bool = false,
    honeysuckle: bool = false,
    _padding: u4 = 0,
};

const FruityFlags = packed struct(u16) {
    // Berries
    blackberry: bool = false,
    raspberry: bool = false,
    blueberry: bool = false,
    strawberry: bool = false,
    cherry: bool = false,
    // Citrus
    grapefruit: bool = false,
    orange: bool = false,
    lemon: bool = false,
    // ... etc.
    _padding: u8 = 0,
};

const SweetFlags = packed struct(u8) {
    chocolate: bool = false,
    caramel: bool = false,
    toffee: bool = false,
    sweet_creme: bool = false,
    white_chocolate: bool = false,
    marshmellow: bool = false,
    _padding: u2 = 0,
};

const NuttyFlags = packed struct(u16) {
    hazelnut: bool = false,
    macadamia: bool = false,
    almond: bool = false,
    pecan: bool = false,
    _padding: u12 = 0,
};

const MintyFlags = packed struct(u8) {
    mint: bool = false,
    spearmint: bool = false,
    peppermint: bool = false,
    _padding: u5 = 0,
};

const FlavorNotesFlags = packed struct(u8) {
    fruity: bool = false,
    floral: bool = false,
    sweet: bool = false,
    nutty: bool = false,
    minty: bool = false,
    _padding: u3 = 0,
};

const ContainsNotesFlags = union(enum) {
    fruity: FruityFlags,
    floral: FloralFlags,
    sweet: SweetFlags,
    nutty: NuttyFlags,
    minty: MintyFlags,
};

const bitwise = @import("utils/bitwise.zig");
const setFlags = bitwise.setFlags;
const clearFlags = bitwise.clearFlags;
const hasFlags = bitwise.hasFlags;
const bitwiseAnd = bitwise.bitwiseAnd;

pub const FlavorProfile = struct {
    fruity: FruityFlags = .{},
    floral: FloralFlags = .{},
    sweet: SweetFlags = .{},
    nutty: NuttyFlags = .{},
    minty: MintyFlags = .{},

    /// Returns true if *any* of the provided notes are present
    pub fn hasFlavorNotes(self: FlavorProfile, mask: FlavorNotesFlags) bool {
        const this_flags: FlavorNotesFlags = .{
            .fruity = self.hasFruityNotes(),
            .floral = self.hasFloralNotes(),
            .sweet = self.hasSweetNotes(),
            .nutty = self.hasNuttyNotes(),
            .minty = self.hasMintyNotes(),
        };
        const empty_mask: FlavorNotesFlags = .{};
        return bitwiseAnd(FlavorNotesFlags, this_flags, mask) != empty_mask;
    }

    /// Returns true if *all* provided notes are present
    pub fn containsFlavorNotes(self: FlavorProfile, flags: ContainsNotesFlags) bool {
        return switch (flags) {
            .fruity => |mask| self.containsFruityNotes(mask),
            .floral => |mask| self.containsFloralNotes(mask),
            .sweet => |mask| self.containsSweetNotes(mask),
            .nutty => |mask| self.containsNuttyNotes(mask),
            .minty => |mask| self.containsMintyNotes(mask),
        };
    }

    /// Returns true if *any* fruity notes are present
    pub fn hasFruityNotes(self: FlavorProfile) bool {
        const mask: FruityFlags = .{};
        return self.fruity != mask;
    }

    /// Returns true if *all* provided fruity notes are present
    pub fn containsFruityNotes(self: FlavorProfile, mask: FruityFlags) bool {
        return hasFlags(FruityFlags, self.fruity, mask);
    }

    /// Add a fruity note to the flavor profile. Does nothing if note(s) present.
    pub fn addFruityNotes(self: *FlavorProfile, mask: FruityFlags) void {
        self.fruity = setFlags(FruityFlags, self.fruity, mask);
    }

    /// Replaces the fruity notes with the provided notes
    pub fn setFruityNotes(self: *FlavorProfile, mask: FruityFlags) void {
        self.fruity = mask;
    }

    /// Removes the provided fruity note(s) from the profile.
    pub fn removeFruityNotes(self: *FlavorProfile, mask: FruityFlags) void {
        self.fruity = clearFlags(FruityFlags, self.fruity, mask);
    }

    /// Returns true if *any* floral notes are present
    pub fn hasFloralNotes(self: FlavorProfile) bool {
        const mask: FloralFlags = .{};
        return self.floral != mask;
    }

    /// Returns true if *all* provided floral notes are present
    pub fn containsFloralNotes(self: FlavorProfile, mask: FloralFlags) bool {
        return hasFlags(FloralFlags, self.floral, mask);
    }

    /// Add floral notes to the flavor profile. Does nothing if note(s) already present.
    pub fn addFloralNotes(self: *FlavorProfile, mask: FloralFlags) void {
        self.floral = setFlags(FloralFlags, self.floral, mask);
    }

    /// Replaces the floral notes with the provided notes
    pub fn setFloralNotes(self: *FlavorProfile, mask: FloralFlags) void {
        self.floral = mask;
    }

    /// Removes the provided floral note(s) from the profile.
    pub fn removeFloralNotes(self: *FlavorProfile, mask: FloralFlags) void {
        self.floral = clearFlags(FloralFlags, self.floral, mask);
    }

    /// Returns true if *any* sweet notes are present
    pub fn hasSweetNotes(self: FlavorProfile) bool {
        const mask: SweetFlags = .{};
        return self.sweet != mask;
    }

    /// Returns true if *all* provided sweet notes are present
    pub fn containsSweetNotes(self: FlavorProfile, mask: SweetFlags) bool {
        return hasFlags(SweetFlags, self.sweet, mask);
    }

    /// Add sweet notes to the flavor profile. Does nothing if note(s) already present.
    pub fn addSweetNotes(self: *FlavorProfile, mask: SweetFlags) void {
        self.sweet = setFlags(SweetFlags, self.sweet, mask);
    }

    /// Replaces the sweet notes with the provided notes
    pub fn setSweetNotes(self: *FlavorProfile, mask: SweetFlags) void {
        self.sweet = mask;
    }

    /// Removes the provided sweet note(s) from the profile.
    pub fn removeSweetNotes(self: *FlavorProfile, mask: SweetFlags) void {
        self.sweet = clearFlags(SweetFlags, self.sweet, mask);
    }

    /// Returns true if *any* nutty notes are present
    pub fn hasNuttyNotes(self: FlavorProfile) bool {
        const mask: NuttyFlags = .{};
        return self.nutty != mask;
    }

    /// Returns true if *all* provided nutty notes are present
    pub fn containsNuttyNotes(self: FlavorProfile, mask: NuttyFlags) bool {
        return hasFlags(NuttyFlags, self.nutty, mask);
    }

    /// Add nutty notes to the flavor profile. Does nothing if note(s) already present.
    pub fn addNuttyNotes(self: *FlavorProfile, mask: NuttyFlags) void {
        self.nutty = setFlags(NuttyFlags, self.nutty, mask);
    }

    /// Replaces the nutty notes with the provided notes
    pub fn setNuttyNotes(self: *FlavorProfile, mask: NuttyFlags) void {
        self.nutty = mask;
    }

    /// Removes the provided nutty note(s) from the profile.
    pub fn removeNuttyNotes(self: *FlavorProfile, mask: NuttyFlags) void {
        self.nutty = clearFlags(NuttyFlags, self.nutty, mask);
    }

    /// Returns true if *any* minty notes are present
    pub fn hasMintyNotes(self: FlavorProfile) bool {
        const mask: MintyFlags = .{};
        return self.minty != mask;
    }

    /// Returns true if *all* provided minty notes are present
    pub fn containsMintyNotes(self: FlavorProfile, mask: MintyFlags) bool {
        return hasFlags(MintyFlags, self.minty, mask);
    }

    /// Add minty notes to the flavor profile. Does nothing if note(s) already present.
    pub fn addMintyNotes(self: *FlavorProfile, mask: MintyFlags) void {
        self.minty = setFlags(MintyFlags, self.minty, mask);
    }

    /// Replaces the minty notes with the provided notes
    pub fn setMintyNotes(self: *FlavorProfile, mask: MintyFlags) void {
        self.minty = mask;
    }

    /// Removes the provided minty note(s) from the profile.
    pub fn removeMintyNotes(self: *FlavorProfile, mask: MintyFlags) void {
        self.minty = clearFlags(MintyFlags, self.minty, mask);
    }
};

pub const FlavorRule = struct {
    name: []const u8,
    condition: *const fn (profile: FlavorProfile) bool,
    action: *const fn (profile_ptr: *FlavorProfile) void,
};

const CustomRules = struct {
    before: []FlavorRule,
    after: []FlavorRule,
    action_overrides: std.StringHashMap(*const fn (profile_ptr: *FlavorProfile) void),
};

const flavor_rules = [_]FlavorRule{
    .{
        .name = "toffee",
        .condition = hasChocolateAndCaramel,
        .action = addToffeeNote,
    },
    // add more rules...
};

pub fn alterFlavor(profile: *FlavorProfile, custom_rules: CustomRules) void {
    for (custom_rules.before) |rule| {
        if (rule.condition(profile.*)) {
            rule.action(profile);
        }
    }
    inline for (flavor_rules) |rule| {
        const override = custom_rules.action_overrides.get(rule.name);
        if (rule.condition(profile.*)) {
            if (override) |action_fn| {
                action_fn(profile);
            } else {
                rule.action(profile);
            }
        }
    }
    for (custom_rules.after) |rule| {
        if (rule.condition(profile.*)) {
            rule.action(profile);
        }
    }
}

// ======== [ Conditions ] ========
fn hasChocolateAndCaramel(profile: FlavorProfile) bool {
    const mask: SweetFlags = .{ .chocolate = true, .caramel = true };
    return profile.containsFlavorNotes(.{ .sweet = mask });
}

// add more conditions...

// ======== [ Actions ] =========
fn addToffeeNote(profile_ptr: *FlavorProfile) void {
    const add_mask: SweetFlags = .{ .toffee = true };
    const remove_mask: SweetFlags = .{ .chocolate = true, .caramel = true };
    profile_ptr.removeSweetNotes(remove_mask);
    profile_ptr.addSweetNotes(add_mask);
}

// add more actions...
//
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
const testing = std.testing;

test "FlavorProfile: add, remove, and query sweet notes" {
    var profile = FlavorProfile{};

    try testing.expect(!profile.hasSweetNotes());

    profile.addSweetNotes(.{ .chocolate = true, .caramel = true });
    try testing.expect(profile.hasSweetNotes());
    try testing.expect(profile.containsSweetNotes(.{ .chocolate = true }));
    try testing.expect(profile.containsSweetNotes(.{ .caramel = true }));
    try testing.expect(!profile.containsSweetNotes(.{ .toffee = true }));

    profile.removeSweetNotes(.{ .caramel = true });
    try testing.expect(!profile.containsSweetNotes(.{ .caramel = true }));
    try testing.expect(profile.containsSweetNotes(.{ .chocolate = true }));

    profile.setSweetNotes(.{ .marshmellow = true });
    try testing.expect(!profile.containsSweetNotes(.{ .chocolate = true }));
    try testing.expect(profile.containsSweetNotes(.{ .marshmellow = true }));
}

test "FlavorProfile: hasFlavorNotes with FlavorNotesFlags mask" {
    var profile = FlavorProfile{};

    try testing.expect(!profile.hasFlavorNotes(.{ .sweet = true }));
    profile.addSweetNotes(.{ .toffee = true });
    try testing.expect(profile.hasFlavorNotes(.{ .sweet = true }));
    try testing.expect(!profile.hasFlavorNotes(.{ .floral = true }));

    profile.addFloralNotes(.{ .rose = true });
    try testing.expect(profile.hasFlavorNotes(.{ .floral = true }));
    try testing.expect(profile.hasFlavorNotes(.{ .floral = true, .sweet = true }));
    try testing.expect(!profile.hasFlavorNotes(.{ .minty = true }));
}

test "FlavorProfile: containsFlavorNotes with ContainsNotesFlags" {
    var profile = FlavorProfile{};

    profile.addNuttyNotes(.{ .almond = true, .pecan = true });
    try testing.expect(profile.containsFlavorNotes(.{ .nutty = .{ .almond = true } }));
    try testing.expect(profile.containsFlavorNotes(.{ .nutty = .{ .almond = true, .pecan = true } }));
    try testing.expect(!profile.containsFlavorNotes(.{ .nutty = .{ .hazelnut = true } }));

    profile.addMintyNotes(.{ .mint = true });
    try testing.expect(profile.containsFlavorNotes(.{ .minty = .{ .mint = true } }));
    try testing.expect(!profile.containsFlavorNotes(.{ .minty = .{ .spearmint = true } }));
}

test "alterFlavor applies built-in rule without override" {
    var profile = FlavorProfile{};
    profile.addSweetNotes(.{ .chocolate = true, .caramel = true });

    var map = std.StringHashMap(*const fn (*FlavorProfile) void).init(testing.allocator);
    defer map.deinit();

    const rules = CustomRules{
        .before = &[_]FlavorRule{},
        .after = &[_]FlavorRule{},
        .action_overrides = map,
    };

    alterFlavor(&profile, rules);

    try testing.expect(!profile.containsSweetNotes(.{ .chocolate = true }));
    try testing.expect(!profile.containsSweetNotes(.{ .caramel = true }));
    try testing.expect(profile.containsSweetNotes(.{ .toffee = true }));
}

test "alterFlavor respects custom before rule" {
    var profile = FlavorProfile{};
    const before_rule = FlavorRule{
        .name = "add_rose_if_no_floral",
        .condition = struct {
            fn anon(p: FlavorProfile) bool {
                return !p.hasFloralNotes();
            }
        }.anon,
        .action = struct {
            fn anon(p: *FlavorProfile) void {
                p.addFloralNotes(.{ .rose = true });
            }
        }.anon,
    };

    var map = std.StringHashMap(*const fn (*FlavorProfile) void).init(testing.allocator);
    defer map.deinit();

    const rules = CustomRules{
        .before = @constCast(&[_]FlavorRule{before_rule}),
        .after = @constCast(&[_]FlavorRule{}),
        .action_overrides = map,
    };

    alterFlavor(&profile, rules);
    try testing.expect(profile.containsFloralNotes(.{ .rose = true }));
}

test "alterFlavor applies action override" {
    var profile = FlavorProfile{};
    profile.addSweetNotes(.{ .chocolate = true, .caramel = true });

    const override_action = struct {
        fn anon(p: *FlavorProfile) void {
            p.setSweetNotes(.{ .white_chocolate = true });
        }
    }.anon;

    var map = std.StringHashMap(*const fn (*FlavorProfile) void).init(testing.allocator);
    defer map.deinit();

    try map.put("toffee", override_action);

    const rules = CustomRules{
        .before = &[_]FlavorRule{},
        .after = &[_]FlavorRule{},
        .action_overrides = map,
    };

    alterFlavor(&profile, rules);

    try testing.expect(!profile.containsSweetNotes(.{ .toffee = true }));
    try testing.expect(profile.containsSweetNotes(.{ .white_chocolate = true }));
}

test "alterFlavor respects custom after rule" {
    var profile = FlavorProfile{};

    const after_rule = FlavorRule{
        .name = "add_spearmint",
        .condition = struct {
            fn anon(p: FlavorProfile) bool {
                return !p.hasMintyNotes();
            }
        }.anon,
        .action = struct {
            fn anon(p: *FlavorProfile) void {
                p.addMintyNotes(.{ .spearmint = true });
            }
        }.anon,
    };

    var map = std.StringHashMap(*const fn (*FlavorProfile) void).init(testing.allocator);
    defer map.deinit();

    const rules = CustomRules{
        .before = &[_]FlavorRule{},
        .after = @constCast(&[_]FlavorRule{after_rule}),
        .action_overrides = map,
    };

    alterFlavor(&profile, rules);
    try testing.expect(profile.containsMintyNotes(.{ .spearmint = true }));
}
