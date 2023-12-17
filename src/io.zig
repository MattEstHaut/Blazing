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

pub fn stringify(board: chess.Board) BoardString {
    var result = BoardString{ .string = undefined };
    result.write(masks.full, '.');
    result.write(board.white.pawns, 'P');
    result.write(board.white.knights, 'N');
    result.write(board.white.bishops, 'B');
    result.write(board.white.rooks, 'R');
    result.write(board.white.queens, 'Q');
    result.write(board.white.king, 'K');
    result.write(board.black.pawns, 'p');
    result.write(board.black.knights, 'n');
    result.write(board.black.bishops, 'b');
    result.write(board.black.rooks, 'r');
    result.write(board.black.queens, 'q');
    result.write(board.black.king, 'k');
    return result;
}
