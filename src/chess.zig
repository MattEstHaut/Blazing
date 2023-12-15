const masks = @import("masks.zig").masks;

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
