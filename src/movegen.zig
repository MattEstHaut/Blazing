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

inline fn queenLookup(queen: Index, occupied: chess.Bitboard) chess.Bitboard {
    return bishopLookup(queen, occupied) | rookLookup(queen, occupied);
}
