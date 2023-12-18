const chess = @import("chess.zig");
const masks = @import("masks.zig");

const Index = u6;

const row_masks = rowMasks();
const col_masks = colMasks();
const ascending_masks = ascendingMasks();
const descending_masks = descendingMasks();

inline fn kingLookup(king: chess.Bitboard) chess.Bitboard {
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

inline fn knightLookup(knight: chess.Bitboard) chess.Bitboard {
    const no_left = knight & masks.no_left;
    const no_left_double = knight & masks.no_left_double;
    const no_right = knight & masks.no_right;
    const no_right_double = knight & masks.no_right_double;
    var lookup = no_left >> 17;
    lookup |= no_left_double >> 10;
    lookup |= no_left_double << 6;
    lookup |= no_left << 15;
    lookup |= no_right << 17;
    lookup |= no_right_double << 10;
    lookup |= no_right_double >> 6;
    lookup |= no_right >> 15;
    return lookup;
}

fn rowMasks() [64]masks.Mask {
    var result: [64]masks.Mask = undefined;
    var index: Index = 0;
    while (true) : (index += 1) {
        const row_offset = index & 56;
        result[index] = masks.first_row << row_offset;
        if (index == 63) break;
    }
    return result;
}

fn colMasks() [64]masks.Mask {
    var result: [64]masks.Mask = undefined;
    var index: Index = 0;
    while (true) : (index += 1) {
        const col_index = index & 7;
        result[index] = masks.first_col << col_index;
        if (index == 63) break;
    }
    return result;
}

fn ascendingMasks() [64]masks.Mask {
    var result: [64]masks.Mask = undefined;
    var index: Index = 0;
    while (true) : (index += 1) {
        const col = index & 7;
        var ascending = masks.one << index;

        for (0..col) |_| {
            ascending |= ascending << 7;
        }
        for (col..7) |_| {
            ascending |= ascending >> 7;
        }

        result[index] = ascending;
        if (index == 63) break;
    }
    return result;
}

fn descendingMasks() [64]masks.Mask {
    var result: [64]masks.Mask = undefined;
    var index: Index = 0;
    while (true) : (index += 1) {
        const col = index & 7;
        var descending = masks.one << index;

        for (0..col) |_| {
            descending |= descending >> 9;
        }
        for (col..7) |_| {
            descending |= descending << 9;
        }

        result[index] = descending;
        if (index == 63) break;
    }
    return result;
}

inline fn hyperbolaQuintessence(s: chess.Bitboard, o: chess.Bitboard, m: masks.Mask) masks.Mask {
    @setRuntimeSafety(false);
    return (((o & m) - 2 * s) ^ @bitReverse(@bitReverse(o & m) - 2 * @bitReverse(s))) & m;
}

inline fn hyperbolaQuintessenceSimple(s: chess.Bitboard, o: chess.Bitboard, m: masks.Mask) masks.Mask {
    @setRuntimeSafety(false);
    return (o & m) ^ ((o & m) - 2 * s) & m;
}

inline fn hyperbolaQuintessenceReversed(s: chess.Bitboard, o: chess.Bitboard, m: masks.Mask) masks.Mask {
    @setRuntimeSafety(false);
    return (o & m) ^ @bitReverse(@bitReverse(o & m) - 2 * @bitReverse(s)) & m;
}

inline fn bishopLookup(bishop: chess.Bitboard, occupied: chess.Bitboard) chess.Bitboard {
    const bishop_index = @ctz(bishop);
    const ascending_mask = ascending_masks[bishop_index];
    const descending_mask = descending_masks[bishop_index];

    const ascending_lookup = hyperbolaQuintessence(bishop, occupied, ascending_mask);
    const descending_lookup = hyperbolaQuintessence(bishop, occupied, descending_mask);

    return ascending_lookup | descending_lookup;
}

pub inline fn rookLookup(rook: chess.Bitboard, occupied: chess.Bitboard) chess.Bitboard {
    const rook_index = @ctz(rook);
    const col_mask = col_masks[rook_index];
    const row_mask = row_masks[rook_index];

    const col_lookup = hyperbolaQuintessence(rook, occupied, col_mask);
    const row_lookup = hyperbolaQuintessence(rook, occupied, row_mask);

    return col_lookup | row_lookup;
}

inline fn queenLookup(queen: chess.Bitboard, occupied: chess.Bitboard) chess.Bitboard {
    return bishopLookup(queen, occupied) | rookLookup(queen, occupied);
}

inline fn pawnsForward(pawns: chess.Bitboard, occupied: chess.Bitboard, comptime color: chess.Color) chess.Bitboard {
    switch (color) {
        .white => return (pawns >> 8) & ~occupied,
        .black => return (pawns << 8) & ~occupied,
    }
}

inline fn pawnsDoubleForward(pawns: chess.Bitboard, occupied: chess.Bitboard, comptime color: chess.Color) chess.Bitboard {
    const pawns_double = if (color == .white) pawns & masks.last_row >> 8 else pawns & masks.first_row << 8;
    return pawnsForward(pawnsForward(pawns_double, occupied, color), occupied, color);
}

inline fn pawnCaptures(pawns: chess.Bitboard, comptime color: chess.Color) chess.Bitboard {
    const no_left = pawns & masks.no_left;
    const no_right = pawns & masks.no_right;
    switch (color) {
        .white => return no_left >> 9 | no_right >> 7,
        .black => return no_left << 7 | no_right << 9,
    }
}

inline fn attackedBy(board: chess.Board, occupied: chess.Bitboard, comptime color: chess.Color) masks.Mask {
    const attackers = if (color == .white) board.white else board.black;
    const blockers = occupied & ~(if (color == .white) board.black.king else board.white.king);

    var attacked = kingLookup(attackers.king);
    attacked |= knightLookup(attackers.knights);
    attacked |= pawnCaptures(attackers.pawns, color);

    var iter = masks.nextbit(attackers.bishops);
    while (iter.nextMask()) |bishop| {
        attacked |= bishopLookup(bishop, blockers);
    }

    iter = masks.nextbit(attackers.rooks);
    while (iter.nextMask()) |rook| {
        attacked |= rookLookup(rook, blockers);
    }

    iter = masks.nextbit(attackers.queens);
    while (iter.nextMask()) |queen| {
        attacked |= queenLookup(queen, blockers);
    }

    return attacked;
}

inline fn isAttackedBy(board: chess.Board, where: masks.Mask, occupied: chess.Bitboard, comptime color: chess.Color) bool {
    const attackers = if (color == .white) board.white else board.black;
    const blockers = occupied & ~(if (color == .white) board.black.king else board.white.king);

    if (kingLookup(attackers.king) & where != 0) return true;
    if (knightLookup(attackers.knights) & where != 0) return true;
    if (pawnCaptures(attackers.pawns, color) & where != 0) return true;

    const rooks = attackers.rooks | attackers.queens;
    if (rookLookup(where, blockers) & rooks != 0) return true;

    const bishops = attackers.bishops | attackers.queens;
    if (bishopLookup(where, blockers) & bishops != 0) return true;

    return false;
}

const PinCheckMasks = struct {
    check: masks.Mask,
    pin_hor: masks.Mask,
    pin_ver: masks.Mask,
    pin_asc: masks.Mask,
    pin_desc: masks.Mask,
    checks: u7,
};

pub inline fn createPinCheckMasks(board: chess.Board, occupied: chess.Bitboard, comptime color: chess.Color) PinCheckMasks {
    const king = if (color == .white) board.white.king else board.black.king;
    const enemy = if (color == .white) board.black else board.white;

    var all_masks: PinCheckMasks = undefined;
    all_masks.check = knightLookup(king) & enemy.knights;
    all_masks.check |= pawnCaptures(king, color) & enemy.pawns;
    all_masks.checks = @popCount(all_masks.check);

    all_masks.pin_hor = 0;
    all_masks.pin_ver = 0;
    all_masks.pin_asc = 0;
    all_masks.pin_desc = 0;

    const king_index = @ctz(king);
    const col_mask = col_masks[king_index];
    const row_mask = row_masks[king_index];
    const ascending_mask = ascending_masks[king_index];
    const descending_mask = descending_masks[king_index];

    const hv_attackers = enemy.rooks | enemy.queens;
    const ad_attackers = enemy.bishops | enemy.queens;

    const top = hyperbolaQuintessenceReversed(king, hv_attackers, col_mask);
    const bottom = hyperbolaQuintessence(king, hv_attackers, col_mask);
    const left = hyperbolaQuintessenceReversed(king, hv_attackers, row_mask);
    const right = hyperbolaQuintessence(king, hv_attackers, row_mask);

    const top_left = hyperbolaQuintessenceReversed(king, ad_attackers, descending_mask);
    const bottom_right = hyperbolaQuintessence(king, ad_attackers, descending_mask);
    const top_right = hyperbolaQuintessenceReversed(king, ad_attackers, ascending_mask);
    const bottom_left = hyperbolaQuintessence(king, ad_attackers, ascending_mask);

    if (top & enemy.rooks != 0) {
        const blockers = @popCount(top & occupied);
        if (blockers == 1) {
            all_masks.check |= top;
            all_masks.checks += 1;
        } else if (blockers == 2) {
            all_masks.pin_ver |= top;
        }
    }

    if (bottom & enemy.rooks != 0) {
        const blockers = @popCount(bottom & occupied);
        if (blockers == 1) {
            all_masks.check |= bottom;
            all_masks.checks += 1;
        } else if (blockers == 2) {
            all_masks.pin_ver |= bottom;
        }
    }

    if (left & enemy.rooks != 0) {
        const blockers = @popCount(left & occupied);
        if (blockers == 1) {
            all_masks.check |= left;
            all_masks.checks += 1;
        } else if (blockers == 2) {
            all_masks.pin_hor |= left;
        }
    }

    if (right & enemy.rooks != 0) {
        const blockers = @popCount(right & occupied);
        if (blockers == 1) {
            all_masks.check |= right;
            all_masks.checks += 1;
        } else if (blockers == 2) {
            all_masks.pin_hor |= right;
        }
    }

    if (top_left & enemy.bishops != 0) {
        const blockers = @popCount(top_left & occupied);
        if (blockers == 1) {
            all_masks.check |= top_left;
            all_masks.checks += 1;
        } else if (blockers == 2) {
            all_masks.pin_desc |= top_left;
        }
    }

    if (bottom_right & enemy.bishops != 0) {
        const blockers = @popCount(bottom_right & occupied);
        if (blockers == 1) {
            all_masks.check |= bottom_right;
            all_masks.checks += 1;
        } else if (blockers == 2) {
            all_masks.pin_desc |= bottom_right;
        }
    }

    if (top_right & enemy.bishops != 0) {
        const blockers = @popCount(top_right & occupied);
        if (blockers == 1) {
            all_masks.check |= top_right;
            all_masks.checks += 1;
        } else if (blockers == 2) {
            all_masks.pin_asc |= top_right;
        }
    }

    if (bottom_left & enemy.bishops != 0) {
        const blockers = @popCount(bottom_left & occupied);
        if (blockers == 1) {
            all_masks.check |= bottom_left;
            all_masks.checks += 1;
        } else if (blockers == 2) {
            all_masks.pin_asc |= bottom_left;
        }
    }

    if (all_masks.check == 0) all_masks.check = masks.full;

    return all_masks;
}

const Promotion = enum {
    queen,
    rook,
    bishop,
    knight,
    none,
};

inline fn reset(board: *chess.Board, where: masks.Mask, comptime color: chess.Color) void {
    const positions = if (color == chess.Color.white) &board.white else &board.black;
    const mask = ~where;
    positions.pawns &= mask;
    positions.knights &= mask;
    positions.bishops &= mask;
    positions.rooks &= mask;
    positions.queens &= mask;
    positions.king &= mask;
}

inline fn doKingMove(board: *chess.Board, dest: masks.Mask, comptime color: chess.Color) void {
    const positions = if (color == chess.Color.white) &board.white else &board.black;
    positions.king = dest;
    reset(board, positions.king, color);

    if (color == chess.Color.white) {
        board.castling_rights &= ~masks.castling_K;
    } else {
        board.castling_rights &= ~masks.castling_k;
    }
}

inline fn doKnightMove(board: *chess.Board, src: chess.Bitboard, dest: masks.Mask, comptime color: chess.Color) void {
    const positions = if (color == chess.Color.white) &board.white else &board.black;
    positions.knights ^= src | dest;
    reset(board, positions.knights, color);
    board.castling_rights &= ~dest;
}

inline fn doBishopMove(board: *chess.Board, src: chess.Bitboard, dest: masks.Mask, comptime color: chess.Color) void {
    const positions = if (color == chess.Color.white) &board.white else &board.black;
    positions.bishops ^= src | dest;
    reset(board, positions.bishops, color);
    board.castling_rights &= ~dest;
}

inline fn doRookMove(board: *chess.Board, src: chess.Bitboard, dest: masks.Mask, comptime color: chess.Color) void {
    const positions = if (color == chess.Color.white) &board.white else &board.black;
    const move = src | dest;
    positions.rooks ^= move;
    reset(board, positions.rooks, color);
    board.castling_rights &= ~move;
}

inline fn doQueenMove(board: *chess.Board, src: chess.Bitboard, dest: masks.Mask, comptime color: chess.Color) void {
    const positions = if (color == chess.Color.white) &board.white else &board.black;
    positions.queens ^= src | dest;
    reset(board, positions.queens, color);
    board.castling_rights &= ~dest;
}

inline fn doPawnForward(board: *chess.Board, dest: masks.Mask, comptime color: chess.Color) void {
    const positions = if (color == chess.Color.white) &board.white else &board.black;
    const src = if (color == chess.Color.white) dest << 8 else dest >> 8;
    positions.pawns ^= src | dest;
}

inline fn doPawnDoubleForward(board: *chess.Board, dest: masks.Mask, comptime color: chess.Color) void {
    const positions = if (color == chess.Color.white) &board.white else &board.black;
    const src = if (color == chess.Color.white) dest << 16 else dest >> 16;
    board.en_passant = if (color == chess.Color.white) dest << 8 else dest >> 8;
    positions.pawns ^= src | dest;
}

inline fn doPawnCapture(board: *chess.Board, src: chess.Bitboard, dest: masks.Mask, comptime color: chess.Color) void {
    const positions = if (color == chess.Color.white) &board.white else &board.black;
    const move = src | dest;
    positions.pawns ^= move;
    reset(board, dest, color);
    board.castling_rights &= ~dest;
}

inline fn doPromotion(board: *chess.Board, loc: chess.Bitboard, comptime piece: Promotion, comptime color: chess.Color) void {
    const positions = if (color == chess.Color.white) &board.white else &board.black;
    positions.pawns ^= loc;
    switch (piece) {
        .queen => positions.queens |= loc,
        .rook => positions.rooks |= loc,
        .bishop => positions.bishops |= loc,
        .knight => positions.knights |= loc,
        else => unreachable,
    }
}

inline fn reverseColor(comptime color: chess.Color) chess.Color {
    switch (color) {
        .white => return .black,
        .black => return .white,
    }
}

inline fn swapSides(board: *chess.Board, comptime color: chess.Color) void {
    board.side_to_move = reverseColor(color);
    board.en_passant = 0;
    board.halfmove_clock += 1;
}
