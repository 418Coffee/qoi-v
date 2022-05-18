module qoi

import io
import os

fn test_qoi() {
	mut f := os.open_file('./qoi_logo.qoi', 'rb') or { panic(err) }
	data := io.read_all(io.ReadAllConfig{ reader: f }) or { panic(err) }
	decoded := decode(data, 0) or { panic(err) }
	encoded := encode(decoded, decode_header(data) or { panic(err) }) or { panic(err) }
	assert data.len == encoded.len
	assert data == encoded
}

fn test_invalid_channels() {
	read("./qoi_logo.qoi", -1) or { exit(0) }
	panic("expected to fail")
}