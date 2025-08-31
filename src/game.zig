const std = @import("std");

pub const Task = struct {
    func: *const fn (ctx: *anyopaque) anyerror!void,
    ctx: *anyopaque,
};

pub const TaskSystem = struct {
    allocator: std.mem.Allocator,
    pool: std.Thread.Pool,
    queue: std.ArrayList(Task),

};

pub const Game = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    worker_pool: std.Thread.Pool,
    task_queue: std.ArrayList(
}
