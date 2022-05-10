module main

import io
import os
import encoding.binary

struct Config {
	width u32
	height u32
}

const (
	magic = "qoif".bytes()
)

pub fn decode_header(mut r io.Reader) ?Config {
	mut header := []u8{len: 14}
	// Read at least 14 bytes (magic).
	mut n := u8(0)
	for n < header.len {
		n += u8(r.read(mut header)?)
	}
	if header[..4] != magic {
		return error("invalid magic")
	}
	width := binary.big_endian_u32(header[4..])
	height := binary.big_endian_u32(header[8..])
	return Config{width: width, height: height}
}

fn main() {
	mut f := os.open_file("./qoi_test_images/dice.qoi", "rb")?
	c := decode_config(mut f)?
	println(c)
}