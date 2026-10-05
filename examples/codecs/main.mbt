///|
fn main {
  let binary = match
    @frame.LengthDelimitedCodec::new(
      length_field_length=2,
      byte_order=@frame.big_endian(),
    ) {
    Ok(codec) => codec
    Err(_) => abort("valid binary codec configuration")
  }
  let wire = match binary.encode(b"binary message") {
    Ok(bytes) => bytes
    Err(_) => abort("payload fits the configured length field")
  }
  match binary.feed(wire) {
    Ok(frames) => println("binary frames: \{frames.length()}")
    Err(_) => abort("binary stream must decode")
  }

  let lines = match @frame.DelimiterDecoder::new(b"\r\n") {
    Ok(codec) => codec
    Err(_) => abort("valid line codec configuration")
  }
  ignore(lines.feed(b"first\r"))
  match lines.feed(b"\nsecond\r\n") {
    Ok(frames) => println("line frames: \{frames.length()}")
    Err(_) => abort("line stream must decode")
  }
}
