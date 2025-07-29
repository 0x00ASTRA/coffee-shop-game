const std = @import("std");

pub const RetrieveResult = struct {
    allocator: std.mem.Allocator,
    item_ids: std.ArrayList(u64),
    quantities: std.ArrayList(u32),

    pub fn init(allocator: std.mem.Allocator) !*RetrieveResult {
        const self = try allocator.create(RetrieveResult);
        self.* = .{
            .allocator = allocator,
            .item_ids = std.ArrayList(u64).init(allocator),
            .quantities = std.ArrayList(u32).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *RetrieveResult) void {
        self.item_ids.deinit();
        self.quantities.deinit();
        self.allocator.destroy(self);
    }
};

pub const StoreRemainder = struct {
    allocator: std.mem.Allocator,
    item_ids: std.ArrayList(u64),
    quantities: std.ArrayList(u32),
    stack_limits: std.ArrayList(u32),

    pub fn init(allocator: std.mem.Allocator) !*StoreRemainder {
        const self = try allocator.create(StoreRemainder);
        self.* = .{
            .allocator = allocator,
            .item_ids = std.ArrayList(u64).init(allocator),
            .quantities = std.ArrayList(u32).init(allocator),
            .stack_limits = std.ArrayList(u32).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *StoreRemainder) void {
        self.item_ids.deinit();
        self.quantities.deinit();
        self.stack_limits.deinit();
        self.allocator.destroy(self);
    }
};

pub const Storage = struct {
    allocator: std.mem.Allocator,
    num_slots: usize,
    item_ids: std.ArrayList(?u64),
    item_quantities: std.ArrayList(u32),
    stack_limits: std.ArrayList(u32),

    pub fn init(allocator: std.mem.Allocator, opts: struct { num_slots: usize }) !*Storage {
        const self = try allocator.create(Storage);
        var item_ids = std.ArrayList(?u64).init(allocator);
        try item_ids.appendNTimes(null, opts.num_slots);

        var item_quantities = std.ArrayList(u32).init(allocator);
        try item_quantities.appendNTimes(0, opts.num_slots);

        var stack_limits = std.ArrayList(u32).init(allocator);
        try stack_limits.appendNTimes(0, opts.num_slots);

        self.* = .{
            .allocator = allocator,
            .num_slots = opts.num_slots,
            .item_ids = item_ids,
            .item_quantities = item_quantities,
            .stack_limits = stack_limits,
        };
        return self;
    }

    pub fn deinit(self: *Storage) void {
        self.item_ids.deinit();
        self.item_quantities.deinit();
        self.stack_limits.deinit();
        self.allocator.destroy(self);
    }

    pub fn nextAvailableSlot(self: *const Storage) ?usize {
        for (self.item_ids.items, 0..) |item, i| {
            if (item == null) {
                return i;
            }
        }
        return null;
    }

    pub fn isSlotAvailable(self: *const Storage, slot_id: usize) !bool {
        if (slot_id >= self.num_slots) {
            return error.IndexOutOfRange;
        }
        return self.item_ids.items[slot_id] == null;
    }

    pub fn getItemQuantity(self: *const Storage, item_id: u64) u32 {
        var total: u32 = 0;
        for (self.item_ids.items, self.item_quantities.items) |id, qty| {
            if (id) |i_id| {
                if (i_id == item_id) {
                    total += qty;
                }
            }
        }
        return total;
    }

    pub fn isSlotFull(self: *const Storage, slot_id: usize) !bool {
        if (slot_id >= self.num_slots) {
            return error.IndexOutOfRange;
        }
        if (self.item_ids.items[slot_id] == null) {
            return false;
        }
        return self.item_quantities.items[slot_id] >= self.stack_limits.items[slot_id];
    }

    pub fn store(self: *Storage, allocator: std.mem.Allocator, opts: struct { item_ids: []const u64, quantities: []const u32, stack_limits: []const u32 }) !*StoreRemainder {
        std.debug.assert(opts.item_ids.len == opts.quantities.len and opts.item_ids.len == opts.stack_limits.len);

        // Use an ArenaAllocator for temporary, mutable copies of the input.
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        // Clone the quantities to a mutable slice we can safely modify.
        var qtys = try std.ArrayList(u32).initCapacity(arena_allocator, opts.quantities.len);
        try qtys.appendSlice(opts.quantities);

        // Pass 1: Attempt to stack with existing items.
        for (opts.item_ids, qtys.items) |item_id, *qty| {
            if (qty.* == 0) continue;
            for (0..self.num_slots) |slot_idx| {
                if (self.item_ids.items[slot_idx] == item_id) {
                    if (try self.isSlotFull(slot_idx)) continue;
                    const space_left = self.stack_limits.items[slot_idx] - self.item_quantities.items[slot_idx];
                    const amount_to_add = @min(qty.*, space_left);
                    self.item_quantities.items[slot_idx] += amount_to_add;
                    qty.* -= amount_to_add;
                    if (qty.* == 0) break;
                }
            }
        }

        // Pass 2: Fill empty slots with remaining items.
        for (opts.item_ids, qtys.items, opts.stack_limits) |item_id, *qty, stack_limit| {
            if (qty.* == 0) continue;
            while (self.nextAvailableSlot()) |slot_idx| {
                const amount_to_add = @min(qty.*, stack_limit);
                self.item_ids.items[slot_idx] = item_id;
                self.item_quantities.items[slot_idx] = amount_to_add;
                self.stack_limits.items[slot_idx] = stack_limit;
                qty.* -= amount_to_add;
                if (qty.* == 0) break;
            }
        }

        // Collect any items that couldn't be stored.
        const remainder = try StoreRemainder.init(allocator);
        for (opts.item_ids, qtys.items, opts.stack_limits) |id, qty, limit| {
            if (qty > 0) {
                try remainder.item_ids.append(id);
                try remainder.quantities.append(qty);
                try remainder.stack_limits.append(limit);
            }
        }
        return remainder;
    }

    pub fn put(self: *Storage, allocator: std.mem.Allocator, opts: struct { slot_id: usize, item_id: u64, quantity: u32, stack_limit: u32 }) !*StoreRemainder {
        if (opts.slot_id >= self.num_slots) {
            return error.IndexOutOfRange;
        }
        const remainder = try StoreRemainder.init(allocator);

        // If slot is occupied, add its contents to the remainder.
        if (self.item_ids.items[opts.slot_id]) |old_id| {
            try remainder.item_ids.append(old_id);
            try remainder.quantities.append(self.item_quantities.items[opts.slot_id]);
            try remainder.stack_limits.append(self.stack_limits.items[opts.slot_id]);
        }

        // Place the new item in the slot.
        self.item_ids.items[opts.slot_id] = opts.item_id;
        self.item_quantities.items[opts.slot_id] = opts.quantity;
        self.stack_limits.items[opts.slot_id] = opts.stack_limit;

        return remainder;
    }

    pub fn retrieve(self: *Storage, allocator: std.mem.Allocator, opts: struct { item_ids: []const u64, quantities: []const u32 }) !*RetrieveResult {
        std.debug.assert(opts.item_ids.len == opts.quantities.len);
        const result = try RetrieveResult.init(allocator);

        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        // Clone the quantities to a mutable slice we can safely modify.
        var qtys_to_remove = try std.ArrayList(u32).initCapacity(arena_allocator, opts.quantities.len);
        try qtys_to_remove.appendSlice(opts.quantities);

        for (opts.item_ids, qtys_to_remove.items) |id_to_find, *qty_to_remove| {
            if (qty_to_remove.* == 0) continue;
            var retrieved_total: u32 = 0;
            for (0..self.num_slots) |slot_idx| {
                if (qty_to_remove.* == 0) break;
                if (self.item_ids.items[slot_idx]) |current_id| {
                    if (current_id == id_to_find) {
                        const amount_to_take = @min(qty_to_remove.*, self.item_quantities.items[slot_idx]);
                        self.item_quantities.items[slot_idx] -= amount_to_take;
                        qty_to_remove.* -= amount_to_take;
                        retrieved_total += amount_to_take;

                        if (self.item_quantities.items[slot_idx] == 0) {
                            self.item_ids.items[slot_idx] = null;
                            self.stack_limits.items[slot_idx] = 0;
                        }
                    }
                }
            }
            if (retrieved_total > 0) {
                try result.item_ids.append(id_to_find);
                try result.quantities.append(retrieved_total);
            }
        }
        return result;
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

test "storage system" {
    var storage = try Storage.init(test_allocator, .{ .num_slots = 3 });
    defer storage.deinit();

    // 1. Store items in empty storage
    const quantities1: []const u32 = &.{ 64, 10 };
    const remainder1 = try storage.store(test_allocator, .{
        .item_ids = &.{ 1, 2 },
        .quantities = quantities1,
        .stack_limits = &.{ 64, 64 },
    });
    defer remainder1.deinit();

    try expectEq(0, remainder1.item_ids.items.len);
    try expectEq(64, storage.getItemQuantity(1));
    try expectEq(10, storage.getItemQuantity(2));
    try expectEq(2, storage.nextAvailableSlot().?);

    // 2. Stack more items
    const quantities2: []const u32 = &.{30};
    const remainder2 = try storage.store(test_allocator, .{
        .item_ids = &.{2},
        .quantities = quantities2,
        .stack_limits = &.{64},
    });
    defer remainder2.deinit();
    try expectEq(40, storage.getItemQuantity(2));
    try expectEq(0, remainder2.item_ids.items.len);

    // 3. Store until full and get remainder
    const quantities3: []const u32 = &.{ 100, 50 };
    const remainder3 = try storage.store(test_allocator, .{
        .item_ids = &.{ 3, 4 },
        .quantities = quantities3,
        .stack_limits = &.{ 64, 32 },
    });
    defer remainder3.deinit();

    try expectEq(64, storage.getItemQuantity(3));
    try expect(storage.getItemQuantity(4) == 0);
    try expectEq(2, remainder3.item_ids.items.len);
    try expectEq(3, remainder3.item_ids.items[0]);
    try expectEq(36, remainder3.quantities.items[0]);
    try expectEq(4, remainder3.item_ids.items[1]);
    try expectEq(50, remainder3.quantities.items[1]);

    // 4. Retrieve items
    const retrieve_qtys1: []const u32 = &.{ 20, 15 };
    const result1 = try storage.retrieve(test_allocator, .{ .item_ids = &.{ 1, 2 }, .quantities = retrieve_qtys1 });
    defer result1.deinit();

    try expectEq(44, storage.getItemQuantity(1));
    try expectEq(25, storage.getItemQuantity(2));

    // 5. Retrieve more than available (clears the stack)
    const retrieve_qtys2: []const u32 = &.{100};
    const result2 = try storage.retrieve(test_allocator, .{ .item_ids = &.{1}, .quantities = retrieve_qtys2 });
    defer result2.deinit();

    try expectEq(1, result2.item_ids.items.len);
    try expectEq(44, result2.quantities.items[0]);
    try expectEq(0, storage.getItemQuantity(1));
    try expect(try storage.isSlotAvailable(0));

    // 6. Put item in specific slot (and get remainder)
    const remainder4 = try storage.put(test_allocator, .{ .slot_id = 1, .item_id = 5, .quantity = 16, .stack_limit = 32 });
    defer remainder4.deinit();

    try expectEq(5, storage.item_ids.items[1].?);
    try expectEq(1, remainder4.item_ids.items.len);
    try expectEq(2, remainder4.item_ids.items[0]);
    try expectEq(25, remainder4.quantities.items[0]);
}
