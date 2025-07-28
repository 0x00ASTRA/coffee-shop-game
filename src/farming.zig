const std = @import("std");

const DEFAULT_BASE_YIELD: u32 = 3;

pub const GrowthStage = enum {
    none,
    seed,
    seedling,
    young,
    flowering,
    fruiting,
    dead,
};

/// A function that determines a GrowthStage based on progress (0.0 to 1.0).
pub const GrowthAlgorithm = *const fn (progress: f32) GrowthStage;
/// A simple linear growth algorithm.
pub fn linearGrowthAlgorithm(progress: f32) GrowthStage {
    if (progress < 0.25) {
        return .seed;
    } else if (progress < 0.50) {
        return .seedling;
    } else if (progress < 0.75) {
        return .young;
    } else {
        return .flowering;
    }
}

pub const FarmError = error{
    IndexOutOfRange,
    NoPlotsAvailable,
    PlotOccupied,
};

pub const PlantManyResult = union(enum) {
    success: void,
    err: FarmError,
};

pub const PlotModifierFlags = enum(u32) {
    fertilizer = 1,
    speed_grow = 1 << 1,
    extra_yield = 1 << 2,
    no_plow = 1 << 3,
    no_cost = 1 << 4,
};

pub const HarvestResult = struct {
    allocator: std.mem.Allocator,
    plot_ids: std.ArrayList(usize),
    seed_ids: std.ArrayList(u32),
    yields: std.ArrayList(u32),

    pub fn init(allocator: std.mem.Allocator, num_plots: usize) !*HarvestResult {
        const self = try allocator.create(HarvestResult);

        var plot_ids = std.ArrayList(usize).init(allocator);
        try plot_ids.ensureTotalCapacity(num_plots);

        var seed_ids = std.ArrayList(u32).init(allocator);
        try seed_ids.ensureTotalCapacity(num_plots);

        var yields = std.ArrayList(u32).init(allocator);
        try yields.ensureTotalCapacity(num_plots);

        self.* = .{ .allocator = allocator, .plot_ids = plot_ids, .seed_ids = seed_ids, .yields = yields };
        return self;
    }

    pub fn deinit(self: *HarvestResult) void {
        self.plot_ids.deinit();
        self.seed_ids.deinit();
        self.yields.deinit();
        self.allocator.destroy(self);
    }
};

pub const Farm = struct {
    allocator: std.mem.Allocator,
    id: u32,
    name: []const u8,
    num_plots: u32,
    growth_stages: std.ArrayList(GrowthStage),
    growth_start_times: std.ArrayList(?i64),
    growth_end_times: std.ArrayList(?i64),
    seed_ids: std.ArrayList(?u32),
    plot_mod_flags: std.ArrayList(u32),

    pub fn init(allocator: std.mem.Allocator, opts: struct { id: u32, name: []const u8, num_plots: u32 }) !*Farm {
        var growth_stages = std.ArrayList(GrowthStage).init(allocator);
        try growth_stages.appendNTimes(.none, opts.num_plots);

        var growth_start_times = std.ArrayList(?i64).init(allocator);
        try growth_start_times.appendNTimes(null, opts.num_plots);

        var growth_end_times = std.ArrayList(?i64).init(allocator);
        try growth_end_times.appendNTimes(null, opts.num_plots);

        var seed_ids = std.ArrayList(?u32).init(allocator);
        try seed_ids.appendNTimes(null, opts.num_plots);

        var plot_mod_flags = std.ArrayList(u32).init(allocator);
        try plot_mod_flags.appendNTimes(0, opts.num_plots);

        const name_cpy = try allocator.dupe(u8, opts.name);
        const self = try allocator.create(Farm);
        self.* = .{
            .allocator = allocator,
            .id = opts.id,
            .name = name_cpy,
            .num_plots = opts.num_plots,
            .growth_stages = growth_stages,
            .growth_start_times = growth_start_times,
            .growth_end_times = growth_end_times,
            .seed_ids = seed_ids,
            .plot_mod_flags = plot_mod_flags,
        };
        return self;
    }

    pub fn deinit(self: *Farm) void {
        self.allocator.free(self.name);
        self.growth_stages.deinit();
        self.growth_start_times.deinit();
        self.growth_end_times.deinit();
        self.seed_ids.deinit();
        self.plot_mod_flags.deinit();
        self.allocator.destroy(self);
    }

    /// Finds the index of the next available plot.
    pub fn nextAvailablePlot(self: *const Farm) !usize {
        for (self.seed_ids.items, 0..) |item, i| {
            if (item == null) {
                return i;
            }
        }
        return FarmError.NoPlotsAvailable;
    }

    /// Apply a modifier mask to a plot
    pub fn applyModifier(self: *Farm, plot_id: usize, mask: u32) !void {
        if (plot_id >= self.num_plots) {
            return FarmError.IndexOutOfRange;
        }

        const old_mask = self.plot_mod_flags.items[plot_id];
        const new_mask = old_mask | mask;
        const changed = old_mask ^ new_mask; // Find which flags were newly added
        self.plot_mod_flags.items[plot_id] = new_mask;

        // Only apply effects for flags that just changed.
        if (changed & @intFromEnum(PlotModifierFlags.speed_grow) != 0) {
            if (self.growth_start_times.items[plot_id]) |start_time| {
                if (self.growth_end_times.items[plot_id]) |end_time| {
                    const remaining_time = end_time - start_time;
                    // For this example, speed_grow halves the remaining time.
                    const new_end_time = end_time - @divFloor(remaining_time, 2);
                    self.growth_end_times.items[plot_id] = new_end_time;
                }
            }
        }
    }

    pub fn removeModifiers(self: *Farm, plot_id: usize, mask: u32) !void {
        if (plot_id >= self.num_plots) {
            return FarmError.IndexOutOfRange;
        }

        const old_mask = self.plot_mod_flags.items[plot_id];
        const new_mask = old_mask & ~mask; // Correctly remove flags
        const changed = old_mask ^ new_mask; // Find which flags were actually removed
        self.plot_mod_flags.items[plot_id] = new_mask;

        // Revert effects for flags that were just removed.
        if (changed & @intFromEnum(PlotModifierFlags.speed_grow) != 0) {
            if (self.growth_start_times.items[plot_id]) |start_time| {
                if (self.growth_end_times.items[plot_id]) |end_time| {
                    // To revert, we double the time that has passed since planting
                    // and add it back to the end time.
                    const time_since_start = end_time - start_time;
                    const original_total_time = time_since_start * 2;
                    self.growth_end_times.items[plot_id] = start_time + original_total_time;
                }
            }
        }
    }

    pub fn removeManyModifiers(self: *Farm, plot_ids: []const usize, masks: []const u32) !void {
        // Ensure the slices have a 1-to-1 mapping
        std.debug.assert(plot_ids.len == masks.len);

        for (plot_ids, masks) |plot_id, mask| {
            try self.removeModifiers(plot_id, mask);
        }
    }

    pub fn clearModifiers(self: *Farm, plot_id: usize) !void {
        if (plot_id >= self.num_plots) {
            return FarmError.IndexOutOfRange;
        }
        // To clear all, just "remove" the current mask, which handles reverting effects.
        const current_mask = self.plot_mod_flags.items[plot_id];
        if (current_mask == 0) return; // Nothing to do
        try self.removeModifiers(plot_id, current_mask);
    }

    pub fn clearManyModifiers(self: *Farm, plot_ids: []const usize) !void {
        for (plot_ids) |plot_id| {
            try self.clearModifiers(plot_id);
        }
    }

    /// Plants a seed in a specified plot or the next available one.
    pub fn plantOne(self: *Farm, seed: struct { id: u32, grow_time: i64 }, plot: union(enum) {
        id: usize,
        next,
    }) !void {
        const plot_id = switch (plot) {
            .id => |i| i,
            .next => try self.nextAvailablePlot(),
        };

        if (plot_id >= self.num_plots) {
            return FarmError.IndexOutOfRange;
        }

        if (self.seed_ids.items[plot_id] != null) {
            return FarmError.PlotOccupied;
        }

        const start_time = std.time.timestamp();
        const end_time = start_time + seed.grow_time;
        self.growth_stages.items[plot_id] = .seed;
        self.growth_start_times.items[plot_id] = start_time;
        self.growth_end_times.items[plot_id] = end_time;
        self.seed_ids.items[plot_id] = seed.id;
    }

    /// Clear the specified plot
    pub fn clearPlot(self: *Farm, plot_id: usize) !void {
        if (plot_id > self.seed_ids.items.len - 1) {
            return FarmError.IndexOutOfRange;
        }
        self.seed_ids.items[plot_id] = null;
        self.growth_start_times.items[plot_id] = null;
        self.growth_end_times.items[plot_id] = null;
        self.growth_stages.items[plot_id] = GrowthStage.none;
    }

    pub fn clearAllPlots(self: *Farm) void {
        for (0.., self.seed_ids.items) |i, item| {
            _ = item;
            self.seed_ids.items[i] = null;
            self.growth_start_times.items[i] = null;
            self.growth_end_times.items[i] = null;
            self.growth_stages.items[i] = .none;
        }
    }

    /// Plants seeds mapped to plot ids. Takes an allocator as arg. Caller is in charge of freeing allocated memory.
    pub fn plantMany(
        self: *Farm,
        allocator: std.mem.Allocator,
        seeds: []const struct { seed_id: u32, plot_id: usize, grow_time: i64 },
    ) ![]PlantManyResult {
        var results = std.ArrayList(PlantManyResult).init(allocator);
        errdefer results.deinit();

        for (seeds) |seed| {
            if (seed.plot_id >= self.num_plots) {
                try results.append(.{ .err = FarmError.IndexOutOfRange });
                continue;
            }
            if (self.seed_ids.items[seed.plot_id] != null) {
                try results.append(.{ .err = FarmError.PlotOccupied });
                continue;
            }

            const start_time = std.time.timestamp();
            const end_time = start_time + seed.grow_time;
            self.growth_stages.items[seed.plot_id] = .seed;
            self.growth_start_times.items[seed.plot_id] = start_time;
            self.growth_end_times.items[seed.plot_id] = end_time;
            self.seed_ids.items[seed.plot_id] = seed.seed_id;

            try results.append(.{ .success = {} });
        }
        return results.toOwnedSlice();
    }

    /// Harvest the grown crops, calculating and returning yields for each plot.
    /// Caller is in charge of calling deinit on result.
    pub fn harvest(self: *Farm, allocator: std.mem.Allocator, base_yields: std.AutoHashMap(u32, u32)) !*HarvestResult {
        var result = try HarvestResult.init(allocator, self.num_plots);
        errdefer result.deinit();

        for (0.., self.growth_stages.items) |i, stage| {
            // We only care about plots that are fruiting or dead
            if (stage != .fruiting and stage != .dead) continue;
            if (self.seed_ids.items[i] == null) continue;

            const seed_id = self.seed_ids.items[i].?;
            var final_yield: u32 = 0;

            if (stage == .fruiting) {
                final_yield = base_yields.get(seed_id) orelse DEFAULT_BASE_YIELD;
                // Check for extra yield modifier
                if (self.plot_mod_flags.items[i] & @intFromEnum(PlotModifierFlags.extra_yield) != 0) {
                    final_yield *= 2; // Double the yield
                }
            }

            try result.plot_ids.append(i);
            try result.seed_ids.append(seed_id);
            try result.yields.append(final_yield);

            // Clear the plot unless the no_plow modifier is active
            if (self.plot_mod_flags.items[i] & @intFromEnum(PlotModifierFlags.no_plow) == 0) {
                try self.clearPlot(i);
            }
        }

        return result;
    }

    pub fn update(self: *Farm, current_time: i64, algorithm: GrowthAlgorithm) void {
        for (0.., self.growth_stages.items) |i, stage| {
            if (stage == .none or stage == .fruiting or stage == .dead) {
                continue;
            }

            const start_time = self.growth_start_times.items[i] orelse continue;
            const end_time = self.growth_end_times.items[i] orelse continue;

            // If the current time has passed the end time, the plant is ready for harvest.
            if (current_time >= end_time) {
                self.growth_stages.items[i] = .fruiting;
                continue;
            }

            const total_duration = end_time - start_time;
            if (total_duration <= 0) continue; // Avoid division by zero.

            const elapsed_time = current_time - start_time;

            const progress = @as(f32, @floatFromInt(elapsed_time)) / @as(f32, @floatFromInt(total_duration));

            // Use the provided algorithm to determine the new stage.
            self.growth_stages.items[i] = algorithm(progress);
        }
    }
};

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
const test_allocator = std.testing.allocator;
const expect = std.testing.expect;
const expectEq = std.testing.expectEqual;
const expectErr = std.testing.expectError;

test "next available plot" {
    var farm = try Farm.init(test_allocator, .{ .id = 1, .name = "Farm-1", .num_plots = 5 });
    defer farm.deinit();

    farm.seed_ids.items[0] = 1234;
    farm.seed_ids.items[1] = 2345;

    const next_p = try farm.nextAvailablePlot();
    try expectEq(2, next_p);

    for (0.., farm.seed_ids.items) |i, item| {
        _ = item;
        farm.seed_ids.items[i] = 2345;
    }

    try expectErr(FarmError.NoPlotsAvailable, farm.nextAvailablePlot());
}

test "plant one" {
    var farm = try Farm.init(test_allocator, .{ .id = 1, .name = "Farm-1", .num_plots = 5 });
    defer farm.deinit();

    try farm.plantOne(.{ .id = 2345, .grow_time = 10_000 }, .next);
    try expectEq(2345, farm.seed_ids.items[0].?);
    try expect(farm.growth_start_times.items[0] != null);
    try expect(farm.growth_end_times.items[0] != null);
    const grow_time = farm.growth_end_times.items[0].? - farm.growth_start_times.items[0].?;
    try expectEq(10_000, grow_time);

    try farm.plantOne(.{ .id = 2345, .grow_time = 10_000 }, .{ .id = 3 });
    try expectEq(2345, farm.seed_ids.items[3].?);

    try expectErr(FarmError.PlotOccupied, farm.plantOne(.{ .id = 678, .grow_time = 30_000 }, .{ .id = 3 }));
    try expectErr(FarmError.IndexOutOfRange, farm.plantOne(.{ .id = 678, .grow_time = 30_000 }, .{ .id = 20 }));

    for (0.., farm.seed_ids.items) |i, item| {
        _ = item;
        farm.seed_ids.items[i] = 2345;
    }

    try expectErr(FarmError.NoPlotsAvailable, farm.plantOne(.{ .id = 678, .grow_time = 30_000 }, .next));
}

test "plant many" {
    var farm = try Farm.init(test_allocator, .{ .id = 1, .name = "Farm-1", .num_plots = 5 });
    defer farm.deinit();

    const results = try farm.plantMany(test_allocator, &.{
        .{ .seed_id = 111, .plot_id = 1, .grow_time = 100 }, // Will succeed
        .{ .seed_id = 999, .plot_id = 99, .grow_time = 200 }, // Will fail (index out of range)
        .{ .seed_id = 333, .plot_id = 1, .grow_time = 300 }, // Will fail (plot occupied by 111)
        .{ .seed_id = 444, .plot_id = 4, .grow_time = 400 }, // Will succeed
    });
    defer test_allocator.free(results);

    // Check the results slice
    for (results, 0..) |res, i| {
        switch (i) {
            0 => try expect(res.success == {}),
            1 => try expect(res.err == FarmError.IndexOutOfRange),
            2 => try expect(res.err == FarmError.PlotOccupied),
            3 => try expect(res.success == {}),
            else => unreachable,
        }
    }

    // Check the final state of the farm
    try expect(farm.seed_ids.items[0] == null);
    try expectEq(111, farm.seed_ids.items[1].?);
    try expectEq(444, farm.seed_ids.items[4].?);
}

test "clear plot" {
    var farm = try Farm.init(test_allocator, .{ .id = 1, .name = "Farm-1", .num_plots = 5 });
    defer farm.deinit();

    const results = try farm.plantMany(test_allocator, &.{
        .{ .seed_id = 111, .plot_id = 1, .grow_time = 100 },
        .{ .seed_id = 444, .plot_id = 3, .grow_time = 400 },
    });
    defer test_allocator.free(results);

    try expect(farm.seed_ids.items[3] == 444);

    try farm.clearPlot(3);
    try expect(farm.seed_ids.items[3] == null);
    try expect(farm.growth_start_times.items[3] == null);
    try expect(farm.growth_end_times.items[3] == null);
    try expect(farm.growth_stages.items[3] == .none);
}

test "clear all plots" {
    var farm = try Farm.init(test_allocator, .{ .id = 1, .name = "Farm-1", .num_plots = 5 });
    defer farm.deinit();

    const results = try farm.plantMany(test_allocator, &.{
        .{ .seed_id = 111, .plot_id = 0, .grow_time = 400 },
        .{ .seed_id = 111, .plot_id = 1, .grow_time = 100 },
        .{ .seed_id = 111, .plot_id = 2, .grow_time = 400 },
        .{ .seed_id = 111, .plot_id = 3, .grow_time = 100 },
        .{ .seed_id = 111, .plot_id = 4, .grow_time = 400 },
    });
    defer test_allocator.free(results);

    for (0.., farm.seed_ids.items) |i, item| {
        _ = item;
        try expect(farm.seed_ids.items[i] == 111);
    }
    farm.clearAllPlots();
    for (0.., farm.seed_ids.items) |i, item| {
        _ = item;
        try expect(farm.seed_ids.items[i] == null);
        try expect(farm.growth_start_times.items[i] == null);
        try expect(farm.growth_end_times.items[i] == null);
        try expect(farm.growth_stages.items[i] == .none);
    }
}

test "apply modifier" {
    var farm = try Farm.init(test_allocator, .{ .id = 1, .name = "Farm-1", .num_plots = 5 });
    defer farm.deinit();

    // Plant a seed with a known grow time
    try farm.plantOne(.{ .id = 123, .grow_time = 20_000 }, .{ .id = 2 });

    // const original_end_time = farm.growth_end_times.items[2].?;

    // Apply the speed_grow modifier
    try farm.applyModifier(2, @intFromEnum(PlotModifierFlags.speed_grow));

    // Check that the flag is set
    const expected_mask = @intFromEnum(PlotModifierFlags.speed_grow);
    try expect(farm.plot_mod_flags.items[2] == expected_mask);

    // Check that the grow time was reduced by half
    const new_end_time = farm.growth_end_times.items[2].?;
    const original_start_time = farm.growth_start_times.items[2].?;
    try expect(new_end_time == original_start_time + 10_000);

    // Apply it again and make sure the time doesn't change again
    try farm.applyModifier(2, @intFromEnum(PlotModifierFlags.speed_grow));
    try expect(farm.growth_end_times.items[2].? == new_end_time);
}

test "harvest" {
    var farm = try Farm.init(test_allocator, .{ .id = 1, .name = "Farm-1", .num_plots = 5 });
    defer farm.deinit();

    // Setup base yields for our seeds
    var base_yields = std.AutoHashMap(u32, u32).init(test_allocator);
    defer base_yields.deinit();
    try base_yields.put(101, 5); // Seed 101 has a base yield of 5
    try base_yields.put(102, 10); // Seed 102 has a base yield of 10

    // Plot 0: Fruiting, normal yield
    farm.seed_ids.items[0] = 101;
    farm.growth_stages.items[0] = .fruiting;

    // Plot 1: Fruiting, extra yield
    farm.seed_ids.items[1] = 102;
    farm.growth_stages.items[1] = .fruiting;
    farm.plot_mod_flags.items[1] = @intFromEnum(PlotModifierFlags.extra_yield);

    // Plot 2: Fruiting, extra yield, but won't be cleared
    farm.seed_ids.items[2] = 101;
    farm.growth_stages.items[2] = .fruiting;
    farm.plot_mod_flags.items[2] = @intFromEnum(PlotModifierFlags.extra_yield) | @intFromEnum(PlotModifierFlags.no_plow);

    // Plot 3: Dead plant
    farm.seed_ids.items[3] = 101;
    farm.growth_stages.items[3] = .dead;

    // Plot 4: Still growing, should be ignored
    farm.seed_ids.items[4] = 102;
    farm.growth_stages.items[4] = .seedling;

    // --- Perform Harvest ---
    var result = try farm.harvest(test_allocator, base_yields);
    defer result.deinit();

    // --- Verify Results ---
    try expectEq(4, result.plot_ids.items.len);

    // Check plot 0 results (normal yield)
    try expectEq(0, result.plot_ids.items[0]);
    try expectEq(101, result.seed_ids.items[0]);
    try expectEq(5, result.yields.items[0]); // Base yield for seed 101

    // Check plot 1 results (extra yield)
    try expectEq(1, result.plot_ids.items[1]);
    try expectEq(102, result.seed_ids.items[1]);
    try expectEq(20, result.yields.items[1]); // 10 * 2

    // Check plot 2 results (extra yield)
    try expectEq(2, result.plot_ids.items[2]);
    try expectEq(101, result.seed_ids.items[2]);
    try expectEq(10, result.yields.items[2]); // 5 * 2

    // Check plot 3 results (dead)
    try expectEq(3, result.plot_ids.items[3]);
    try expectEq(101, result.seed_ids.items[3]);
    try expectEq(0, result.yields.items[3]);

    // --- Verify Farm State After Harvest ---
    // Plot 0 should be cleared
    try expect(farm.seed_ids.items[0] == null);
    // Plot 1 should be cleared
    try expect(farm.seed_ids.items[1] == null);
    // Plot 2 should NOT be cleared (no_plow)
    try expect(farm.seed_ids.items[2] != null);
    try expectEq(.fruiting, farm.growth_stages.items[2]);
    // Plot 3 should be cleared
    try expect(farm.seed_ids.items[3] == null);
    // Plot 4 should be untouched
    try expect(farm.seed_ids.items[4] != null);
}

test "remove and clear modifiers" {
    var farm = try Farm.init(test_allocator, .{ .id = 1, .name = "Farm-1", .num_plots = 5 });
    defer farm.deinit();

    // -- Test Setup --
    // Plot 0: will have speed_grow and extra_yield, then we remove speed_grow
    // Plot 1: will have all modifiers, then we clear them all
    // Plot 2 & 3: for removeMany and clearMany
    const initial_grow_time: i64 = 40_000;
    try farm.plantOne(.{ .id = 1, .grow_time = initial_grow_time }, .{ .id = 0 });
    try farm.plantOne(.{ .id = 2, .grow_time = initial_grow_time }, .{ .id = 1 });
    try farm.plantOne(.{ .id = 3, .grow_time = initial_grow_time }, .{ .id = 2 });
    try farm.plantOne(.{ .id = 4, .grow_time = initial_grow_time }, .{ .id = 3 });

    const start_time_0 = farm.growth_start_times.items[0].?;
    const start_time_1 = farm.growth_start_times.items[1].?;

    // -- Test removeModifiers --
    const apply_mask_0 = @intFromEnum(PlotModifierFlags.speed_grow) | @intFromEnum(PlotModifierFlags.extra_yield);
    try farm.applyModifier(0, apply_mask_0);

    // Check that speed_grow was applied correctly
    var sped_up_end_time = farm.growth_end_times.items[0].?;
    try expectEq(start_time_0 + initial_grow_time / 2, sped_up_end_time);

    // Now, remove just the speed_grow flag
    try farm.removeModifiers(0, @intFromEnum(PlotModifierFlags.speed_grow));
    var reverted_end_time = farm.growth_end_times.items[0].?;

    // Check that grow time reverted and extra_yield flag remains
    try expectEq(start_time_0 + initial_grow_time, reverted_end_time);
    try expectEq(@intFromEnum(PlotModifierFlags.extra_yield), farm.plot_mod_flags.items[0]);

    // -- Test clearModifiers --
    const all_mods = @intFromEnum(PlotModifierFlags.speed_grow) | @intFromEnum(PlotModifierFlags.extra_yield) | @intFromEnum(PlotModifierFlags.fertilizer);
    try farm.applyModifier(1, all_mods);

    // Verify speed_grow was applied
    sped_up_end_time = farm.growth_end_times.items[1].?;
    try expectEq(start_time_1 + initial_grow_time / 2, sped_up_end_time);
    try expectEq(all_mods, farm.plot_mod_flags.items[1]);

    // Now clear all modifiers from the plot
    try farm.clearModifiers(1);
    reverted_end_time = farm.growth_end_times.items[1].?;

    // Check that the mask is 0 and time is reverted
    try expectEq(0, farm.plot_mod_flags.items[1]);
    try expectEq(start_time_1 + initial_grow_time, reverted_end_time);

    // -- Test removeManyModifiers & clearManyModifiers --
    try farm.applyModifier(2, @intFromEnum(PlotModifierFlags.speed_grow));
    try farm.applyModifier(3, @intFromEnum(PlotModifierFlags.extra_yield) | @intFromEnum(PlotModifierFlags.speed_grow));

    // Remove speed_grow from plot 2 and extra_yield from plot 3
    try farm.removeManyModifiers(&.{ 2, 3 }, &.{ @intFromEnum(PlotModifierFlags.speed_grow), @intFromEnum(PlotModifierFlags.extra_yield) });

    try expectEq(0, farm.plot_mod_flags.items[2]); // Was only speed_grow
    try expectEq(@intFromEnum(PlotModifierFlags.speed_grow), farm.plot_mod_flags.items[3]); // extra_yield removed

    // Clear all from plots 2 and 3 (only 3 has mods left)
    try farm.clearManyModifiers(&.{ 2, 3 });
    try expectEq(0, farm.plot_mod_flags.items[2]);
    try expectEq(0, farm.plot_mod_flags.items[3]);
}

test "growth algorithm and update" {
    var farm = try Farm.init(test_allocator, .{ .id = 1, .name = "Farm-1", .num_plots = 1 });
    defer farm.deinit();

    const grow_time: i64 = 100;
    try farm.plantOne(.{ .id = 999, .grow_time = grow_time }, .{ .id = 0 });

    // Manually set times for a deterministic test.
    const start_time: i64 = 1_000_000;
    farm.growth_start_times.items[0] = start_time;
    farm.growth_end_times.items[0] = start_time + grow_time;

    // Test point at 10% progress -> should be 'seed'
    farm.update(start_time + 10, linearGrowthAlgorithm);
    try expectEq(.seed, farm.growth_stages.items[0]);

    // Test point at 30% progress -> should be 'seedling'
    farm.update(start_time + 30, linearGrowthAlgorithm);
    try expectEq(.seedling, farm.growth_stages.items[0]);

    // Test point at 60% progress -> should be 'young'
    farm.update(start_time + 60, linearGrowthAlgorithm);
    try expectEq(.young, farm.growth_stages.items[0]);

    // Test point at 90% progress -> should be 'flowering'
    farm.update(start_time + 90, linearGrowthAlgorithm);
    try expectEq(.flowering, farm.growth_stages.items[0]);

    // Test point after completion -> should be 'fruiting'
    farm.update(start_time + grow_time + 1, linearGrowthAlgorithm);
    try expectEq(.fruiting, farm.growth_stages.items[0]);
}

