const std = @import("std");
const perft = @import("perft.zig");

pub fn main() !void {
    var args = std.process.args();

    _ = args.skip();
    const fen = args.next() orelse unreachable;
    const depth = try std.fmt.parseInt(u64, args.next() orelse unreachable, 10);

    try perft.perft(fen, depth);
}
