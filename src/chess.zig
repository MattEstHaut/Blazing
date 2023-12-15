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

pub const Board = struct {
    white: PiecePositions,
    black: PiecePositions,

    en_passant: Bitboard,
    castling_rights: Bitboard,
    side_to_move: Color,

    halfmove_clock: u8,
    fullmove_number: u16,
};
