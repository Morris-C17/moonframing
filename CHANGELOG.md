# Changelog

## 0.2.0 - 2026-10

- Added configurable fixed-width length fields with endian, offset, adjustment, and skip controls.
- Added delimiter-based framing with multi-byte boundary support.
- Added an incremental decoder for CRC-32 protected frames.
- Reworked the uLEB128 decoder into a linear header/payload state machine.
- Fixed false buffer-limit failures for large chunks containing many valid small frames.
- Added fragmentation, overflow, coalescing, and resource-limit tests.
- Added a reproducible throughput benchmark, a tokio-util comparison, and security guidance.

## 0.1.0 - 2026-09-23

- Implement bounded 31-bit unsigned LEB128 framing.
- Add one-shot, finite-stream, and incremental decoders.
- Add explicit truncation, malformed input, frame, and buffer limit errors.
- Add optional IEEE CRC-32 protected frames.
- Add runnable example, protocol documentation, tests, and multi-backend CI.
