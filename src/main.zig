const std = @import("std");
const debugger = @import("debugger.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const fen = args[1];
    const depth = try std.fmt.parseInt(u64, args[2], 10);

    try debugger.perftInfo(fen, depth);
}
