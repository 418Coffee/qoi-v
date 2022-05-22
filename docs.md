# module qoi

## contents

- [decode_header](#decode_header)
- [encode](#encode)
- [read](#read)
- [write](#write)
- [decode](#decode)

## decode_header

```v
fn decode_header(data []u8) ?Config
```

decode_header decodes a QOI header from memory.

[[Return to contents]](#contents)

## encode

```v
fn encode(data []u8, config Config) ?[]u8
```

encode encodes raw RGB or RGBA pixels into a QOI image in memory. The config struct must be filled with the image width, height,
number of channels (3 = RGB, 4 = RGBA) and the colourspace.

[[Return to contents]](#contents)

## read

```v
fn read(filename string, channels int) ?[]u8
```

read reads and decodes a QOI image from the file system. If channels is 0, the number of channels from the file header is used. If channels is 3 or 4 the
output format will be forced into this number of channels.

[[Return to contents]](#contents)

## write

```v
fn write(filename string, data []u8, config Config) ?
```

write encodes raw RGB or RGBA pixels into a QOI image and write it to the file system. The config struct must be filled with the image width, height,
number of channels (3 = RGB, 4 = RGBA) and the colourspace.

[[Return to contents]](#contents)

## decode

```v
fn decode(data []u8, channels int) ?[]u8
```

decode decodes a QOI image from memory. If channels is 0, the number of channels from the file header is used. If channels is 3 or 4 the
output format will be forced into this number of channels.

[[Return to contents]](#contents)

#### Powered by vdoc. Generated on: 22 May 2022 10:11:36
