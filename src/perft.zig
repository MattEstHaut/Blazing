const chess = @import("chess.zig");
const movegen = @import("movegen.zig");
const io = @import("io.zig");
const std = @import("std");

fn getMNodesPerSec(nodes: u64, dt: i128) f64 {
    const mn_per_100_sec: f64 = @floatFromInt(nodes * 1000 * 100 / @as(u64, @intCast(dt)));
    return mn_per_100_sec / 100;
}

pub fn perft(fen: [*:0]const u8, depth: u64) !void {
    const board = try io.parse(fen);

    const t0 = std.time.nanoTimestamp();
    const nodes = movegen.explore(board, depth);
    const dt = std.time.nanoTimestamp() - t0;

    const mnodes_per_s = getMNodesPerSec(nodes, dt);

    std.debug.print("{d} nodes found in {d}ms ({d:.3} MNodes/s)\n", .{ nodes, @divTrunc(dt, 1000000), mnodes_per_s });
}
