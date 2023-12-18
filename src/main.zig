const std = @import("std");
const debugger = @import("debugger.zig");

pub fn main() !void {
    var args = std.process.args();

    _ = args.skip();
    const fen = args.next() orelse unreachable;
    const depth = try std.fmt.parseInt(u64, args.next() orelse unreachable, 10);
    const info = args.next() orelse "noinfo";

    if (cmp(info, "info")) {
        try debugger.perftInfo(fen, depth);
    } else if (cmp(info, "noinfo")) {
        try debugger.perft(fen, depth);
    } else {
        unreachable;
    }
}

fn cmp(str1: [:0]const u8, str2: [:0]const u8) bool {
    var index: usize = 0;
    while (true) {
        if (str1[index] == 0) return str2[index] == 0;
        if (str2[index] == 0) return false;
        if (str1[index] != str2[index]) return false;
        index += 1;
    }
    unreachable;
}
