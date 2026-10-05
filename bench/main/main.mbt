///|
fn main {
  let payload = Bytes::from_array(Array::make(1024, 97))
  let wire = @frame.encode_frame(payload)
  let iterations = 10000
  let start = @bench.monotonic_clock_start()
  let mut decoded = 0
  for _i = 0; _i < iterations; _i = _i + 1 {
    let decoder = @frame.Decoder::new(max_frame_size=2048)
    match decoder.feed(wire) {
      Ok(frames) => decoded = decoded + frames.length()
      Err(_) => abort("benchmark input must decode")
    }
  }
  let elapsed_us = @bench.monotonic_clock_end(start)
  let mib = (iterations * payload.length()).to_double() / 1048576.0
  println("decoded frames: \{decoded}")
  println("payload MiB: \{mib}")
  println("elapsed us: \{elapsed_us}")
  println("throughput MiB/s: \{mib * 1000000.0 / elapsed_us}")
}
