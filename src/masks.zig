pub const Mask = u64;

pub const one: Mask = 1;
pub const full: Mask = 0xffffffffffffffff;

pub const no_left: Mask = 0xfefefefefefefefe;
pub const no_left_double: Mask = 0xfcfcfcfcfcfcfcfc;
pub const no_right: Mask = 0x7f7f7f7f7f7f7f7f;
pub const no_right_double: Mask = 0x3f3f3f3f3f3f3f3f;

pub const asc_diag: Mask = 0x0102040810204080;
pub const dsc_diag: Mask = 0x8040201008040201;

pub const first_row: Mask = 0x00000000000000ff;
pub const last_row: Mask = 0xff00000000000000;
pub const first_col: Mask = 0x0101010101010101;
pub const last_col: Mask = 0x8080808080808080;

pub const castling_K: Mask = 0x9000000000000000;
pub const castling_Q: Mask = 0x1100000000000000;
pub const castling_k: Mask = 0x0000000000000090;
pub const castling_q: Mask = 0x0000000000000011;
