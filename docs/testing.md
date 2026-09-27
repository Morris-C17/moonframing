# MoonFraming 测试说明

## 运行方法

```bash
moon fmt --check
moon check --deny-warn
moon build --deny-warn
moon test --deny-warn --target wasm
moon test --deny-warn --target wasm-gc
moon test --deny-warn --target js
moon run examples/basic
```

GitHub Actions 对每次 push 和 pull request 执行相同检查，并分别运行 wasm、wasm-gc、JavaScript 三个后端。

## 当前测试矩阵

| 范围 | 验证内容 |
|---|---|
| uLEB128 | 小值、多字节值、截断和第五字节非法高位 |
| 基础帧 | 编码后可恢复原始载荷并报告消耗字节数 |
| 拆包 | 长度头和载荷可在任意读取边界分开输入 |
| 粘包 | 一次输入包含多个帧时按顺序全部输出 |
| 截断 | `finish` 对残留头部或载荷返回 `NeedMore` |
| 帧预算 | 载荷到齐前即可拒绝超过 `max_frame_size` 的声明 |
| 缓冲预算 | 输入累计超过 `max_buffer_size` 时立即拒绝 |
| CRC-32 | 正确载荷通过，缺失或被修改的校验值失败 |
| 重置 | 已知边界处清除残留状态后可重新使用解码器 |

仓库目前共有 11 个测试用例；一个用例可能包含多个断言。黑盒测试通过公开 API 验证调用者可见行为，白盒测试用于内部边界。

## 尚未覆盖

当前没有网络适配层，因此不宣称覆盖 socket 超时、背压或并发连接。也没有零拷贝性能基准。加入 `Reader/Writer` 适配与环形缓冲后，需要分别补充短读、连续小包、大帧和长连接内存稳定性测试。
