# MoonFraming

MoonFraming 是纯 MoonBit 的增量分帧基础库。它把任意字节流恢复为消息边界，正确处理拆包、粘包、截断、畸形长度、资源超限和意外损坏。它同时支持可变长度头、固定宽度长度头和分隔符，可用于 RPC、数据库协议、消息系统、文本协议和文件记录格式。

## 当前能力

- 最多五字节、31 位有界 unsigned LEB128
- 一至四字节固定长度头，支持大小端、字段偏移、长度修正和跳过头部
- 单字节或多字节分隔符，可保留或去除结束符
- 单帧、批量流及任意分片输入的增量解码
- 帧大小与累计缓冲双重预算
- 明确的截断、畸形、超限及校验错误
- 可选 IEEE CRC-32 受保护帧及其增量解码器
- Wasm、Wasm-GC、JavaScript 三后端 CI

## 安装与运行

已发布至 [mooncakes.io](https://mooncakes.io/docs/Morris-C17/moonframing/)，可直接安装：

```bash
moon add Morris-C17/moonframing
```

也可以从源码运行：

```bash
git clone https://github.com/Morris-C17/moonframing.git
cd moonframing
moon check --deny-warn
moon build --deny-warn
moon test --deny-warn
moon run cmd/main
moon run examples/basic
moon run examples/codecs
moon run bench/main --target js
```

## 最小使用示例

```moonbit
let decoder = @moonframing.Decoder::new(max_frame_size=4096)
let wire = @moonframing.encode_frame(b"hello")
match decoder.feed(wire) {
  Ok(frames) => assert_true(frames[0] == b"hello")
  Err(_) => fail("valid frame")
}
```

## 协议与边界

默认格式为 `uLEB128(payload_length) || payload`；需要对接现有协议时可使用 `LengthDelimitedCodec`；行协议可使用 `DelimiterDecoder`。校验格式在 payload 后追加大端 CRC-32。CRC-32 只能检测意外损坏，不能替代认证或加密。项目不实现 socket、TLS、压缩和具体异步运行时。

## 文档

- [设计说明](docs/design.md)
- [线格式与错误语义](docs/protocol.md)
- [测试说明与覆盖矩阵](docs/testing.md)
- [与 tokio-util 的能力对照](docs/tokio-comparison.md)
- [安全与资源限制](docs/security.md)
- [十月改造计划](OCTOBER_PLAN.md)
- [可类型检查的示例](README.mbt.md)
- [项目申报书](PROJECT_PLAN.md)
- [版本记录](CHANGELOG.md)

完整可执行示例位于 `examples/basic`。GitHub Actions 会检查格式、编译、三个后端的测试，并实际运行该示例。

Apache-2.0 licensed.
