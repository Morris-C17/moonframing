# 与 tokio-util LengthDelimitedCodec 的对照

初审反馈建议参考 Rust `tokio-util::codec::LengthDelimitedCodec`。MoonFraming 没有复制它的代码，而是学习其配置模型，再按 MoonBit 的 `Bytes` 和多后端特点重新实现。

| 能力 | tokio-util | MoonFraming 0.2 |
|---|---|---|
| 固定长度字段 | 1、2、4、8 字节 | 1 至 4 字节 |
| 字节序 | 大端、小端 | 大端、小端 |
| 字段偏移 | 支持 | 支持 |
| 有符号长度修正 | 支持 | 支持 |
| 跳过头部 | 支持 | 支持 |
| 最大帧限制 | 支持 | 支持 |
| 缓冲预算 | 按 BytesMut 容量管理 | 显式残留数据上限 |
| 可变长度头 | 未内置 | uLEB128 |
| 分隔符帧 | LinesCodec 等其他 codec | 多字节分隔符 |
| 完整性校验 | 由上层完成 | 内置可选 CRC-32 |
| 运行时 | Tokio | 不绑定 I/O 或异步运行时 |

## 参考范围与许可证

- 项目：tokio-util `LengthDelimitedCodec`
- 源码：https://github.com/tokio-rs/tokio/blob/master/tokio-util/src/codec/length_delimited.rs
- 许可证：MIT
- 参考范围：长度字段宽度、偏移、字节序、长度修正、跳过字节数、最大帧长度等 API 语义。
- 未复制内容：Rust 源码、Tokio 异步上下文、`BytesMut` 实现和 trait 结构。
