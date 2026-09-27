///|
/// Entry point for the CLI or runnable program in this template.
/// Keep main focused; move logic into the library package.
/// Run with `moon run cmd/main` from the project root.
fn main {
  let stream = @frame.encode_frames([b"hello", b"from", b"MoonFraming"])
  match @frame.decode_all(stream) {
    Ok(frames) => {
      println("decoded frames: \{frames.length()}")
      println("last payload bytes: \{frames[2].length()}")
    }
    Err(_) => println("decode failed")
  }
}
