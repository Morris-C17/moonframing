///|
/// Stateful framing for line protocols and other delimiter-terminated streams.
pub struct DelimiterDecoder {
  buffer : Array[Byte]
  delimiter : Bytes
  strip_delimiter : Bool
  max_frame_size : Int
  max_buffer_size : Int
}

///|
pub fn DelimiterDecoder::new(
  delimiter : Bytes,
  strip_delimiter? : Bool = true,
  max_frame_size? : Int = 1048576,
  max_buffer_size? : Int = max_frame_size + delimiter.length(),
) -> Result[DelimiterDecoder, FrameError] {
  if delimiter.length() == 0 {
    return Err(InvalidConfiguration("delimiter must not be empty"))
  }
  if max_frame_size < 0 || max_buffer_size < delimiter.length() {
    return Err(InvalidConfiguration("delimiter resource limits are invalid"))
  }
  Ok(DelimiterDecoder::{
    buffer: [],
    delimiter,
    strip_delimiter,
    max_frame_size,
    max_buffer_size,
  })
}

///|
fn DelimiterDecoder::ends_with_delimiter(self : DelimiterDecoder) -> Bool {
  let delimiter_length = self.delimiter.length()
  let buffer_length = self.buffer.length()
  if buffer_length < delimiter_length {
    return false
  }
  for i = 0; i < delimiter_length; i = i + 1 {
    if self.buffer[buffer_length - delimiter_length + i] != self.delimiter[i] {
      return false
    }
  }
  true
}

///|
/// Encode one delimiter-terminated item.
pub fn DelimiterDecoder::encode(
  self : DelimiterDecoder,
  payload : Bytes,
) -> Result[Bytes, FrameError] {
  if payload.length() > self.max_frame_size {
    return Err(FrameTooLarge(payload.length(), self.max_frame_size))
  }
  let output = payload.to_array()
  for byte in self.delimiter {
    output.push(byte)
  }
  Ok(Bytes::from_array(output))
}

///|
/// Feed arbitrary chunks. Multi-byte delimiters may span chunk boundaries.
pub fn DelimiterDecoder::feed(
  self : DelimiterDecoder,
  chunk : Bytes,
) -> Result[Array[Bytes], FrameError] {
  let frames : Array[Bytes] = []
  for byte in chunk {
    self.buffer.push(byte)
    if self.ends_with_delimiter() {
      let full_length = self.buffer.length()
      let payload_length = full_length - self.delimiter.length()
      if payload_length > self.max_frame_size {
        return Err(FrameTooLarge(payload_length, self.max_frame_size))
      }
      let end = if self.strip_delimiter { payload_length } else { full_length }
      let snapshot = Bytes::from_array(self.buffer)
      frames.push(snapshot[:end].to_owned())
      self.buffer.clear()
    } else if self.buffer.length() > self.max_buffer_size ||
      self.buffer.length() > self.max_frame_size + self.delimiter.length() - 1 {
      let actual = self.buffer.length()
      self.buffer.clear()
      return Err(BufferLimitExceeded(actual, self.max_buffer_size))
    }
  }
  Ok(frames)
}

///|
pub fn DelimiterDecoder::buffered(self : DelimiterDecoder) -> Int {
  self.buffer.length()
}

///|
pub fn DelimiterDecoder::reset(self : DelimiterDecoder) -> Unit {
  self.buffer.clear()
}

///|
pub fn DelimiterDecoder::finish(
  self : DelimiterDecoder,
) -> Result[Unit, FrameError] {
  if self.buffer.length() == 0 {
    Ok(())
  } else {
    Err(NeedMore)
  }
}
