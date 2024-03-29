const std = @import("std");
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
    var lookup = king;
    lookup |= no_left >> 1;
    lookup |= no_right << 1;
    lookup |= lookup << 8 | lookup >> 8;
    return lookup - king;
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

inline fn rookLookup(rook: chess.Bitboard, occupied: chess.Bitboard) chess.Bitboard {
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

inline fn createPinCheckMasks(board: chess.Board, occupied: chess.Bitboard, comptime color: chess.Color) PinCheckMasks {
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
    const bottom = hyperbolaQuintessenceSimple(king, hv_attackers, col_mask);
    const left = hyperbolaQuintessenceReversed(king, hv_attackers, row_mask);
    const right = hyperbolaQuintessenceSimple(king, hv_attackers, row_mask);

    const top_left = hyperbolaQuintessenceReversed(king, ad_attackers, descending_mask);
    const bottom_right = hyperbolaQuintessenceSimple(king, ad_attackers, descending_mask);
    const top_right = hyperbolaQuintessenceReversed(king, ad_attackers, ascending_mask);
    const bottom_left = hyperbolaQuintessenceSimple(king, ad_attackers, ascending_mask);

    if (top & hv_attackers != 0) {
        const blockers = @popCount(top & occupied);
        if (blockers == 1) {
            all_masks.check |= top;
            all_masks.checks += 1;
        } else if (blockers == 2) {
            all_masks.pin_ver |= top;
        }
    }

    if (bottom & hv_attackers != 0) {
        const blockers = @popCount(bottom & occupied);
        if (blockers == 1) {
            all_masks.check |= bottom;
            all_masks.checks += 1;
        } else if (blockers == 2) {
            all_masks.pin_ver |= bottom;
        }
    }

    if (left & hv_attackers != 0) {
        const blockers = @popCount(left & occupied);
        if (blockers == 1) {
            all_masks.check |= left;
            all_masks.checks += 1;
        } else if (blockers == 2) {
            all_masks.pin_hor |= left;
        }
    }

    if (right & hv_attackers != 0) {
        const blockers = @popCount(right & occupied);
        if (blockers == 1) {
            all_masks.check |= right;
            all_masks.checks += 1;
        } else if (blockers == 2) {
            all_masks.pin_hor |= right;
        }
    }

    if (top_left & ad_attackers != 0) {
        const blockers = @popCount(top_left & occupied);
        if (blockers == 1) {
            all_masks.check |= top_left;
            all_masks.checks += 1;
        } else if (blockers == 2) {
            all_masks.pin_desc |= top_left;
        }
    }

    if (bottom_right & ad_attackers != 0) {
        const blockers = @popCount(bottom_right & occupied);
        if (blockers == 1) {
            all_masks.check |= bottom_right;
            all_masks.checks += 1;
        } else if (blockers == 2) {
            all_masks.pin_desc |= bottom_right;
        }
    }

    if (top_right & ad_attackers != 0) {
        const blockers = @popCount(top_right & occupied);
        if (blockers == 1) {
            all_masks.check |= top_right;
            all_masks.checks += 1;
        } else if (blockers == 2) {
            all_masks.pin_asc |= top_right;
        }
    }

    if (bottom_left & ad_attackers != 0) {
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

pub const Promotion = enum {
    queen,
    rook,
    bishop,
    knight,
    none,
};

pub const Move = struct {
    from: masks.Mask,
    to: masks.Mask,
    promotion: Promotion,
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
    reset(board, positions.king, reverseColor(color));

    if (color == chess.Color.white) {
        board.castling_rights &= ~masks.castling_K;
    } else {
        board.castling_rights &= ~masks.castling_k;
    }
}

inline fn doKnightMove(board: *chess.Board, src: chess.Bitboard, dest: masks.Mask, comptime color: chess.Color) void {
    const positions = if (color == chess.Color.white) &board.white else &board.black;
    positions.knights ^= src | dest;
    reset(board, positions.knights, reverseColor(color));
    board.castling_rights &= ~dest;
}

inline fn doBishopMove(board: *chess.Board, src: chess.Bitboard, dest: masks.Mask, comptime color: chess.Color) void {
    const positions = if (color == chess.Color.white) &board.white else &board.black;
    positions.bishops ^= src | dest;
    reset(board, positions.bishops, reverseColor(color));
    board.castling_rights &= ~dest;
}

inline fn doRookMove(board: *chess.Board, src: chess.Bitboard, dest: masks.Mask, comptime color: chess.Color) void {
    const positions = if (color == chess.Color.white) &board.white else &board.black;
    const move = src | dest;
    positions.rooks ^= move;
    reset(board, positions.rooks, reverseColor(color));
    board.castling_rights &= ~move;
}

inline fn doQueenMove(board: *chess.Board, src: chess.Bitboard, dest: masks.Mask, comptime color: chess.Color) void {
    const positions = if (color == chess.Color.white) &board.white else &board.black;
    positions.queens ^= src | dest;
    reset(board, positions.queens, reverseColor(color));
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
    reset(board, dest, reverseColor(color));
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

inline fn doEnPassant(board: *chess.Board, src: chess.Bitboard, comptime color: chess.Color) void {
    const positions = if (color == chess.Color.white) &board.white else &board.black;
    const dest = board.en_passant;
    positions.pawns ^= src | dest;
    const captured = if (color == chess.Color.white) dest << 8 else dest >> 8;
    const enemy = if (color == chess.Color.white) &board.black else &board.white;
    enemy.pawns ^= captured;
}

inline fn reverseColor(comptime color: chess.Color) chess.Color {
    switch (color) {
        .white => return .black,
        .black => return .white,
    }
}

inline fn swapSides(board: *chess.Board, comptime color: chess.Color) void {
    board.side_to_move = reverseColor(color);
    board.en_passant &= if (color == chess.Color.white) masks.last_row >> 16 else masks.first_row << 16;
    board.halfmove_clock += 1;
}

inline fn castlingRightK(board: chess.Board, occupied: chess.Bitboard, comptime color: chess.Color) bool {
    if (board.castling_rights & masks.castling_K == masks.castling_K) {
        if (occupied & (masks.one << 61 | masks.one << 62) == 0) {
            if (!isAttackedBy(board, masks.one << 60, occupied, reverseColor(color))) {
                if (!isAttackedBy(board, masks.one << 61, occupied, reverseColor(color))) {
                    if (!isAttackedBy(board, masks.one << 62, occupied, reverseColor(color))) {
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

inline fn castlingRightQ(board: chess.Board, occupied: chess.Bitboard, comptime color: chess.Color) bool {
    if (board.castling_rights & masks.castling_Q == masks.castling_Q) {
        if (occupied & (masks.one << 59 | masks.one << 58 | masks.one << 57) == 0) {
            if (!isAttackedBy(board, masks.one << 60, occupied, reverseColor(color))) {
                if (!isAttackedBy(board, masks.one << 59, occupied, reverseColor(color))) {
                    if (!isAttackedBy(board, masks.one << 58, occupied, reverseColor(color))) {
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

inline fn castlingRightBlackK(board: chess.Board, occupied: chess.Bitboard, comptime color: chess.Color) bool {
    if (board.castling_rights & masks.castling_k == masks.castling_k) {
        if (occupied & (masks.one << 5 | masks.one << 6) == 0) {
            if (!isAttackedBy(board, masks.one << 4, occupied, reverseColor(color))) {
                if (!isAttackedBy(board, masks.one << 5, occupied, reverseColor(color))) {
                    if (!isAttackedBy(board, masks.one << 6, occupied, reverseColor(color))) {
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

inline fn castlingRightBlackQ(board: chess.Board, occupied: chess.Bitboard, comptime color: chess.Color) bool {
    if (board.castling_rights & masks.castling_q == masks.castling_q) {
        if (occupied & (masks.one << 3 | masks.one << 2 | masks.one << 1) == 0) {
            if (!isAttackedBy(board, masks.one << 2, occupied, reverseColor(color))) {
                if (!isAttackedBy(board, masks.one << 3, occupied, reverseColor(color))) {
                    if (!isAttackedBy(board, masks.one << 4, occupied, reverseColor(color))) {
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

fn countMoves(board: chess.Board, comptime color: chess.Color) u64 {
    var nodes: u64 = 0;

    const positions = if (color == chess.Color.white) board.white else board.black;
    const enemy = if (color == chess.Color.white) board.black.occupied() else board.white.occupied();
    const occupied = positions.occupied() | enemy;
    const empty_or_enemy = ~occupied | enemy;

    const pin_and_check = createPinCheckMasks(board, occupied, color);
    const en_passant_check = (pawnsForward(pin_and_check.check, 0, color) & board.en_passant) | pin_and_check.check;

    {
        const lookup = kingLookup(positions.king) & empty_or_enemy;
        var dest_iter = masks.nextbit(lookup);
        while (dest_iter.nextMask()) |dest| {
            if (!isAttackedBy(board, dest, occupied, reverseColor(color))) nodes += 1;
        }
    }

    if (pin_and_check.checks > 1) return nodes;

    const pin_hv = pin_and_check.pin_hor | pin_and_check.pin_ver;
    const pin_ad = pin_and_check.pin_asc | pin_and_check.pin_desc;

    {
        var src_iter = masks.nextbit(positions.knights & ~(pin_hv | pin_ad));
        while (src_iter.nextMask()) |src| {
            const lookup = knightLookup(src) & empty_or_enemy & pin_and_check.check;
            nodes += @popCount(lookup);
        }
    }

    {
        var src_iter = masks.nextbit(positions.bishops & ~pin_hv);
        while (src_iter.nextMask()) |src| {
            var pin_mask: masks.Mask = masks.full;
            if (pin_and_check.pin_asc & src != 0) {
                pin_mask = pin_and_check.pin_asc;
            } else if (pin_and_check.pin_desc & src != 0) {
                pin_mask = pin_and_check.pin_desc;
            }

            const lookup = bishopLookup(src, occupied) & empty_or_enemy & pin_and_check.check & pin_mask;
            nodes += @popCount(lookup);
        }
    }

    {
        var src_iter = masks.nextbit(positions.rooks & ~pin_ad);
        while (src_iter.nextMask()) |src| {
            var pin_mask: masks.Mask = masks.full;
            if (pin_and_check.pin_hor & src != 0) {
                pin_mask = pin_and_check.pin_hor;
            } else if (pin_and_check.pin_ver & src != 0) {
                pin_mask = pin_and_check.pin_ver;
            }

            const lookup = rookLookup(src, occupied) & empty_or_enemy & pin_and_check.check & pin_mask;
            nodes += @popCount(lookup);
        }
    }

    {
        var src_iter = masks.nextbit(positions.queens);
        while (src_iter.nextMask()) |src| {
            var pin_mask: masks.Mask = masks.full;
            if (pin_and_check.pin_hor & src != 0) {
                pin_mask = pin_and_check.pin_hor;
            } else if (pin_and_check.pin_ver & src != 0) {
                pin_mask = pin_and_check.pin_ver;
            } else if (pin_and_check.pin_asc & src != 0) {
                pin_mask = pin_and_check.pin_asc;
            } else if (pin_and_check.pin_desc & src != 0) {
                pin_mask = pin_and_check.pin_desc;
            }

            const lookup = queenLookup(src, occupied) & empty_or_enemy & pin_and_check.check & pin_mask;
            nodes += @popCount(lookup);
        }
    }

    {
        const prom_row = if (color == chess.Color.white) masks.first_row else masks.last_row;

        const src = positions.pawns & ~(pin_ad | pin_and_check.pin_hor);
        const lookup = pawnsForward(src, occupied, color) & pin_and_check.check;
        nodes += @popCount(lookup);
        nodes += @popCount(lookup & prom_row) * 3;
    }

    {
        const src = positions.pawns & ~(pin_ad | pin_and_check.pin_hor);
        const lookup = pawnsDoubleForward(src, occupied, color) & pin_and_check.check;
        nodes += @popCount(lookup);
    }

    {
        var src_iter = masks.nextbit(positions.pawns & ~pin_hv);
        while (src_iter.nextMask()) |src| {
            var pin_mask: masks.Mask = masks.full;
            if (pin_and_check.pin_asc & src != 0) {
                pin_mask = pin_and_check.pin_asc;
            } else if (pin_and_check.pin_desc & src != 0) {
                pin_mask = pin_and_check.pin_desc;
            }

            const dest = pawnCaptures(src, color) & pin_and_check.check & pin_mask & enemy;
            if (dest & (masks.first_row | masks.last_row) != 0) {
                nodes += @popCount(dest) * 4;
            } else {
                nodes += @popCount(dest);
            }
        }
    }

    {
        const lookup = pawnCaptures(board.en_passant & en_passant_check, reverseColor(color));
        var src_iter = masks.nextbit(positions.pawns & ~pin_hv & lookup);
        while (src_iter.nextMask()) |src| {
            var child = board;
            doEnPassant(&child, src, color);
            swapSides(&child, color);
            const child_occupied = child.white.occupied() | child.black.occupied();
            if (!isAttackedBy(child, positions.king, child_occupied, reverseColor(color))) nodes += 1;
        }
    }

    {
        if (color == chess.Color.white) {
            if (castlingRightK(board, occupied, color)) nodes += 1;
            if (castlingRightQ(board, occupied, color)) nodes += 1;
        } else {
            if (castlingRightBlackK(board, occupied, color)) nodes += 1;
            if (castlingRightBlackQ(board, occupied, color)) nodes += 1;
        }
    }

    return nodes;
}

pub fn generate(board: chess.Board, list: *std.ArrayList(chess.Board)) u64 {
    switch (board.side_to_move) {
        .white => return generateColorMoves(board, .white, list),
        .black => return generateColorMoves(board, .black, list),
    }
}

fn generateColorMoves(board: chess.Board, comptime color: chess.Color, list: *std.ArrayList(chess.Board)) u64 {
    const positions = if (color == chess.Color.white) board.white else board.black;
    const enemy = if (color == chess.Color.white) board.black.occupied() else board.white.occupied();
    const occupied = positions.occupied() | enemy;
    const empty_or_enemy = ~occupied | enemy;

    var nodes: u64 = 0;

    const pin_and_check = createPinCheckMasks(board, occupied, color);
    const en_passant_check = (pawnsForward(pin_and_check.check, 0, color) & board.en_passant) | pin_and_check.check;

    {
        const lookup = kingLookup(positions.king) & empty_or_enemy;
        var dest_iter = masks.nextbit(lookup);
        while (dest_iter.nextMask()) |dest| {
            if (isAttackedBy(board, dest, occupied, reverseColor(color))) continue;
            var child = board;
            doKingMove(&child, dest, color);
            swapSides(&child, color);
            list.append(child) catch unreachable;
            nodes += 1;
        }
    }

    if (pin_and_check.checks > 1) return nodes;

    const pin_hv = pin_and_check.pin_hor | pin_and_check.pin_ver;
    const pin_ad = pin_and_check.pin_asc | pin_and_check.pin_desc;

    {
        var src_iter = masks.nextbit(positions.knights & ~(pin_hv | pin_ad));
        while (src_iter.nextMask()) |src| {
            const lookup = knightLookup(src) & empty_or_enemy & pin_and_check.check;
            var dest_iter = masks.nextbit(lookup);
            while (dest_iter.nextMask()) |dest| {
                var child = board;
                doKnightMove(&child, src, dest, color);
                swapSides(&child, color);
                list.append(child) catch unreachable;
                nodes += 1;
            }
        }
    }

    {
        var src_iter = masks.nextbit(positions.bishops & ~pin_hv);
        while (src_iter.nextMask()) |src| {
            var pin_mask: masks.Mask = masks.full;
            if (pin_and_check.pin_asc & src != 0) {
                pin_mask = pin_and_check.pin_asc;
            } else if (pin_and_check.pin_desc & src != 0) {
                pin_mask = pin_and_check.pin_desc;
            }

            const lookup = bishopLookup(src, occupied) & empty_or_enemy & pin_and_check.check & pin_mask;
            var dest_iter = masks.nextbit(lookup);
            while (dest_iter.nextMask()) |dest| {
                var child = board;
                doBishopMove(&child, src, dest, color);
                swapSides(&child, color);
                list.append(child) catch unreachable;
                nodes += 1;
            }
        }
    }

    {
        var src_iter = masks.nextbit(positions.rooks & ~pin_ad);
        while (src_iter.nextMask()) |src| {
            var pin_mask: masks.Mask = masks.full;
            if (pin_and_check.pin_hor & src != 0) {
                pin_mask = pin_and_check.pin_hor;
            } else if (pin_and_check.pin_ver & src != 0) {
                pin_mask = pin_and_check.pin_ver;
            }

            const lookup = rookLookup(src, occupied) & empty_or_enemy & pin_and_check.check & pin_mask;
            var dest_iter = masks.nextbit(lookup);
            while (dest_iter.nextMask()) |dest| {
                var child = board;
                doRookMove(&child, src, dest, color);
                swapSides(&child, color);
                list.append(child) catch unreachable;
                nodes += 1;
            }
        }
    }

    {
        var src_iter = masks.nextbit(positions.queens);
        while (src_iter.nextMask()) |src| {
            var pin_mask: masks.Mask = masks.full;
            if (pin_and_check.pin_hor & src != 0) {
                pin_mask = pin_and_check.pin_hor;
            } else if (pin_and_check.pin_ver & src != 0) {
                pin_mask = pin_and_check.pin_ver;
            } else if (pin_and_check.pin_asc & src != 0) {
                pin_mask = pin_and_check.pin_asc;
            } else if (pin_and_check.pin_desc & src != 0) {
                pin_mask = pin_and_check.pin_desc;
            }

            const lookup = queenLookup(src, occupied) & empty_or_enemy & pin_and_check.check & pin_mask;
            var dest_iter = masks.nextbit(lookup);
            while (dest_iter.nextMask()) |dest| {
                var child = board;
                doQueenMove(&child, src, dest, color);
                swapSides(&child, color);
                list.append(child) catch unreachable;
                nodes += 1;
            }
        }
    }

    {
        const prom_row = if (color == chess.Color.white) masks.first_row else masks.last_row;

        var src_iter = masks.nextbit(positions.pawns & ~(pin_ad | pin_and_check.pin_hor));
        while (src_iter.nextMask()) |src| {
            const dest = pawnsForward(src, occupied, color) & pin_and_check.check;
            if (dest == 0) continue;
            var child = board;
            doPawnForward(&child, dest, color);
            swapSides(&child, color);
            if (dest & prom_row != 0) {
                var child_queen = child;
                doPromotion(&child_queen, dest, Promotion.queen, color);
                list.append(child_queen) catch unreachable;
                var child_rook = child;
                doPromotion(&child_rook, dest, Promotion.rook, color);
                list.append(child_rook) catch unreachable;
                var child_bishop = child;
                doPromotion(&child_bishop, dest, Promotion.bishop, color);
                list.append(child_bishop) catch unreachable;
                var child_knight = child;
                doPromotion(&child_knight, dest, Promotion.knight, color);
                list.append(child_knight) catch unreachable;
                nodes += 4;
            } else {
                list.append(child) catch unreachable;
                nodes += 1;
            }
        }
    }

    {
        var src_iter = masks.nextbit(positions.pawns & ~(pin_ad | pin_and_check.pin_hor));
        while (src_iter.nextMask()) |src| {
            const dest = pawnsDoubleForward(src, occupied, color) & pin_and_check.check;
            if (dest == 0) continue;
            var child = board;
            doPawnDoubleForward(&child, dest, color);
            swapSides(&child, color);
            list.append(child) catch unreachable;
            nodes += 1;
        }
    }

    {
        var src_iter = masks.nextbit(positions.pawns & ~pin_hv);
        while (src_iter.nextMask()) |src| {
            var pin_mask: masks.Mask = masks.full;
            if (pin_and_check.pin_asc & src != 0) {
                pin_mask = pin_and_check.pin_asc;
            } else if (pin_and_check.pin_desc & src != 0) {
                pin_mask = pin_and_check.pin_desc;
            }

            const lookup = pawnCaptures(src, color) & pin_and_check.check & pin_mask & enemy;
            var dest_iter = masks.nextbit(lookup);
            while (dest_iter.nextMask()) |dest| {
                var child = board;
                doPawnCapture(&child, src, dest, color);
                swapSides(&child, color);
                if (dest & (masks.first_row | masks.last_row) != 0) {
                    var child_queen = child;
                    doPromotion(&child_queen, dest, Promotion.queen, color);
                    list.append(child_queen) catch unreachable;
                    var child_rook = child;
                    doPromotion(&child_rook, dest, Promotion.rook, color);
                    list.append(child_rook) catch unreachable;
                    var child_bishop = child;
                    doPromotion(&child_bishop, dest, Promotion.bishop, color);
                    list.append(child_bishop) catch unreachable;
                    var child_knight = child;
                    doPromotion(&child_knight, dest, Promotion.knight, color);
                    list.append(child_knight) catch unreachable;
                    nodes += 4;
                } else {
                    list.append(child) catch unreachable;
                    nodes += 1;
                }
            }
        }
    }

    {
        const lookup = pawnCaptures(board.en_passant & en_passant_check, reverseColor(color));
        var src_iter = masks.nextbit(positions.pawns & ~pin_hv & lookup);
        while (src_iter.nextMask()) |src| {
            var child = board;
            doEnPassant(&child, src, color);
            swapSides(&child, color);
            const child_occupied = child.white.occupied() | child.black.occupied();
            if (isAttackedBy(child, positions.king, child_occupied, reverseColor(color))) continue;
            list.append(child) catch unreachable;
            nodes += 1;
        }
    }

    {
        if (color == chess.Color.white) {
            if (castlingRightK(board, occupied, color)) {
                var child = board;
                doKingMove(&child, masks.one << 62, color);
                doRookMove(&child, masks.one << 63, masks.one << 61, color);
                swapSides(&child, color);
                list.append(child) catch unreachable;
                nodes += 1;
            }
            if (castlingRightQ(board, occupied, color)) {
                var child = board;
                doKingMove(&child, masks.one << 58, color);
                doRookMove(&child, masks.one << 56, masks.one << 59, color);
                swapSides(&child, color);
                list.append(child) catch unreachable;
                nodes += 1;
            }
        } else {
            if (castlingRightBlackK(board, occupied, color)) {
                var child = board;
                doKingMove(&child, masks.one << 6, color);
                doRookMove(&child, masks.one << 7, masks.one << 5, color);
                swapSides(&child, color);
                list.append(child) catch unreachable;
                nodes += 1;
            }
            if (castlingRightBlackQ(board, occupied, color)) {
                var child = board;
                doKingMove(&child, masks.one << 2, color);
                doRookMove(&child, masks.one << 0, masks.one << 3, color);
                swapSides(&child, color);
                list.append(child) catch unreachable;
                nodes += 1;
            }
        }
    }

    return nodes;
}

pub fn explore(board: chess.Board, depth: u64, comptime start: Callback, comptime end: Callback, arg: anytype) void {
    switch (board.side_to_move) {
        .white => exploreCallback(board, depth, .white, start, end, arg),
        .black => exploreCallback(board, depth, .black, start, end, arg),
    }
}

pub const CallbackReturn = enum {
    abort,
    next,
};

const Callback = fn (board: chess.Board, depth: u64, comptime color: chess.Color, arg: anytype) callconv(.Inline) CallbackReturn;

pub inline fn doNothing(_: chess.Board, _: u64, comptime _: chess.Color, _: anytype) CallbackReturn {
    return .next;
}

fn exploreCallback(board: chess.Board, depth: u64, comptime color: chess.Color, comptime start: Callback, comptime end: Callback, arg: anytype) void {
    if (start(board, depth, color, arg) == CallbackReturn.abort) return;
    if (depth == 0) return;

    const positions = if (color == chess.Color.white) board.white else board.black;
    const enemy = if (color == chess.Color.white) board.black.occupied() else board.white.occupied();
    const occupied = positions.occupied() | enemy;
    const empty_or_enemy = ~occupied | enemy;

    const pin_and_check = createPinCheckMasks(board, occupied, color);
    const en_passant_check = (pawnsForward(pin_and_check.check, 0, color) & board.en_passant) | pin_and_check.check;

    {
        const lookup = kingLookup(positions.king) & empty_or_enemy;
        var dest_iter = masks.nextbit(lookup);
        while (dest_iter.nextMask()) |dest| {
            if (isAttackedBy(board, dest, occupied, reverseColor(color))) continue;
            var child = board;
            doKingMove(&child, dest, color);
            swapSides(&child, color);
            exploreCallback(child, depth - 1, reverseColor(color), start, end, arg);
        }
    }

    if (pin_and_check.checks > 1) return;

    const pin_hv = pin_and_check.pin_hor | pin_and_check.pin_ver;
    const pin_ad = pin_and_check.pin_asc | pin_and_check.pin_desc;

    {
        var src_iter = masks.nextbit(positions.knights & ~(pin_hv | pin_ad));
        while (src_iter.nextMask()) |src| {
            const lookup = knightLookup(src) & empty_or_enemy & pin_and_check.check;
            var dest_iter = masks.nextbit(lookup);
            while (dest_iter.nextMask()) |dest| {
                var child = board;
                doKnightMove(&child, src, dest, color);
                swapSides(&child, color);
                exploreCallback(child, depth - 1, reverseColor(color), start, end, arg);
            }
        }
    }

    {
        var src_iter = masks.nextbit(positions.bishops & ~pin_hv);
        while (src_iter.nextMask()) |src| {
            var pin_mask: masks.Mask = masks.full;
            if (pin_and_check.pin_asc & src != 0) {
                pin_mask = pin_and_check.pin_asc;
            } else if (pin_and_check.pin_desc & src != 0) {
                pin_mask = pin_and_check.pin_desc;
            }

            const lookup = bishopLookup(src, occupied) & empty_or_enemy & pin_and_check.check & pin_mask;
            var dest_iter = masks.nextbit(lookup);
            while (dest_iter.nextMask()) |dest| {
                var child = board;
                doBishopMove(&child, src, dest, color);
                swapSides(&child, color);
                exploreCallback(child, depth - 1, reverseColor(color), start, end, arg);
            }
        }
    }

    {
        var src_iter = masks.nextbit(positions.rooks & ~pin_ad);
        while (src_iter.nextMask()) |src| {
            var pin_mask: masks.Mask = masks.full;
            if (pin_and_check.pin_hor & src != 0) {
                pin_mask = pin_and_check.pin_hor;
            } else if (pin_and_check.pin_ver & src != 0) {
                pin_mask = pin_and_check.pin_ver;
            }

            const lookup = rookLookup(src, occupied) & empty_or_enemy & pin_and_check.check & pin_mask;
            var dest_iter = masks.nextbit(lookup);
            while (dest_iter.nextMask()) |dest| {
                var child = board;
                doRookMove(&child, src, dest, color);
                swapSides(&child, color);
                exploreCallback(child, depth - 1, reverseColor(color), start, end, arg);
            }
        }
    }

    {
        var src_iter = masks.nextbit(positions.queens);
        while (src_iter.nextMask()) |src| {
            var pin_mask: masks.Mask = masks.full;
            if (pin_and_check.pin_hor & src != 0) {
                pin_mask = pin_and_check.pin_hor;
            } else if (pin_and_check.pin_ver & src != 0) {
                pin_mask = pin_and_check.pin_ver;
            } else if (pin_and_check.pin_asc & src != 0) {
                pin_mask = pin_and_check.pin_asc;
            } else if (pin_and_check.pin_desc & src != 0) {
                pin_mask = pin_and_check.pin_desc;
            }

            const lookup = queenLookup(src, occupied) & empty_or_enemy & pin_and_check.check & pin_mask;
            var dest_iter = masks.nextbit(lookup);
            while (dest_iter.nextMask()) |dest| {
                var child = board;
                doQueenMove(&child, src, dest, color);
                swapSides(&child, color);
                exploreCallback(child, depth - 1, reverseColor(color), start, end, arg);
            }
        }
    }

    {
        const prom_row = if (color == chess.Color.white) masks.first_row else masks.last_row;

        var src_iter = masks.nextbit(positions.pawns & ~(pin_ad | pin_and_check.pin_hor));
        while (src_iter.nextMask()) |src| {
            const dest = pawnsForward(src, occupied, color) & pin_and_check.check;
            if (dest == 0) continue;
            var child = board;
            doPawnForward(&child, dest, color);
            swapSides(&child, color);
            if (dest & prom_row != 0) {
                var child_queen = child;
                doPromotion(&child_queen, dest, Promotion.queen, color);
                exploreCallback(child_queen, depth - 1, reverseColor(color), start, end, arg);
                var child_rook = child;
                doPromotion(&child_rook, dest, Promotion.rook, color);
                exploreCallback(child_rook, depth - 1, reverseColor(color), start, end, arg);
                var child_bishop = child;
                doPromotion(&child_bishop, dest, Promotion.bishop, color);
                exploreCallback(child_bishop, depth - 1, reverseColor(color), start, end, arg);
                var child_knight = child;
                doPromotion(&child_knight, dest, Promotion.knight, color);
                exploreCallback(child_knight, depth - 1, reverseColor(color), start, end, arg);
            } else {
                exploreCallback(child, depth - 1, reverseColor(color), start, end, arg);
            }
        }
    }

    {
        var src_iter = masks.nextbit(positions.pawns & ~(pin_ad | pin_and_check.pin_hor));
        while (src_iter.nextMask()) |src| {
            const dest = pawnsDoubleForward(src, occupied, color) & pin_and_check.check;
            if (dest == 0) continue;
            var child = board;
            doPawnDoubleForward(&child, dest, color);
            swapSides(&child, color);
            exploreCallback(child, depth - 1, reverseColor(color), start, end, arg);
        }
    }

    {
        var src_iter = masks.nextbit(positions.pawns & ~pin_hv);
        while (src_iter.nextMask()) |src| {
            var pin_mask: masks.Mask = masks.full;
            if (pin_and_check.pin_asc & src != 0) {
                pin_mask = pin_and_check.pin_asc;
            } else if (pin_and_check.pin_desc & src != 0) {
                pin_mask = pin_and_check.pin_desc;
            }

            const lookup = pawnCaptures(src, color) & pin_and_check.check & pin_mask & enemy;
            var dest_iter = masks.nextbit(lookup);
            while (dest_iter.nextMask()) |dest| {
                var child = board;
                doPawnCapture(&child, src, dest, color);
                swapSides(&child, color);
                if (dest & (masks.first_row | masks.last_row) != 0) {
                    var child_queen = child;
                    doPromotion(&child_queen, dest, Promotion.queen, color);
                    exploreCallback(child_queen, depth - 1, reverseColor(color), start, end, arg);
                    var child_rook = child;
                    doPromotion(&child_rook, dest, Promotion.rook, color);
                    exploreCallback(child_rook, depth - 1, reverseColor(color), start, end, arg);
                    var child_bishop = child;
                    doPromotion(&child_bishop, dest, Promotion.bishop, color);
                    exploreCallback(child_bishop, depth - 1, reverseColor(color), start, end, arg);
                    var child_knight = child;
                    doPromotion(&child_knight, dest, Promotion.knight, color);
                    exploreCallback(child_knight, depth - 1, reverseColor(color), start, end, arg);
                } else {
                    exploreCallback(child, depth - 1, reverseColor(color), start, end, arg);
                }
            }
        }
    }

    {
        const lookup = pawnCaptures(board.en_passant & en_passant_check, reverseColor(color));
        var src_iter = masks.nextbit(positions.pawns & ~pin_hv & lookup);
        while (src_iter.nextMask()) |src| {
            var child = board;
            doEnPassant(&child, src, color);
            swapSides(&child, color);
            const child_occupied = child.white.occupied() | child.black.occupied();
            if (isAttackedBy(child, positions.king, child_occupied, reverseColor(color))) continue;
            exploreCallback(child, depth - 1, reverseColor(color), start, end, arg);
        }
    }

    {
        if (color == chess.Color.white) {
            if (castlingRightK(board, occupied, color)) {
                var child = board;
                doKingMove(&child, masks.one << 62, color);
                doRookMove(&child, masks.one << 63, masks.one << 61, color);
                swapSides(&child, color);
                exploreCallback(child, depth - 1, reverseColor(color), start, end, arg);
            }
            if (castlingRightQ(board, occupied, color)) {
                var child = board;
                doKingMove(&child, masks.one << 58, color);
                doRookMove(&child, masks.one << 56, masks.one << 59, color);
                swapSides(&child, color);
                exploreCallback(child, depth - 1, reverseColor(color), start, end, arg);
            }
        } else {
            if (castlingRightBlackK(board, occupied, color)) {
                var child = board;
                doKingMove(&child, masks.one << 6, color);
                doRookMove(&child, masks.one << 7, masks.one << 5, color);
                swapSides(&child, color);
                exploreCallback(child, depth - 1, reverseColor(color), start, end, arg);
            }
            if (castlingRightBlackQ(board, occupied, color)) {
                var child = board;
                doKingMove(&child, masks.one << 2, color);
                doRookMove(&child, masks.one << 0, masks.one << 3, color);
                swapSides(&child, color);
                exploreCallback(child, depth - 1, reverseColor(color), start, end, arg);
            }
        }
    }

    _ = end(board, depth, color, arg);
}

const PerftCallbackArg = struct {
    nodes: u64,
    bulk: bool,
    nodes_list: ?*std.ArrayList(chess.Board),
};

inline fn perftCallback(board: chess.Board, depth: u64, comptime color: chess.Color, arg: anytype) CallbackReturn {
    if (depth == 1 and arg.bulk) {
        arg.nodes += countMoves(board, color);
        return CallbackReturn.abort;
    }
    if (depth == 0) {
        arg.nodes += 1;
        if (arg.nodes_list) |node_list| node_list.append(board) catch unreachable;
        return CallbackReturn.abort;
    }
    return CallbackReturn.next;
}

pub fn perft(board: chess.Board, depth: u64, comptime bulk: bool, nodes_list: ?*std.ArrayList(chess.Board)) u64 {
    var arg = PerftCallbackArg{ .nodes = 0, .bulk = bulk, .nodes_list = nodes_list };
    explore(board, depth, perftCallback, doNothing, &arg);
    return arg.nodes;
}
