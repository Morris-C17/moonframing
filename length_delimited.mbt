///|
/// Byte order used by fixed-width length fields.
pub enum ByteOrder {
  BigEndian
  LittleEndian
}

///|
pub fn big_endian() -> ByteOrder {
  BigEndian
}

///|
pub fn little_endian() -> ByteOrder {
  LittleEndian
}

///|
/// A configurable fixed-width length-delimited codec.
///
/// Its framing rules mirror the useful configuration points of mature
/// length-delimited codecs: field width, field offset, byte order, signed
/// adjustment, bytes skipped before the returned payload, and resource limits.
pub struct LengthDelimitedCodec {
  buffer : Array[Byte]
  length_field_offset : Int
  length_field_length : Int
  length_adjustment : Int
  num_skip : Int
  byte_order : ByteOrder
  max_frame_size : Int
  max_buffer_size : Int
}

///|
/// Construct a fixed-width codec. Field widths from one through four bytes are
/// supported. Invalid configurations are rejected before any input is read.
pub fn LengthDelimitedCodec::new(
  length_field_offset? : Int = 0,
  length_field_length? : Int = 4,
  length_adjustment? : Int = 0,
  num_skip? : Int = length_field_offset + length_field_length,
  byte_order? : ByteOrder = BigEndian,
  max_frame_size? : Int = 1048576,
  max_buffer_size? : Int = max_frame_size +
    length_field_offset +
    length_field_length,
) -> Result[LengthDelimitedCodec, FrameError] {
  if length_field_offset < 0 {
    return Err(InvalidConfiguration("length_field_offset must be non-negative"))
  }
  if length_field_length < 1 || length_field_length > 4 {
    return Err(
      InvalidConfiguration("length_field_length must be between 1 and 4"),
    )
  }
  let field_end = length_field_offset + length_field_length
  if num_skip < 0 || num_skip > field_end {
    return Err(
      InvalidConfiguration(
        "num_skip must be between zero and the end of the length field",
      ),
    )
  }
  if max_frame_size < 0 || max_buffer_size < field_end {
    return Err(
      InvalidConfiguration("resource limits are smaller than the frame header"),
    )
  }
  Ok(LengthDelimitedCodec::{
    buffer: [],
    length_field_offset,
    length_field_length,
    length_adjustment,
    num_skip,
    byte_order,
    max_frame_size,
    max_buffer_size,
  })
}

///|
fn read_fixed_length(
  data : Bytes,
  offset : Int,
  width : Int,
  order : ByteOrder,
) -> UInt {
  let mut value = 0U
  match order {
    BigEndian =>
      for i = 0; i < width; i = i + 1 {
        value = (value << 8) | data[offset + i].to_uint()
      }
    LittleEndian =>
      for i = 0; i < width; i = i + 1 {
        value = value | (data[offset + i].to_uint() << (i * 8))
      }
  }
  value
}

///|
fn append_fixed_length(
  output : Array[Byte],
  value : Int,
  width : Int,
  order : ByteOrder,
) -> Unit {
  let unsigned = value.reinterpret_as_uint()
  match order {
    BigEndian =>
      for i = width - 1; i >= 0; i = i - 1 {
        output.push((unsigned >> (i * 8)).to_byte())
      }
    LittleEndian =>
      for i = 0; i < width; i = i + 1 {
        output.push((unsigned >> (i * 8)).to_byte())
      }
  }
}

///|
fn max_value_for_width(width : Int) -> Int {
  if width == 4 {
    0x7fffffff
  } else {
    (1 << (width * 8)) - 1
  }
}

///|
/// Encode one item using this codec's header layout.
pub fn LengthDelimitedCodec::encode(
  self : LengthDelimitedCodec,
  payload : Bytes,
) -> Result[Bytes, FrameError] {
  if payload.length() > self.max_frame_size {
    return Err(FrameTooLarge(payload.length(), self.max_frame_size))
  }
  let field_end = self.length_field_offset + self.length_field_length
  let declared = payload.length() +
    self.num_skip -
    field_end -
    self.length_adjustment
  if declared < 0 {
    return Err(InvalidLengthAdjustment(declared))
  }
  let field_max = max_value_for_width(self.length_field_length)
  if declared > field_max {
    return Err(LengthFieldOverflow(declared, field_max))
  }
  let output : Array[Byte] = []
  for _i = 0; _i < self.length_field_offset; _i = _i + 1 {
    output.push(0)
  }
  append_fixed_length(
    output,
    declared,
    self.length_field_length,
    self.byte_order,
  )
  for byte in payload {
    output.push(byte)
  }
  Ok(Bytes::from_array(output))
}

///|
fn LengthDelimitedCodec::try_decode(
  self : LengthDelimitedCodec,
) -> Result[(Bytes, Int), FrameError] {
  let field_end = self.length_field_offset + self.length_field_length
  if self.buffer.length() < field_end {
    return Err(NeedMore)
  }
  let snapshot = Bytes::from_array(self.buffer)
  let raw = read_fixed_length(
    snapshot,
    self.length_field_offset,
    self.length_field_length,
    self.byte_order,
  )
  if raw > 0x7fffffffU {
    return Err(FrameTooLarge(0x7fffffff, self.max_frame_size))
  }
  let total = field_end + raw.reinterpret_as_int() + self.length_adjustment
  if total < self.num_skip {
    return Err(InvalidLengthAdjustment(total))
  }
  let payload_length = total - self.num_skip
  if payload_length > self.max_frame_size {
    return Err(FrameTooLarge(payload_length, self.max_frame_size))
  }
  if self.buffer.length() < total {
    return Err(NeedMore)
  }
  Ok((snapshot[self.num_skip:total].to_owned(), total))
}

///|
/// Feed a fragmented or coalesced stream and return every complete item.
pub fn LengthDelimitedCodec::feed(
  self : LengthDelimitedCodec,
  chunk : Bytes,
) -> Result[Array[Bytes], FrameError] {
  let frames : Array[Bytes] = []
  for byte in chunk {
    self.buffer.push(byte)
    match self.try_decode() {
      Ok((payload, consumed)) => {
        frames.push(payload)
        let snapshot = Bytes::from_array(self.buffer)
        self.buffer.clear()
        for remaining in snapshot[consumed:] {
          self.buffer.push(remaining)
        }
      }
      Err(NeedMore) => ()
      Err(error) => return Err(error)
    }
    if self.buffer.length() > self.max_buffer_size {
      let actual = self.buffer.length()
      self.buffer.clear()
      return Err(BufferLimitExceeded(actual, self.max_buffer_size))
    }
  }
  Ok(frames)
}

///|
pub fn LengthDelimitedCodec::buffered(self : LengthDelimitedCodec) -> Int {
  self.buffer.length()
}

///|
pub fn LengthDelimitedCodec::reset(self : LengthDelimitedCodec) -> Unit {
  self.buffer.clear()
}

///|
pub fn LengthDelimitedCodec::finish(
  self : LengthDelimitedCodec,
) -> Result[Unit, FrameError] {
  if self.buffer.length() == 0 {
    Ok(())
  } else {
    Err(NeedMore)
  }
}
