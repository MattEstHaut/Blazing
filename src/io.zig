const chess = @import("chess.zig");
const masks = @import("masks.zig");

const BoardString = struct {
    string: [71]u8,

    fn write(self: *BoardString, where: masks.Mask, what: u8) void {
        var index: u64 = 0;
        var mask: masks.Mask = 1;

        while (true) : (mask <<= 1) {
            if (0 < mask & where) {
                self.string[index] = what;
            }
            index += 1;
            if (index % 9 == 8) {
                if (index == 71) break;
                self.string[index] = '\n';
                index += 1;
            }
        }
    }
};
