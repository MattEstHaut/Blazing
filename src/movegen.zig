const chess = @import("chess.zig");
const masks = @import("masks.zig");

pub const Index = u6;

const rook_masks = rookMasks();
const bishop_masks = bishopMasks();

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

fn rookMasks() [64]masks.Mask {
    var result: [64]masks.Mask = undefined;
    var index: Index = 0;
    while (true) : (index += 1) {
        const col_index = index & 7;
        const row_offset = index - col_index;
        const col_mask = masks.first_col << col_index;
        const row_mask = masks.first_row << row_offset;
        result[index] = col_mask ^ row_mask;
        if (index == 63) break;
    }
    return result;
}

fn bishopMasks() [64]masks.Mask {
    var result: [64]masks.Mask = undefined;
    var index: Index = 0;
    while (true) : (index += 1) {
        const col = index & 7;
        var descending = masks.one << index;
        var ascending = masks.one << index;

        for (0..col) |_| {
            descending |= descending >> 9;
            ascending |= ascending << 7;
        }
        for (col..7) |_| {
            descending |= descending << 9;
            ascending |= ascending >> 7;
        }

        result[index] = descending ^ ascending;
        if (index == 63) break;
    }
    return result;
}
