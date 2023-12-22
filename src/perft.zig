const chess = @import("chess.zig");
const movegen = @import("movegen.zig");
const io = @import("io.zig");
const std = @import("std");

fn getMNodesPerSec(nodes: u64, dt: i128) f64 {
    const mn_per_100_sec: f64 = @floatFromInt(nodes * 1000 * 100 / @as(u64, @intCast(dt)));
    return mn_per_100_sec / 100;
}

fn count(board: chess.Board, depth: u64, result: *u64) void {
    result.* = movegen.perft(board, depth, true, null);
}

pub fn perft(fen: [*:0]const u8, depth: u64) !void {
    const stdout = std.io.getStdOut().writer();
    const board = try io.parse(fen);

    if (depth == 0) {
        try stdout.print("{d} node found\n", .{1});
        return;
    }

    const allocator = std.heap.page_allocator;
    var start_list = std.ArrayList(chess.Board).init(allocator);
    var thread_list = std.ArrayList(std.Thread).init(allocator);
    var result_list = std.ArrayList(u64).init(allocator);
    defer start_list.deinit();
    defer result_list.deinit();
    defer thread_list.deinit();

    _ = movegen.perft(board, 1, false, &start_list);

    if (depth == 1) {
        for (start_list.items) |result| {
            const diff = io.diff(board, result);
            try stdout.print("{s}\n", .{io.moveToString(diff)});
        }
        try stdout.print("{d} nodes found\n", .{start_list.items.len});
        return;
    }

    try result_list.appendNTimes(0, start_list.items.len);

    const t0 = std.time.nanoTimestamp();
    for (start_list.items, 0..) |start, id| {
        const thread = try std.Thread.spawn(.{}, count, .{ start, depth - 1, &result_list.items[id] });
        try thread_list.append(thread);
    }

    var nodes: u64 = 0;
    for (thread_list.items, 0..) |thread, id| {
        thread.join();
        const diff = io.diff(board, start_list.items[id]);
        nodes += result_list.items[id];
        try stdout.print("{s}: {d}\n", .{ io.moveToString(diff), result_list.items[id] });
    }
    const dt = std.time.nanoTimestamp() - t0;

    const mnodes_per_s = getMNodesPerSec(nodes, dt);
    std.debug.print("{d} nodes found in {d}ms ({d:.3} MNodes/s)\n", .{ nodes, @divTrunc(dt, 1000000), mnodes_per_s });
}

pub fn benchmark(fen: [*:0]const u8, depth: u64, n: u64) !void {
    const stdout = std.io.getStdOut().writer();
    const board = try io.parse(fen);

    var nodes: u64 = 0;

    const t0 = std.time.nanoTimestamp();
    for (0..n) |_| {
        nodes = movegen.perft(board, depth, true, null);
    }
    const dt = std.time.nanoTimestamp() - t0;

    const dt_mean = @divTrunc(dt, n);
    const mnodes_per_s = getMNodesPerSec(nodes, dt_mean);
    const dt_ms = @divTrunc(dt_mean, 1000000);

    try stdout.print("{s} at depth={d} : mean={d}ms ({d:.3}MNodes/sec) (n={d})\n", .{ fen, depth, dt_ms, mnodes_per_s, n });
}
