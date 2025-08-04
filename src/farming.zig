const std = @import("std");
const GridLocation2D = @import("utils/location.zig").GridLocation2D;

pub const FarmError = error{
    InvalidPlotId,
    NoPlotsAvailable,
    PlotOccupied,
    PlotNotHarvestable,
};

pub const PlotSize = enum { sm, md, lg, xl };

pub const GrowthStage = enum {
    seed,
    seedling,
    young,
    flowering,
    fruiting,
    dead,
};

/// A series of time thresholds that define growth transitions.
pub const GrowthCurve = struct {
    timestamps: []const i64,

    /// Create a growth curve with exact stage timestamps.
    pub fn init(comptime timestamps: []const i64) GrowthCurve {
        comptime std.debug.assert(timestamps.len == @typeInfo(GrowthStage).@"enum".fields.len);
        return .{ .timestamps = timestamps };
    }

    /// Check current growth stage given time since planting.
    pub fn checkStage(self: GrowthCurve, progress: i64) GrowthStage {
        var i = self.timestamps.len;
        while (i > 0) : (i -= 1) {
            if (progress >= self.timestamps[i - 1])
                return @enumFromInt(i - 1);
        }
        return .seed;
    }
};

/// A plantable seed with a growth curve and yield parameters.
pub const Seed = struct {
    name: []const u8,
    id: u64,
    description: []const u8,
    fruit_id: u64,
    min_yield: u32,
    max_yield: u32,
    growth_curve: GrowthCurve,
};

pub const Plot = struct {
    name: []const u8 = "Plot",
    id: u64,
    size: PlotSize = .sm,
};

/// Harvest result after a successful harvest.
pub const HarvestResult = struct {
    fruit_id: u64,
    yield: u32,
};

/// Manages a grid of plots, seed planting, growth, and harvesting.
pub const Farm = struct {
    allocator: std.mem.Allocator,
    id: u64,
    name: []const u8,
    plots: std.ArrayList(Plot),
    plot_locations: std.ArrayList(GridLocation2D),
    plot_seeds: std.ArrayList(?Seed),
    growth_stages: std.ArrayList(?GrowthStage),
    growth_start_times: std.ArrayList(?i64),
    _plot_id_to_idx: std.AutoHashMap(u64, usize),
    _last_update: i64 = 0,

    /// Initialize a new farm.
    pub fn init(allocator: std.mem.Allocator, opts: struct {
        id: u64,
        name: []const u8,
        num_plots: usize,
        plot_locations: []GridLocation2D,
    }) !Farm {
        std.debug.assert(opts.plot_locations.len == opts.num_plots);

        var plots = try std.ArrayList(Plot).initCapacity(allocator, opts.num_plots);
        var plot_locations = try std.ArrayList(GridLocation2D).initCapacity(allocator, opts.num_plots);
        var plot_seeds = try std.ArrayList(?Seed).initCapacity(allocator, opts.num_plots);
        var growth_stages = try std.ArrayList(?GrowthStage).initCapacity(allocator, opts.num_plots);
        var growth_start_times = try std.ArrayList(?i64).initCapacity(allocator, opts.num_plots);
        var plot_id_to_idx = std.AutoHashMap(u64, usize).init(allocator);

        for (0..opts.num_plots) |i| {
            const id = i + 1;
            try plots.append(.{ .id = id });
            try plot_id_to_idx.put(id, i);
            try plot_seeds.append(null);
            try growth_stages.append(null);
            try growth_start_times.append(null);
        }

        try plot_locations.appendSlice(opts.plot_locations);
        const name_copy = try allocator.dupe(u8, opts.name);

        return .{
            .allocator = allocator,
            .id = opts.id,
            .name = name_copy,
            .plots = plots,
            .plot_locations = plot_locations,
            .plot_seeds = plot_seeds,
            .growth_stages = growth_stages,
            .growth_start_times = growth_start_times,
            ._plot_id_to_idx = plot_id_to_idx,
        };
    }

    /// Free all dynamic memory associated with the farm.
    pub fn deinit(self: *Farm) void {
        for (self.plot_seeds.items) |maybe_seed| {
            if (maybe_seed) |seed| {
                self.allocator.free(seed.name);
                self.allocator.free(seed.description);
            }
        }
        self.plot_seeds.deinit();
        self.growth_stages.deinit();
        self.growth_start_times.deinit();
        self.plot_locations.deinit();
        self.plots.deinit();
        self._plot_id_to_idx.deinit();
        self.allocator.free(self.name);
    }

    /// Plant a seed in a specific plot.
    pub fn plantSeed(self: *Farm, plot_id: u64, seed: Seed) !void {
        const idx = self._plot_id_to_idx.get(plot_id) orelse return FarmError.InvalidPlotId;
        if (self.plot_seeds.items[idx] != null)
            return FarmError.PlotOccupied;

        const now = std.time.timestamp();
        const name_copy = try self.allocator.dupe(u8, seed.name);
        errdefer self.allocator.free(name_copy);
        const desc_copy = try self.allocator.dupe(u8, seed.description);
        errdefer self.allocator.free(desc_copy);

        self.plot_seeds.items[idx] = .{
            .name = name_copy,
            .description = desc_copy,
            .id = seed.id,
            .fruit_id = seed.fruit_id,
            .min_yield = seed.min_yield,
            .max_yield = seed.max_yield,
            .growth_curve = seed.growth_curve,
        };
        self.growth_start_times.items[idx] = now;
        self.growth_stages.items[idx] = .seed;
    }

    /// Checks if a plot has a seed
    pub fn hasSeed(self: *Farm, plot_id: u64) !bool {
        const idx = self._plot_id_to_idx.get(plot_id) orelse return FarmError.InvalidPlotId;
        return self.plot_seeds.items[idx] != null;
    }

    /// Remove any planted seed from the plot.
    pub fn clearPlot(self: *Farm, plot_id: u64) !void {
        const idx = self._plot_id_to_idx.get(plot_id) orelse return FarmError.InvalidPlotId;

        if (self.plot_seeds.items[idx]) |seed| {
            self.allocator.free(seed.name);
            self.allocator.free(seed.description);
        }

        self.plot_seeds.items[idx] = null;
        self.growth_stages.items[idx] = null;
        self.growth_start_times.items[idx] = null;
    }

    /// Get the location of a plot.
    pub fn getPlotLocation(self: *Farm, plot_id: u64) !GridLocation2D {
        const idx = self._plot_id_to_idx.get(plot_id) orelse return FarmError.InvalidPlotId;
        return self.plot_locations.items[idx];
    }

    /// Get the seed planted in a plot.
    pub fn getPlotSeed(self: *Farm, plot_id: u64) !?Seed {
        const idx = self._plot_id_to_idx.get(plot_id) orelse return FarmError.InvalidPlotId;
        return self.plot_seeds.items[idx];
    }

    /// Get the current growth stage of a plot.
    pub fn getPlotGrowthStage(self: *Farm, plot_id: u64) !?GrowthStage {
        const idx = self._plot_id_to_idx.get(plot_id) orelse return FarmError.InvalidPlotId;
        return self.growth_stages.items[idx];
    }

    /// Update all growth stages based on current timestamp.
    pub fn update(self: *Farm) void {
        const now = std.time.timestamp();
        self._last_update = now;

        for (self.plot_seeds.items, 0..) |maybe_seed, i| {
            if (maybe_seed) |seed| {
                const start_time = self.growth_start_times.items[i].?;
                const elapsed = now - start_time;
                const new_stage = seed.growth_curve.checkStage(elapsed);
                if (self.growth_stages.items[i].? != new_stage)
                    self.growth_stages.items[i] = new_stage;
            }
        }
    }

    /// Attempt to harvest a plot. Only works if stage is `fruiting`.
    pub fn harvestPlot(self: *Farm, plot_id: u64) !HarvestResult {
        const idx = self._plot_id_to_idx.get(plot_id) orelse return FarmError.InvalidPlotId;
        const stage = self.growth_stages.items[idx] orelse return FarmError.PlotNotHarvestable;
        if (stage != .fruiting) return FarmError.PlotNotHarvestable;

        const seed = self.plot_seeds.items[idx] orelse return FarmError.PlotNotHarvestable;

        var prng = std.Random.DefaultPrng.init(0);
        const result = prng.random().intRangeAtMost(u32, seed.min_yield, seed.max_yield);

        return .{ .yield = result, .fruit_id = seed.fruit_id };
    }
};

test "Farm init and deinit" {
    const allocator = std.testing.allocator;

    var farm = try Farm.init(allocator, .{
        .id = 1,
        .name = "Test Farm",
        .num_plots = 2,
        .plot_locations = @constCast(&[_]GridLocation2D{
            .{ .x = 0, .y = 0 },
            .{ .x = 1, .y = 1 },
        }),
    });
    defer farm.deinit();

    try std.testing.expectEqual(@as(u64, 1), farm.id);
    try std.testing.expectEqualStrings("Test Farm", farm.name);
    try std.testing.expectEqual(@as(usize, 2), farm.plots.items.len);
}

test "Farm plant, has and get seed" {
    const allocator = std.testing.allocator;

    var farm = try Farm.init(allocator, .{
        .id = 2,
        .name = "Test",
        .num_plots = 1,
        .plot_locations = @constCast(&[_]GridLocation2D{.{
            .x = 0,
            .y = 0,
        }}),
    });
    defer farm.deinit();

    const seed = Seed{
        .name = "Test Seed",
        .id = 100,
        .description = "Fast grow",
        .fruit_id = 200,
        .min_yield = 1,
        .max_yield = 5,
        .growth_curve = GrowthCurve.init(@constCast(&[_]i64{
            0,
            1,
            2,
            3,
            4,
            5,
        })),
    };

    try farm.plantSeed(1, seed);
    const planted = try farm.getPlotSeed(1);
    const has_seed = try farm.hasSeed(1);
    try std.testing.expect(planted != null);
    try std.testing.expectEqualStrings("Test Seed", planted.?.name);
    try std.testing.expect(has_seed);
}

test "Farm clearPlot removes seed" {
    const allocator = std.testing.allocator;

    var farm = try Farm.init(allocator, .{
        .id = 3,
        .name = "Test",
        .num_plots = 1,
        .plot_locations = @constCast(&[_]GridLocation2D{.{
            .x = 0,
            .y = 0,
        }}),
    });
    defer farm.deinit();

    const seed = Seed{
        .name = "Test",
        .id = 10,
        .description = "Desc",
        .fruit_id = 11,
        .min_yield = 1,
        .max_yield = 2,
        .growth_curve = GrowthCurve.init(@constCast(&[_]i64{
            0,
            1,
            2,
            3,
            4,
            5,
        })),
    };

    try farm.plantSeed(1, seed);
    try farm.clearPlot(1);
    const check = try farm.getPlotSeed(1);
    try std.testing.expectEqual(@as(?Seed, null), check);
}

test "getPlotLocation returns correct coordinates" {
    const allocator = std.testing.allocator;

    const loc = GridLocation2D{ .x = 9, .y = 3 };
    var farm = try Farm.init(allocator, .{
        .id = 4,
        .name = "Test",
        .num_plots = 1,
        .plot_locations = @constCast(&[_]GridLocation2D{loc}),
    });
    defer farm.deinit();

    const got = try farm.getPlotLocation(1);
    try std.testing.expectEqual(loc, got);
}

test "update changes growth stage" {
    const allocator = std.testing.allocator;

    var farm = try Farm.init(allocator, .{
        .id = 5,
        .name = "Update Test",
        .num_plots = 1,
        .plot_locations = @constCast(&[_]GridLocation2D{.{
            .x = 0,
            .y = 0,
        }}),
    });
    defer farm.deinit();

    const seed = Seed{
        .name = "Test",
        .id = 10,
        .description = "Desc",
        .fruit_id = 20,
        .min_yield = 1,
        .max_yield = 2,
        .growth_curve = GrowthCurve.init(@constCast(&[_]i64{
            0,
            1,
            2,
            3,
            4,
            5,
        })),
    };

    try farm.plantSeed(1, seed);
    farm.growth_start_times.items[0] = std.time.timestamp() - 3;
    farm.update();

    const stage = try farm.getPlotGrowthStage(1);
    try std.testing.expect(stage != null);
    try std.testing.expectEqual(GrowthStage.flowering, stage.?);
}

test "harvestPlot returns yield and fruit_id" {
    const allocator = std.testing.allocator;

    var farm = try Farm.init(allocator, .{
        .id = 6,
        .name = "Harvest Test",
        .num_plots = 1,
        .plot_locations = @constCast(&[_]GridLocation2D{.{
            .x = 0,
            .y = 0,
        }}),
    });
    defer farm.deinit();

    const seed = Seed{
        .name = "Harvest Seed",
        .id = 1,
        .description = "desc",
        .fruit_id = 77,
        .min_yield = 2,
        .max_yield = 4,
        .growth_curve = GrowthCurve.init(@constCast(&[_]i64{
            0,
            1,
            2,
            3,
            4,
            5,
        })),
    };

    try farm.plantSeed(1, seed);
    farm.growth_start_times.items[0] = std.time.timestamp() - 4;
    farm.update();

    const stage = try farm.getPlotGrowthStage(1);
    try std.testing.expectEqual(GrowthStage.fruiting, stage.?);

    const result = try farm.harvestPlot(1);
    try std.testing.expect(result.yield >= 2 and result.yield <= 4);
    try std.testing.expectEqual(@as(u64, 77), result.fruit_id);
}

test "planting in occupied plot fails" {
    const allocator = std.testing.allocator;

    var farm = try Farm.init(allocator, .{
        .id = 7,
        .name = "Fail Test",
        .num_plots = 1,
        .plot_locations = @constCast(&[_]GridLocation2D{.{
            .x = 0,
            .y = 0,
        }}),
    });
    defer farm.deinit();

    const seed = Seed{
        .name = "A",
        .id = 1,
        .description = "x",
        .fruit_id = 10,
        .min_yield = 1,
        .max_yield = 2,
        .growth_curve = GrowthCurve.init(@constCast(&[_]i64{
            0,
            1,
            2,
            3,
            4,
            5,
        })),
    };

    try farm.plantSeed(1, seed);
    const result = farm.plantSeed(1, seed);
    try std.testing.expectError(FarmError.PlotOccupied, result);
}
