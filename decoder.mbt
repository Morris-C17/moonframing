///|
/// Stateful decoder accepting arbitrarily fragmented byte chunks.
pub struct Decoder {
  buffer : Array[Byte]
  max_frame_size : Int
  max_buffer_size : Int
  header_value : Array[Int]
  header_shift : Array[Int]
  header_bytes : Array[Int]
  frame_header_bytes : Array[Int]
  expected_length : Array[Int]
}

///|
pub fn Decoder::new(
  max_frame_size? : Int = 1048576,
  max_buffer_size? : Int = max_frame_size + 5,
) -> Decoder {
  Decoder::{
    buffer: [],
    max_frame_size,
    max_buffer_size,
    header_value: [0],
    header_shift: [0],
    header_bytes: [0],
    frame_header_bytes: [0],
    expected_length: [-1],
  }
}

///|
/// Number of bytes retained while waiting for a complete frame.
pub fn Decoder::buffered(self : Decoder) -> Int {
  self.header_bytes[0] + self.frame_header_bytes[0] + self.buffer.length()
}

///|
/// Discard partial data so a caller can recover at a known boundary.
pub fn Decoder::reset(self : Decoder) -> Unit {
  self.buffer.clear()
  self.header_value[0] = 0
  self.header_shift[0] = 0
  self.header_bytes[0] = 0
  self.frame_header_bytes[0] = 0
  self.expected_length[0] = -1
}

///|
/// Feed any chunk size and return every complete frame now available.
pub fn Decoder::feed(
  self : Decoder,
  chunk : Bytes,
) -> Result[Array[Bytes], FrameError] {
  let frames : Array[Bytes] = []
  for byte in chunk {
    if self.expected_length[0] < 0 {
      let part = byte.to_int()
      let byte_index = self.header_bytes[0]
      if byte_index == 4 && ((part & 0x80) != 0 || (part & 0x78) != 0) {
        return Err(MalformedVarint)
      }
      self.header_value[0] = self.header_value[0] |
        ((part & 0x7f) << self.header_shift[0])
      self.header_bytes[0] = byte_index + 1
      if (part & 0x80) == 0 {
        let length = self.header_value[0]
        if length > self.max_frame_size {
          return Err(FrameTooLarge(length, self.max_frame_size))
        }
        self.expected_length[0] = length
        self.frame_header_bytes[0] = self.header_bytes[0]
        self.header_value[0] = 0
        self.header_shift[0] = 0
        self.header_bytes[0] = 0
        if length == 0 {
          frames.push(b"")
          self.expected_length[0] = -1
          self.frame_header_bytes[0] = 0
        }
      } else {
        self.header_shift[0] = self.header_shift[0] + 7
      }
    } else {
      self.buffer.push(byte)
      if self.buffer.length() == self.expected_length[0] {
        frames.push(Bytes::from_array(self.buffer))
        self.buffer.clear()
        self.expected_length[0] = -1
        self.frame_header_bytes[0] = 0
      }
    }
    let retained = self.buffered()
    if retained > self.max_buffer_size {
      let actual = retained
      self.reset()
      return Err(BufferLimitExceeded(actual, self.max_buffer_size))
    }
  }
  Ok(frames)
}

///|
/// Signal end-of-input. A partial header or payload is an explicit error.
pub fn Decoder::finish(self : Decoder) -> Result[Unit, FrameError] {
  if self.buffered() == 0 && self.expected_length[0] < 0 {
    Ok(())
  } else {
    Err(NeedMore)
  }
}
