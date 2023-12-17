const masks = @import("masks.zig");

pub const Bitboard = u64;

const PiecePositions = struct {
    pawns: Bitboard,
    knights: Bitboard,
    bishops: Bitboard,
    rooks: Bitboard,
    queens: Bitboard,
    king: Bitboard,
};

pub const Color = enum {
    white,
    black,
};

pub const CastlingRights = struct {
    K: bool,
    Q: bool,
    k: bool,
    q: bool,
};

pub const Board = struct {
    white: PiecePositions,
    black: PiecePositions,

    en_passant: Bitboard,
    castling_rights: Bitboard,
    side_to_move: Color,

    halfmove_clock: u8,
    fullmove_number: u16,

    fn getCastlingRights(self: *Board) CastlingRights {
        return CastlingRights{
            .K = self.castling_rights & masks.castling_K,
            .Q = self.castling_rights & masks.castling_Q,
            .k = self.castling_rights & masks.castling_k,
            .q = self.castling_rights & masks.castling_q,
        };
    }

    fn setCastlingRights(self: *Board, rights: CastlingRights) void {
        self.castling_rights = 0;
        if (rights.K) self.castling_rights |= masks.castling_K;
        if (rights.Q) self.castling_rights |= masks.castling_Q;
        if (rights.k) self.castling_rights |= masks.castling_k;
        if (rights.q) self.castling_rights |= masks.castling_q;
    }
};

pub const void_board = Board{
    .white = PiecePositions{
        .pawns = 0,
        .knights = 0,
        .bishops = 0,
        .rooks = 0,
        .queens = 0,
        .king = 0,
    },
    .black = PiecePositions{
        .pawns = 0,
        .knights = 0,
        .bishops = 0,
        .rooks = 0,
        .queens = 0,
        .king = 0,
    },
    .en_passant = 0,
    .castling_rights = 0,
    .side_to_move = Color.white,
    .halfmove_clock = 0,
    .fullmove_number = 0,
};

inline fn kingLookup(king: Bitboard) Bitboard {
    const no_left = king & masks.no_left;
    const no_right = king & masks.no_right;
    var lookup = king >> 8;
    lookup |= no_left >> 9;
    lookup |= no_left >> 1;
    lookup |= no_left << 7;
    lookup |= king << 8;
    lookup |= no_right << 9;
    lookup |= no_right << 1;
    lookup |= no_right >> 7;
    return lookup;
}
