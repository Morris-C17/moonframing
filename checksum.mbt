///|
/// IEEE CRC-32 for optional corruption detection on framed transports.
pub fn crc32(data : Bytes) -> UInt {
  let mut crc = 0xffffffffU
  for byte in data {
    crc = crc ^ byte.to_uint()
    for _bit = 0; _bit < 8; _bit = _bit + 1 {
      crc = if (crc & 1U) != 0U { (crc >> 1) ^ 0xedb88320U } else { crc >> 1 }
    }
  }
  crc.lnot()
}

///|
/// Encode payload plus a big-endian CRC-32 inside the length envelope.
pub fn encode_checked_frame(payload : Bytes) -> Bytes {
  let checksum = crc32(payload)
  let body : Array[Byte] = []
  for byte in payload {
    body.push(byte)
  }
  body.push((checksum >> 24).to_byte())
  body.push((checksum >> 16).to_byte())
  body.push((checksum >> 8).to_byte())
  body.push(checksum.to_byte())
  encode_frame(Bytes::from_array(body))
}

///|
/// Decode and verify one checksummed frame.
pub fn decode_checked_frame(
  data : Bytes,
  max_frame_size? : Int = 1048576,
) -> Result[(Bytes, Int), FrameError] {
  match decode_frame(data, max_frame_size=max_frame_size + 4) {
    Err(error) => Err(error)
    Ok((body, consumed)) => {
      if body.length() < 4 {
        return Err(MissingChecksum)
      }
      let end = body.length()
      let payload = body[:end - 4].to_owned()
      let expected = (body[end - 4].to_uint() << 24) |
        (body[end - 3].to_uint() << 16) |
        (body[end - 2].to_uint() << 8) |
        body[end - 1].to_uint()
      let actual = crc32(payload)
      if actual != expected {
        return Err(ChecksumMismatch(expected, actual))
      }
      Ok((payload, consumed))
    }
  }
}

///|
fn verify_checked_body(body : Bytes) -> Result[Bytes, FrameError] {
  if body.length() < 4 {
    return Err(MissingChecksum)
  }
  let end = body.length()
  let payload = body[:end - 4].to_owned()
  let expected = (body[end - 4].to_uint() << 24) |
    (body[end - 3].to_uint() << 16) |
    (body[end - 2].to_uint() << 8) |
    body[end - 1].to_uint()
  let actual = crc32(payload)
  if actual != expected {
    Err(ChecksumMismatch(expected, actual))
  } else {
    Ok(payload)
  }
}

///|
/// Incremental decoder for CRC-32 protected frames.
pub struct CheckedDecoder {
  inner : Decoder
}

///|
pub fn CheckedDecoder::new(
  max_frame_size? : Int = 1048576,
  max_buffer_size? : Int = max_frame_size + 9,
) -> CheckedDecoder {
  CheckedDecoder::{
    inner: Decoder::new(max_frame_size=max_frame_size + 4, max_buffer_size~),
  }
}

///|
pub fn CheckedDecoder::feed(
  self : CheckedDecoder,
  chunk : Bytes,
) -> Result[Array[Bytes], FrameError] {
  match self.inner.feed(chunk) {
    Err(error) => Err(error)
    Ok(bodies) => {
      let frames : Array[Bytes] = []
      for body in bodies {
        match verify_checked_body(body) {
          Ok(payload) => frames.push(payload)
          Err(error) => return Err(error)
        }
      }
      Ok(frames)
    }
  }
}

///|
pub fn CheckedDecoder::buffered(self : CheckedDecoder) -> Int {
  self.inner.buffered()
}

///|
pub fn CheckedDecoder::reset(self : CheckedDecoder) -> Unit {
  self.inner.reset()
}

///|
pub fn CheckedDecoder::finish(
  self : CheckedDecoder,
) -> Result[Unit, FrameError] {
  self.inner.finish()
}
