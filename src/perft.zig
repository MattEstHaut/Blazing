const chess = @import("chess.zig");
const movegen = @import("movegen.zig");
const io = @import("io.zig");
const std = @import("std");

fn getMNodesPerSec(nodes: u64, dt: i128) f64 {
    const mn_per_100_sec: f64 = @floatFromInt(nodes * 1000 * 100 / @as(u64, @intCast(dt)));
    return mn_per_100_sec / 100;
}

pub fn perft(fen: [*:0]const u8, depth: u64) !void {
    const stdout = std.io.getStdOut().writer();
    const board = try io.parse(fen);

    const allocator = std.heap.page_allocator;
    var start_list = std.ArrayList(chess.Board).init(allocator);
    var result_list = std.ArrayList(u64).init(allocator);
    defer start_list.deinit();
    defer result_list.deinit();

    _ = movegen.explore(board, 1, false, &start_list);
    try result_list.appendNTimes(0, start_list.items.len);
    var total_nodes: u64 = 0;

    const t0 = std.time.nanoTimestamp();
    for (start_list.items, 0..) |start, id| {
        const diff = io.diff(board, start);
        const nodes = movegen.explore(start, depth - 1, true, null);
        try stdout.print("{s}: {d}\n", .{ io.moveToString(diff), nodes });
        result_list.items[id] = nodes;
        total_nodes += nodes;
    }
    const dt = std.time.nanoTimestamp() - t0;

    const mnodes_per_s = getMNodesPerSec(total_nodes, dt);
    std.debug.print("{d} nodes found in {d}ms ({d:.3} MNodes/s)\n", .{ total_nodes, @divTrunc(dt, 1000000), mnodes_per_s });
}
