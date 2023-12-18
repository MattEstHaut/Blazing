const chess = @import("chess.zig");
const movegen = @import("movegen.zig");
const io = @import("io.zig");
const std = @import("std");

pub fn perftInfo(fen: [*:0]const u8, depth: u64) !void {
    const board = try io.parse(fen);

    const t0 = std.time.nanoTimestamp();
    const nodes = movegen.exploreEntry(movegen.explore, board, depth, perftInfoDetails, board);
    const dt = std.time.nanoTimestamp() - t0;

    const mnodes_per_s = getMNodesPerSec(nodes, dt);

    std.debug.print("{d} nodes found in {d}ms ({d:.3} MNodes/s)\n", .{ nodes, @divTrunc(dt, 1000000), mnodes_per_s });
}

fn perftInfoDetails(board: chess.Board, depth: u64, comptime color: chess.Color, _: anytype, arg: anytype) u64 {
    const nodes = movegen.explore(board, depth, color, movegen.explore, arg);
    const old = if (arg.side_to_move == chess.Color.white) arg.white else arg.black;
    const new = if (arg.side_to_move == chess.Color.white) board.white else board.black;
    const diff = new.occupied() ^ old.occupied();
    const src = old.occupied() & diff;
    const dst = new.occupied() & diff;
    std.debug.print("{s}{s}: {d}\n", .{ io.maskToSquare(src), io.maskToSquare(dst), nodes });
    return nodes;
}

fn getMNodesPerSec(nodes: u64, dt: i128) f64 {
    const mn_per_100_sec: f64 = @floatFromInt(nodes * 1000 * 100 / @as(u64, @intCast(dt)));
    return mn_per_100_sec / 100;
}

pub fn perft(fen: [*:0]const u8, depth: u64) !void {
    const board = try io.parse(fen);

    const t0 = std.time.nanoTimestamp();
    const nodes = movegen.exploreEntry(movegen.exploreThread, board, depth, null, null);
    const dt = std.time.nanoTimestamp() - t0;

    const mnodes_per_s = getMNodesPerSec(nodes, dt);

    std.debug.print("{d} nodes found in {d}ms ({d:.3} MNodes/s)\n", .{ nodes, @divTrunc(dt, 1000000), mnodes_per_s });
}
