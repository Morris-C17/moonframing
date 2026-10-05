# MoonFraming 线格式

## 基础帧

```text
+----------------------+------------------+
| uLEB128 payload size | payload bytes    |
+----------------------+------------------+
```

- 长度是非负、最多五字节的 uLEB128。
- 当前实现接受的最大编码值为 31 位非负整数。
- `payload size` 不包含长度前缀本身。
- 多个帧可以直接连接，中间没有分隔符。

例如，三字节载荷 `61 62 63` 编码为：

```text
03 61 62 63
```

## CRC-32 校验帧

```text
+-------------------+---------------+--------------------+
| uLEB128 body size | payload bytes | CRC-32, big-endian |
+-------------------+---------------+--------------------+
```

`body size` 等于载荷长度加四。校验值使用 IEEE CRC-32 多项式，并按大端字节序附加。少于四字节的帧返回 `MissingChecksum`，计算结果不一致返回 `ChecksumMismatch`。

## 固定宽度长度帧

```text
+----------------+--------------+------------------+
| optional prefix| length field | remaining bytes  |
+----------------+--------------+------------------+
```

`LengthDelimitedCodec` 支持一至四字节长度字段。`length_field_offset` 指定字段之前的字节数，`length_adjustment` 在读取声明长度后修正整帧终点，`num_skip` 指定返回数据开始的位置。默认返回长度字段之后的载荷。

两字节大端长度和三字节载荷 `abc` 为：

```text
00 03 61 62 63
```

## 分隔符帧

`DelimiterDecoder` 把分隔符之前的数据当作一帧。分隔符可以是 `\n`、`\r\n` 或其他非空字节序列，并可以横跨两次 `feed`。默认去除分隔符，也可设置 `strip_delimiter=false` 保留它。

## 错误语义

| 错误 | 含义 |
|---|---|
| `NeedMore` | 当前字节不足以组成完整帧；在 `finish` 后表示截断 |
| `MalformedVarint` | 长度前缀超过五字节或高位非法 |
| `InvalidConfiguration` | codec 宽度、偏移、跳过字节或资源配置无效 |
| `LengthFieldOverflow` | 编码长度无法放入配置的固定宽度字段 |
| `InvalidLengthAdjustment` | 长度修正使帧终点落在返回起点之前 |
| `FrameTooLarge` | 声明的载荷超过允许的单帧上限 |
| `BufferLimitExceeded` | 保留字节与新输入之和超过缓冲预算 |
| `MissingChecksum` | 校验帧没有四字节 CRC-32 |
| `ChecksumMismatch` | 声明值与实际 CRC-32 不一致 |
