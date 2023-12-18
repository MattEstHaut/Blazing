const std = @import("std");
const debugger = @import("debugger.zig");

pub fn main() !void {
    try debugger.perftInfo("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", 5);
}
