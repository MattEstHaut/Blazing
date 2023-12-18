const chess = @import("chess.zig");
const masks = @import("masks.zig");

const BoardString = struct {
    string: [71]u8,

    pub fn write(self: *const BoardString, where: masks.Mask, what: u8) BoardString {
        var result = self.*;
        var index: u64 = 0;
        var mask: masks.Mask = 1;

        while (true) : (mask <<= 1) {
            if (0 < mask & where) {
                result.string[index] = what;
            }
            index += 1;
            if (index % 9 == 8) {
                if (index == 71) break;
                result.string[index] = '\n';
                index += 1;
            }
        }

        return result;
    }
};

pub fn stringify(board: chess.Board) BoardString {
    var result = BoardString{ .string = undefined };
    result = result.write(masks.full, '.');
    result = result.write(board.white.pawns, 'P');
    result = result.write(board.white.knights, 'N');
    result = result.write(board.white.bishops, 'B');
    result = result.write(board.white.rooks, 'R');
    result = result.write(board.white.queens, 'Q');
    result = result.write(board.white.king, 'K');
    result = result.write(board.black.pawns, 'p');
    result = result.write(board.black.knights, 'n');
    result = result.write(board.black.bishops, 'b');
    result = result.write(board.black.rooks, 'r');
    result = result.write(board.black.queens, 'q');
    result = result.write(board.black.king, 'k');
    return result;
}

const FenError = error{
    InvalidCharacter,
    PrematureEnd,
    InvalidBoard,
    InvalidCastlingRights,
    InvalidEnPassant,
};

fn filter(char: u8, string: []const u8) ?u8 {
    for (string) |c| {
        if (char == c) return char;
    }
    return null;
}

const FenIterator = struct {
    fen: [*:0]const u8,
    index: usize,

    fn next(self: *FenIterator) !u8 {
        if (self.fen[self.index] == 0) return FenError.PrematureEnd;
        self.index += 1;
        return self.fen[self.index - 1];
    }

    fn look(self: *FenIterator) u8 {
        return self.fen[self.index];
    }

    fn skip(self: *FenIterator, char: u8) void {
        if (self.fen[self.index] != char) return;
        self.index += 1;
    }

    fn end(self: *FenIterator) bool {
        return self.fen[self.index] == 0;
    }
};

fn fenIter(fen: [*:0]const u8) FenIterator {
    return FenIterator{ .fen = fen, .index = 0 };
}

pub fn parse(fen: [*:0]const u8) !chess.Board {
    var iter = fenIter(fen);
    var board = chess.void_board;

    var board_index: u7 = 0;
    while (filter(try iter.next(), "PNBRQKpnbrqk/12345678")) |char| : (board_index += 1) {
        if (board_index > 63) return FenError.InvalidBoard;
        const mask = masks.one << @intCast(board_index);
        switch (char) {
            'P' => board.white.pawns |= mask,
            'N' => board.white.knights |= mask,
            'B' => board.white.bishops |= mask,
            'R' => board.white.rooks |= mask,
            'Q' => board.white.queens |= mask,
            'K' => board.white.king |= mask,
            'p' => board.black.pawns |= mask,
            'n' => board.black.knights |= mask,
            'b' => board.black.bishops |= mask,
            'r' => board.black.rooks |= mask,
            'q' => board.black.queens |= mask,
            'k' => board.black.king |= mask,
            '/' => {
                if (board_index % 8 != 0 or board_index == 0) return FenError.InvalidBoard;
                board_index -= 1;
            },
            else => board_index += @intCast(char - '1'),
        }
    }
    if (board_index != 64) return FenError.InvalidBoard;

    if (@popCount(board.white.pawns) > 8 or
        @popCount(board.white.knights) > 10 or
        @popCount(board.white.bishops) > 10 or
        @popCount(board.white.rooks) > 10 or
        @popCount(board.white.queens) > 9 or
        @popCount(board.white.king) != 1 or
        @popCount(board.black.pawns) > 8 or
        @popCount(board.black.knights) > 10 or
        @popCount(board.black.bishops) > 10 or
        @popCount(board.black.rooks) > 10 or
        @popCount(board.black.queens) > 9 or
        @popCount(board.black.king) != 1) return FenError.InvalidBoard;

    switch (try iter.next()) {
        'w' => board.side_to_move = chess.Color.white,
        'b' => board.side_to_move = chess.Color.black,
        else => return FenError.InvalidCharacter,
    }
    iter.skip(' ');

    if (iter.look() == '-') {
        iter.skip('-');
        iter.skip(' ');
    } else {
        var K: u8 = 0;
        var Q: u8 = 0;
        var k: u8 = 0;
        var q: u8 = 0;

        while (filter(try iter.next(), "KQkq")) |char| {
            switch (char) {
                'K' => K += 1,
                'Q' => Q += 1,
                'k' => k += 1,
                'q' => q += 1,
                else => unreachable,
            }
        }

        if (K > 1 or Q > 1 or k > 1 or q > 1) return FenError.InvalidCastlingRights;
        if (K == 1) board.castling_rights |= masks.castling_K;
        if (Q == 1) board.castling_rights |= masks.castling_Q;
        if (k == 1) board.castling_rights |= masks.castling_k;
        if (q == 1) board.castling_rights |= masks.castling_q;
    }

    const file = try iter.next();
    if (file == '-') {
        iter.skip('-');
    } else {
        const rank = try iter.next();
        if (file < 'a' or 'h' < file or (rank != '3' and rank != '6')) return FenError.InvalidEnPassant;
        board.en_passant = @as(u64, 1) << @as(u6, @intCast(file - 'a' + ('8' - rank) * 8));
    }

    if (!(iter.look() == ' ' or iter.end())) return FenError.InvalidCharacter;

    return board;
}

pub fn maskToSquare(mask: masks.Mask) [2]u8 {
    const index = @ctz(mask);
    const col = index & 7;
    const row = index / 8;
    return [2]u8{ 'a' + col, '8' - row };
}
