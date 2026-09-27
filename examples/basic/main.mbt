///|
fn main {
  let wire = @frame.encode_frames([b"first", b"second"])
  let decoder = @frame.Decoder::new(max_frame_size=1024)
  let split = 3
  ignore(decoder.feed(wire[:split].to_owned()))
  match decoder.feed(wire[split:].to_owned()) {
    Ok(frames) => println("decoded frames: \{frames.length()}")
    Err(_) => println("decode failed")
  }
}
