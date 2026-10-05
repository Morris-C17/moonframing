///|
test "varint boundary round trips" {
  for value in [0, 1, 127, 128, 16384, 1048576] {
    let encoded = @moonframing.encode_varint(value)
    match @moonframing.decode_varint(encoded) {
      Some((decoded, consumed)) => {
        inspect(decoded == value, content="true")
        inspect(consumed == encoded.length(), content="true")
      }
      None => fail("encoded varint must decode")
    }
  }
}

///|
test "single frame round trip" {
  let encoded = @moonframing.encode_frame(b"hello")
  match @moonframing.decode_frame(encoded) {
    Ok((payload, consumed)) => {
      inspect(payload == b"hello", content="true")
      inspect(consumed == encoded.length(), content="true")
    }
    Err(_) => fail("complete frame must decode")
  }
}

///|
test "frame size limit is enforced before allocation" {
  match @moonframing.decode_frame(b"\x08abcdefgh", max_frame_size=4) {
    Err(@moonframing.FrameTooLarge(actual, limit)) => {
      inspect(actual, content="8")
      inspect(limit, content="4")
    }
    _ => fail("oversized frame must be rejected")
  }
}

///|
test "incremental decoder tolerates one-byte chunks" {
  let decoder = @moonframing.Decoder::new()
  let encoded = @moonframing.encode_frame(b"fragmented")
  let output : Array[Bytes] = []
  for byte in encoded {
    match decoder.feed(Bytes::from_array([byte])) {
      Ok(frames) =>
        for frame in frames {
          output.push(frame)
        }
      Err(_) => fail("valid fragments must not fail")
    }
  }
  inspect(output.length(), content="1")
  inspect(output[0] == b"fragmented", content="true")
  inspect(decoder.buffered(), content="0")
}

///|
test "incremental decoder emits multiple coalesced frames" {
  let first = @moonframing.encode_frame(b"a")
  let second = @moonframing.encode_frame(b"bc")
  let joined : Array[Byte] = []
  for byte in first {
    joined.push(byte)
  }
  for byte in second {
    joined.push(byte)
  }
  let decoder = @moonframing.Decoder::new()
  match decoder.feed(Bytes::from_array(joined)) {
    Ok(frames) => {
      inspect(frames.length(), content="2")
      inspect(frames[0] == b"a", content="true")
      inspect(frames[1] == b"bc", content="true")
    }
    Err(_) => fail("coalesced frames must decode")
  }
}

///|
test "finite stream helper rejects trailing partial frame" {
  let stream = @moonframing.encode_frames([b"one", b"two", b"three"])
  match @moonframing.decode_all(stream) {
    Ok(frames) => inspect(frames.length(), content="3")
    Err(_) => fail("complete finite stream must decode")
  }
  match @moonframing.decode_all(b"\x05abc") {
    Err(@moonframing.NeedMore) => ()
    _ => fail("truncated payload must be explicit")
  }
}

///|
test "CRC-32 standard vector and checked frame" {
  inspect(@moonframing.crc32(b"123456789") == 0xcbf43926U, content="true")
  let encoded = @moonframing.encode_checked_frame(b"protected")
  match @moonframing.decode_checked_frame(encoded) {
    Ok((payload, _)) => inspect(payload == b"protected", content="true")
    Err(_) => fail("untampered checksum must pass")
  }
  let tampered = encoded.to_array()
  tampered[2] = (tampered[2].to_int() ^ 1).to_byte()
  match @moonframing.decode_checked_frame(Bytes::from_array(tampered)) {
    Err(@moonframing.ChecksumMismatch(_, _)) => ()
    _ => fail("tampering must be detected")
  }
}

///|
test "decoder can recover at an application-defined boundary" {
  let decoder = @moonframing.Decoder::new(max_frame_size=3)
  match decoder.feed(@moonframing.encode_frame(b"toolong")) {
    Err(@moonframing.FrameTooLarge(_, _)) => ()
    _ => fail("limit must reject oversized input")
  }
  inspect(decoder.buffered() > 0, content="true")
  decoder.reset()
  match decoder.feed(@moonframing.encode_frame(b"ok")) {
    Ok(frames) => inspect(frames[0] == b"ok", content="true")
    Err(_) => fail("decoder must be reusable after reset")
  }
}

///|
test "malformed 31-bit varints are rejected" {
  match @moonframing.decode_frame(b"\xff\xff\xff\xff\x0f") {
    Err(@moonframing.MalformedVarint) => ()
    _ => fail("overflowing fifth varint byte must be rejected")
  }
}

///|
test "incremental decoder enforces a total buffer budget" {
  let decoder = @moonframing.Decoder::new(max_frame_size=8, max_buffer_size=6)
  match decoder.feed(b"\x08abcdef") {
    Err(@moonframing.BufferLimitExceeded(actual, limit)) => {
      inspect(actual, content="7")
      inspect(limit, content="6")
      inspect(decoder.buffered(), content="0")
    }
    _ => fail("oversized buffered input must be rejected before copying")
  }
}

///|
test "coalesced complete frames do not consume the retained buffer budget" {
  let payloads : Array[Bytes] = []
  for _i = 0; _i < 32; _i = _i + 1 {
    payloads.push(b"ok")
  }
  let decoder = @moonframing.Decoder::new(max_frame_size=4, max_buffer_size=5)
  match decoder.feed(@moonframing.encode_frames(payloads)) {
    Ok(frames) => {
      inspect(frames.length(), content="32")
      inspect(decoder.buffered(), content="0")
    }
    Err(_) =>
      fail("complete coalesced frames must be drained before limit checks")
  }
}

///|
test "fixed-width big-endian codec round trips" {
  let codec = match
    @moonframing.LengthDelimitedCodec::new(
      length_field_length=2,
      max_frame_size=1024,
    ) {
    Ok(codec) => codec
    Err(_) => fail("valid configuration")
  }
  let wire = match codec.encode(b"moon") {
    Ok(wire) => wire
    Err(_) => fail("encodable payload")
  }
  inspect(wire == b"\x00\x04moon", content="true")
  match codec.feed(wire) {
    Ok(frames) => inspect(frames[0] == b"moon", content="true")
    Err(_) => fail("fixed-width frame must decode")
  }
}

///|
test "fixed-width little-endian field supports an offset" {
  let codec = match
    @moonframing.LengthDelimitedCodec::new(
      length_field_offset=2,
      length_field_length=2,
      byte_order=@moonframing.little_endian(),
    ) {
    Ok(codec) => codec
    Err(_) => fail("valid offset configuration")
  }
  let wire = match codec.encode(b"abc") {
    Ok(wire) => wire
    Err(_) => fail("encodable payload")
  }
  inspect(wire == b"\x00\x00\x03\x00abc", content="true")
  match codec.feed(wire) {
    Ok(frames) => inspect(frames[0] == b"abc", content="true")
    Err(_) => fail("little-endian frame must decode")
  }
}

///|
test "fixed-width signed length adjustment round trips" {
  let codec = match
    @moonframing.LengthDelimitedCodec::new(
      length_field_length=1,
      length_adjustment=-2,
    ) {
    Ok(codec) => codec
    Err(_) => fail("valid adjustment")
  }
  let wire = match codec.encode(b"abc") {
    Ok(wire) => wire
    Err(_) => fail("encodable adjusted payload")
  }
  inspect(wire == b"\x05abc", content="true")
  match codec.feed(wire) {
    Ok(frames) => inspect(frames[0] == b"abc", content="true")
    Err(_) => fail("adjusted frame must decode")
  }
}

///|
test "fixed-width field overflow and malformed configurations are rejected" {
  let codec = match
    @moonframing.LengthDelimitedCodec::new(length_field_length=1) {
    Ok(codec) => codec
    Err(_) => fail("one-byte field is valid")
  }
  let too_large = Bytes::from_array(Array::make(256, 0))
  match codec.encode(too_large) {
    Err(@moonframing.LengthFieldOverflow(256, 255)) => ()
    _ => fail("one-byte length must reject 256")
  }
  match @moonframing.LengthDelimitedCodec::new(length_field_length=0) {
    Err(@moonframing.InvalidConfiguration(_)) => ()
    _ => fail("zero-width length field is invalid")
  }
}

///|
test "fixed-width decoder handles every fragmentation boundary" {
  let wire = b"\x00\x0afragmented"
  for split = 0; split <= wire.length(); split = split + 1 {
    let codec = match
      @moonframing.LengthDelimitedCodec::new(length_field_length=2) {
      Ok(codec) => codec
      Err(_) => fail("valid configuration")
    }
    let output : Array[Bytes] = []
    match codec.feed(wire[:split].to_owned()) {
      Ok(frames) =>
        for frame in frames {
          output.push(frame)
        }
      Err(_) => fail("first fragment")
    }
    match codec.feed(wire[split:].to_owned()) {
      Ok(frames) =>
        for frame in frames {
          output.push(frame)
        }
      Err(_) => fail("second fragment")
    }
    inspect(output.length(), content="1")
    inspect(output[0] == b"fragmented", content="true")
  }
}

///|
test "multi-byte delimiter may cross chunk boundaries" {
  let codec = match @moonframing.DelimiterDecoder::new(b"\r\n") {
    Ok(codec) => codec
    Err(_) => fail("valid delimiter")
  }
  match codec.feed(b"one\r") {
    Ok(frames) => inspect(frames.length(), content="0")
    Err(_) => fail("partial delimiter")
  }
  match codec.feed(b"\ntwo\r\n") {
    Ok(frames) => {
      inspect(frames.length(), content="2")
      inspect(frames[0] == b"one", content="true")
      inspect(frames[1] == b"two", content="true")
    }
    Err(_) => fail("complete delimiter stream")
  }
}

///|
test "delimiter codec can preserve terminators and enforce limits" {
  let preserving = match
    @moonframing.DelimiterDecoder::new(b"\n", strip_delimiter=false) {
    Ok(codec) => codec
    Err(_) => fail("valid delimiter")
  }
  match preserving.feed(b"line\n") {
    Ok(frames) => inspect(frames[0] == b"line\n", content="true")
    Err(_) => fail("preserved delimiter")
  }
  let limited = match
    @moonframing.DelimiterDecoder::new(b"\n", max_frame_size=3) {
    Ok(codec) => codec
    Err(_) => fail("valid limited delimiter")
  }
  match limited.feed(b"four\n") {
    Err(@moonframing.BufferLimitExceeded(_, _)) => ()
    _ => fail("unterminated oversized item must be bounded")
  }
}

///|
test "checked decoder verifies fragmented and coalesced frames" {
  let first = @moonframing.encode_checked_frame(b"one")
  let second = @moonframing.encode_checked_frame(b"two")
  let stream = first.to_array()
  for byte in second {
    stream.push(byte)
  }
  let decoder = @moonframing.CheckedDecoder::new()
  let output : Array[Bytes] = []
  for byte in Bytes::from_array(stream) {
    match decoder.feed(Bytes::from_array([byte])) {
      Ok(frames) =>
        for frame in frames {
          output.push(frame)
        }
      Err(_) => fail("valid checked stream")
    }
  }
  inspect(output.length(), content="2")
  inspect(output[0] == b"one", content="true")
  inspect(output[1] == b"two", content="true")
}

///|
test "incremental decoder emits empty frames without losing the next header" {
  let decoder = @moonframing.Decoder::new()
  match decoder.feed(b"\x00\x01x\x00") {
    Ok(frames) => {
      inspect(frames.length(), content="3")
      inspect(frames[0] == b"", content="true")
      inspect(frames[1] == b"x", content="true")
      inspect(frames[2] == b"", content="true")
    }
    Err(_) => fail("empty and non-empty frames may be coalesced")
  }
}

///|
test "fixed-width codec can return a complete envelope with num_skip zero" {
  let codec = match
    @moonframing.LengthDelimitedCodec::new(
      length_field_offset=2,
      length_field_length=2,
      num_skip=0,
    ) {
    Ok(codec) => codec
    Err(_) => fail("valid envelope configuration")
  }
  match codec.feed(b"AB\x00\x03xyz") {
    Ok(frames) => inspect(frames[0] == b"AB\x00\x03xyz", content="true")
    Err(_) => fail("complete envelope must decode")
  }
}

///|
test "fixed-width decoder rejects an oversized declaration before payload" {
  let codec = match
    @moonframing.LengthDelimitedCodec::new(
      length_field_length=2,
      max_frame_size=8,
    ) {
    Ok(codec) => codec
    Err(_) => fail("valid bounded codec")
  }
  match codec.feed(b"\x00\x09") {
    Err(@moonframing.FrameTooLarge(9, 8)) => ()
    _ => fail("oversized declaration must fail as soon as the header arrives")
  }
}

///|
test "fixed-width codec drains many frames before checking retained budget" {
  let codec = match
    @moonframing.LengthDelimitedCodec::new(
      length_field_length=1,
      max_frame_size=2,
      max_buffer_size=3,
    ) {
    Ok(codec) => codec
    Err(_) => fail("valid small-budget codec")
  }
  match codec.feed(b"\x02ok\x02ok\x02ok\x02ok") {
    Ok(frames) => inspect(frames.length(), content="4")
    Err(_) => fail("complete frames must not accumulate against the budget")
  }
}

///|
test "empty delimiter and incomplete delimited input are explicit" {
  match @moonframing.DelimiterDecoder::new(b"") {
    Err(@moonframing.InvalidConfiguration(_)) => ()
    _ => fail("empty delimiter is ambiguous")
  }
  let codec = match @moonframing.DelimiterDecoder::new(b"\r\n") {
    Ok(codec) => codec
    Err(_) => fail("valid delimiter")
  }
  ignore(codec.feed(b"unfinished\r"))
  match codec.finish() {
    Err(@moonframing.NeedMore) => ()
    _ => fail("trailing partial item must be reported")
  }
}

///|
test "checked decoder reports corruption after arbitrary fragmentation" {
  let wire = @moonframing.encode_checked_frame(b"protected").to_array()
  wire[3] = (wire[3].to_int() ^ 4).to_byte()
  let decoder = @moonframing.CheckedDecoder::new()
  let mut failed = false
  for byte in Bytes::from_array(wire) {
    match decoder.feed(Bytes::from_array([byte])) {
      Err(@moonframing.ChecksumMismatch(_, _)) => failed = true
      Err(_) => fail("unexpected checked decoder error")
      Ok(_) => ()
    }
  }
  inspect(failed, content="true")
}

///|
test "decoder finish distinguishes a parsed header from an idle decoder" {
  let decoder = @moonframing.Decoder::new()
  ignore(decoder.feed(b"\x03"))
  match decoder.finish() {
    Err(@moonframing.NeedMore) => ()
    _ => fail("a parsed length with no payload is incomplete")
  }
  decoder.reset()
  match decoder.finish() {
    Ok(_) => ()
    _ => fail("reset decoder must be idle")
  }
}
