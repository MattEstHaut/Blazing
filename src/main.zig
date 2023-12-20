const std = @import("std");
const perft = @import("perft.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip();
    const fen = args.next() orelse unreachable;
    const depth = try std.fmt.parseInt(u64, args.next() orelse unreachable, 10);

    try perft.perft(fen, depth);
}
