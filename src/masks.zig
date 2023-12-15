pub const Mask = u64;

const full: Mask = 0xffffffffffffffff;

const no_left: Mask = 0xfefefefefefefefe;
const no_left_double: Mask = 0xfcfcfcfcfcfcfcfc;
const no_right: Mask = 0x7f7f7f7f7f7f7f7f;
const no_right_double: Mask = 0x3f3f3f3f3f3f3f3f;

const asc_diag: Mask = 0x0102040810204080;
const dsc_diag: Mask = 0x8040201008040201;

const first_row: Mask = 0x00000000000000ff;
const last_row: Mask = 0xff00000000000000;
const first_col: Mask = 0x0101010101010101;
const last_col: Mask = 0x8080808080808080;

const castling_K: Mask = 0x9000000000000000;
const castling_Q: Mask = 0x1100000000000000;
const castling_k: Mask = 0x0000000000000090;
const castling_q: Mask = 0x0000000000000011;
