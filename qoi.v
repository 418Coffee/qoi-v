module main

import io
import os
import encoding.binary

struct Config {
	width       u32
	height      u32
	channels    u8
	colourspace u8
}

struct Qoi_rgba {
mut:
 	r u8
	g u8
	b u8
	a u8
}

const (
    qoi_op_index =  0x00 /* 00xxxxxx */
    qoi_op_diff  =  0x40 /* 01xxxxxx */
    qoi_op_luna  =  0x80 /* 10xxxxxx */
    qoi_op_run   =  0xc0 /* 11xxxxxx */
    qoi_op_rgb   =  0xfe /* 11111110 */
    qoi_op_rgba  =  0xff /* 11111111 */



	qoi_header_size = 14
	qoi_magic = [u8(`q`), `o`, `i`, `f`]
	/* 2GB is the max file size that this implementation can safely handle. We guard
	against anything larger than that, assuming the worst case with 5 bytes per
	pixel, rounded down to a nice clean value. 400 million pixels ought to be
	enough for anybody. */
	qoi_pixels_max  = 400_000_000
)

type Pixel = [4]u8

fn read_full(mut r io.Reader, mut buf []u8) ? {
	read_at_least(mut r, mut buf, buf.len)?
}

fn read_at_least(mut r io.Reader, mut buf []u8, min int) ? {
	if min < 0 {
		return error("n < 0")
	} else if buf.len < min {
		return error("buf.len < n")
	}
	mut nn := 0
	for nn < min {
		nn += r.read(mut buf[nn..])?
	}
	if nn < min {
		return error("unexpected eof")
	}
}

fn read_byte(mut r io.Reader) ?u8 {
	mut buf := [u8(0)]
	read_at_least(mut r, mut buf, 1)?
	return buf[0]
}



pub fn decode_header(mut r io.Reader) ?Config {
	mut header := []u8{len: qoi_header_size}
	read_full(mut r, mut header)?
	if header[..4] != qoi_magic {
		return error("invalid magic")
	}
	width := binary.big_endian_u32(header[4..])
	height := binary.big_endian_u32(header[8..])
	channels := header[12]
	colourspace := header[13]
	return Config{
		width: width, 
		height: height, 
		channels: channels,
		colourspace: colourspace
	}
}

pub fn decode(mut r io.Reader) ? {
	cfg := decode_header(mut r)?
	mut pixels := cfg.width * cfg.height
	// https://twitter.com/v_language/status/1517099415143690240 :wow:
	if pixels == 0 || !(cfg.channels in [3,4]) || cfg.colourspace > 1 || pixels > qoi_pixels_max {
		return error("invalid configuration")
	}
	println(cfg)
	mut bytes := []u8{len: int(pixels*cfg.channels)}
	read_full(mut r, mut bytes)?
	index := []Pixel{len: 64}
	mut p := 14
	mut run := 0
	mut rgba := Qoi_rgba{}
	for px_pos := 0; px_pos < bytes.len; px_pos += cfg.channels {
		if run > 0 {
			run--
		} else {
			b1 := bytes[p++]
			if b1 == qoi_op_rgb {
				start := p
				rgba.r = bytes[p++]
				rgba.g = bytes[p++]
				rgba.b = bytes[p++]
				rgba.a = bytes[p++]
			}
		}
	}
}

fn main() {
	mut f := os.open_file("./qoi_test_images/dice.qoi", "rb")?
	decode(mut f)?
}