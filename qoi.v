module qoi

import io
import os
import encoding.binary

const (
	qoi_op_index    = 0x00 // 00xxxxxx
	qoi_op_diff     = 0x40 // 01xxxxxx
	qoi_op_luma     = 0x80 // 10xxxxxx
	qoi_op_run      = 0xc0 // 11xxxxxx
	qoi_op_rgb      = 0xfe // 11111110
	qoi_op_rgba     = 0xff // 11111111
	qoi_mask_2      = 0xc0 // 11000000
	qoi_header_size = 14
	qoi_magic       = [u8(`q`), `o`, `i`, `f`]
	qoi_padding     = [u8(0), 0, 0, 0, 0, 0, 0, 1]
	/*
	2GB is the max file size that this implementation can safely handle. We guard
	against anything larger than that, assuming the worst case with 5 data per
	pixel, rounded down to a nice clean value. 400 million pixels ought to be
	enough for anybody.*/
	qoi_pixels_max  = 400_000_000
)

type Operand = u8

type Pixel = [4]u8

struct Config {
	pixels      u32
	width       u32
	height      u32
	channels    u8
	colourspace u8
}

fn (c Config) is_valid() ? {
	if c.pixels == 0 || c.channels !in [3, 4] || c.colourspace > 1
		|| c.pixels < qoi.qoi_header_size + qoi.qoi_padding.len || c.pixels > qoi.qoi_pixels_max {
		return error('invalid configuration')
	}
}

fn colour_hash(p Pixel) u8 {
	return p[0] * 3 + p[1] * 5 + p[2] * 7 + p[3] * 11
}

// decode_header decodes a QOI header from memory.
pub fn decode_header(data []u8) ?Config {
	if data.len < qoi.qoi_header_size {
		return error('data < qoi_header_size')
	}
	if data[..4] != qoi.qoi_magic {
		return error('invalid magic')
	}
	width := binary.big_endian_u32(data[4..])
	height := binary.big_endian_u32(data[8..])
	channels := data[12]
	colourspace := data[13]
	return Config{
		pixels: width * height
		width: width
		height: height
		channels: channels
		colourspace: colourspace
	}
}

// decode decodes a QOI image from memory.
pub fn decode(data []u8, channels int) ?[]u8 {
	// V should be able to optimize this:
	// https://twitter.com/v_language/status/1517099415143690240
	if channels !in [0, 3, 4] {
		return error('invalid channel')
	}
	config := decode_header(data) ?
	config.is_valid() ?
	c := if channels != 0 { channels } else { config.channels }
	px_len := int(config.pixels * config.channels)
	mut p, mut run := 14, 0
	mut res := []u8{cap: px_len}
	mut index := []Pixel{len: 64}
	mut px := Pixel([4]u8{init: 0})
	px[3] = 0xff
	chunks_len := data.len - qoi.qoi_padding.len
	for px_pos := 0; px_pos < px_len; px_pos += c {
		if run > 0 {
			run--
		} else if p < chunks_len {
			b1 := Operand(data[p++])
			if b1 == qoi.qoi_op_rgb {
				px[0] = data[p++]
				px[1] = data[p++]
				px[2] = data[p++]
			} else if b1 == qoi.qoi_op_rgba {
				px[0] = data[p++]
				px[1] = data[p++]
				px[2] = data[p++]
				px[3] = data[p++]
			} else if (b1 & qoi.qoi_mask_2) == qoi.qoi_op_index {
				px = index[b1]
			} else if (b1 & qoi.qoi_mask_2) == qoi.qoi_op_diff {
				px[0] += ((b1 >> 4) & 0x03) - 2
				px[1] += ((b1 >> 2) & 0x03) - 2
				px[2] += (b1 & 0x03) - 2
			} else if (b1 & qoi.qoi_mask_2) == qoi.qoi_op_luma {
				b2 := data[p++]
				vg := (b1 & 0x3f) - 32
				px[0] += vg - 8 + ((b2 >> 4) & 0x0f)
				px[1] += vg
				px[2] += vg - 8 + (b2 & 0x0f)
			} else if (b1 & qoi.qoi_mask_2) == qoi.qoi_op_run {
				run = (b1 & 0x3f)
			}
			index[colour_hash(px) % 64] = px
		}
		res << px[0]
		res << px[1]
		res << px[2]
		if c == 4 {
			res << px[3]
		}
	}
	return res
}

// encode encodes raw RGB or RGBA pixels into a QOI image in memory.
pub fn encode(data []u8, config Config) ?[]u8 {
	config.is_valid() ?
	max_size := int(config.pixels) * (config.channels + 1) + qoi.qoi_header_size +
		qoi.qoi_padding.len
	mut res := []u8{len: 14, cap: max_size}
	mut p := 0
	res[p++] = qoi.qoi_magic[0]
	res[p++] = qoi.qoi_magic[1]
	res[p++] = qoi.qoi_magic[2]
	res[p++] = qoi.qoi_magic[3]
	binary.big_endian_put_u32(mut res[4..], config.width)
	binary.big_endian_put_u32(mut res[8..], config.height)
	p += 8
	res[p++] = config.channels
	res[p++] = config.colourspace
	mut index := []Pixel{len: 64}
	mut run := u8(0)
	mut px_prev := Pixel([4]u8{init: 0})
	px_prev[3] = 0xff
	mut px := px_prev
	px_len := config.pixels * config.channels
	px_end := px_len - config.channels
	for px_pos := 0; px_pos < px_len; px_pos += config.channels {
		px[0] = data[px_pos + 0]
		px[1] = data[px_pos + 1]
		px[2] = data[px_pos + 2]
		if config.channels == 4 {
			px[3] = data[px_pos + 3]
		}
		if px == px_prev {
			run++
			if run == 62 || px_pos == px_end {
				res << qoi.qoi_op_run | (run - 1)
				run = 0
			}
		} else {
			if run > 0 {
				res << qoi.qoi_op_run | (run - 1)
				run = 0
			}
			index_pos := colour_hash(px) % 64
			if index[index_pos] == px {
				res << qoi.qoi_op_index | index_pos
			} else {
				index[index_pos] = px
				if px[3] == px_prev[3] {
					vr := i8(px[0] - px_prev[0])
					vg := i8(px[1] - px_prev[1])
					vb := i8(px[2] - px_prev[2])
					vg_r := vr - vg
					vg_b := vb - vg
					if vr > -3 && vr < 2 && vg > -3 && vg < 2 && vb > -3 && vb < 2 {
						res << qoi.qoi_op_diff | u8((vr + 2) << 4 | (vg + 2) << 2 | (vb + 2))
					} else if vg_r > -9 && vg_r < 8 && vg > -33 && vg < 32 && vg_b > -9 && vg_b < 8 {
						res << qoi.qoi_op_luma | u8(vg + 32)
						res << u8((vg_r + 8) << 4) | u8(vg_b + 8)
					} else {
						res << qoi.qoi_op_rgb
						res << px[0]
						res << px[1]
						res << px[2]
					}
				} else {
					res << qoi.qoi_op_rgba
					res << px[0]
					res << px[1]
					res << px[2]
					res << px[3]
				}
			}
		}
		px_prev = px
	}
	for i := 0; i < qoi.qoi_padding.len; i++ {
		res << qoi.qoi_padding[i]
	}
	return res
}

// write encodes raw RGB or RGBA pixels into a QOI image and write it to the file
// system. The config struct must be filled with the image width, height,
// number of channels (3 = RGB, 4 = RGBA) and the colourspace.
pub fn write(filename string, data []u8, config Config) ? {
	return write_to_file(filename, encode(data, config) ?)
}

// read reads and decodes a QOI image from the file system. If channels is 0, the
// number of channels from the file header is used. If channels is 3 or 4 the
// output format will be forced into this number of channels.
pub fn read(filename string, channels int) ?[]u8 {
	return decode(os.read_bytes(filename) ?, channels)
}

fn write_to_file(filename string, data []u8) ? {
	mut f := os.create(filename) ?
	write_all(data, mut f) ?
	f.close()
}

fn write_all(data []u8, mut w io.Writer) ? {
	mut n := 0
	for n < data.len {
		n += w.write(data[n..]) ?
	}
}
