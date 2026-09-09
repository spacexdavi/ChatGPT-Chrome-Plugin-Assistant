# ChatGPT 扩展安装助手（Windows 10 / 11）

这是非官方安装辅助脚本，目标是 OpenAI 发布的 ChatGPT 浏览器控制／侧边栏扩展：
https://chromewebstore.google.com/detail/chatgpt/hehggadaopoacecdllhhajmbjkdcmajg

扩展 ID：`hehggadaopoacecdllhhajmbjkdcmajg`。

## 使用方法

1. **先将整个 ZIP 解压**到普通文件夹，再双击 `Start.cmd`。不要直接在 ZIP 预览中运行。
2. 脚本校验随包附带的 Google 官方 CRX，解压到本机固定目录，并复制扩展目录路径、打开 Chrome 扩展管理页。
3. 在你打算使用的 Chrome 个人资料中，开启右上角**开发者模式**，点击**加载已解压的扩展程序**，在选择文件夹窗口粘贴复制的路径并确认。
4. 扩展卡片显示 ChatGPT 后，从浏览器工具栏打开它，完成桌面应用连接。在 ChatGPT / Codex 桌面应用的“设置 → 计算机使用”中确认 Chrome 已连接。安装浏览器扩展不等于安装桌面应用。

脚本显示 `Prepared` 仅表示文件准备完成，**不代表已安装或已连接成功**。本工具将准备过程自动化，仍需完成 Chrome 的加载操作。

## 附带的官方包

- Google 官方下载接口取得，2026-09-09 验证版本：`1.26.901.11451`。
- `Start.cmd` 优先使用 `official.crx`，不依赖香港 Google 账号访问商店页面。若随包没有该文件，才尝试在线下载。
- 本机必须已安装 Google Chrome；无需管理员权限、Python 或 Node.js。
- `Download-Latest.cmd` 尝试从 Google 下载当时适用于本机 Chrome 的版本。下载接口受网络和 Google 的服务规则影响，无法保证所有地区都成功。
- 该方式无法解决 ChatGPT 服务本身的网络、账号、地区或工作空间功能限制。

## 文件和更新

准备后的文件保存在 `%LOCALAPPDATA%\ChatGPT-Extension-Helper\run-...\extension`。**加载后请保留该目录。** 每次运行创建新目录，不会覆盖已加载版本。

开发者模式加载的扩展没有商店正常的自动更新。需要更新时运行 `Download-Latest.cmd`，准备成功后，在扩展页面移除旧的开发者模式版本，再加载新目录。移除扩展可能清除扩展的本地设置。重复运行 `Start.cmd` 使用的仍是附带版本，不保证更新。

若不再使用，在 `chrome://extensions` 中移除 ChatGPT 扩展，然后手动删除对应的 `run-...` 目录。仅删除文件夹不会自动卸载扩展。

## 校验和权限

脚本会核对 CRX3 格式、固定扩展 ID、与该 ID 对应的开发者 RSA 签名及 ZIP 路径。它不实现 Chrome 商店的完整验证器；若未来包格式或签名算法变化，会失败并停止。原始 CRX 保持不变。

为保持原 ID，解压后会在 manifest.json 写入签名中的公钥，并跳过仅供商店使用的 `_metadata`。保留 ID 有助于原生消息通信，但最终连接仍需在实际 Chrome 和桌面应用中确认。

该官方扩展申请浏览记录、调试器、下载及所有网站访问等广泛权限。脚本会显示权限清单，请在加载前阅读。`receipt.json` 记录版本、权限和原始包 SHA-256。

脚本不修改 Chrome 个人资料、注册表、企业策略或 Google 账号地区，不关闭安全浏览，不请求账号密码；运行时会用扩展路径覆盖剪贴板。启动器仅对当前 PowerShell 进程设置执行策略，不永久修改系统执行策略。

## 故障处理

- 出现红色失败提示：准备未完成，请保留错误原文；不要将部分解压目录加载到 Chrome。
- 下载失败：优先使用附带官方 CRX 的 `Start.cmd`；在线更新要求能够连接 Google 下载服务。
- 找不到“开发者模式”或被管理员禁止：联系设备管理员；脚本不会覆盖管理策略。
- 已加载但未连接：更新并启动桌面应用，确认使用同一个 Chrome 个人资料，按桌面应用提示设置浏览器集成。
- Chrome 阻止加载：以 Chrome 实际提示为准。本方案不能保证受管理环境或未来 Chrome 版本允许加载。

## 验证范围和来源

已在 Windows PowerShell 5.1 中，使用真实下载的上述版本测试签名校验、解压、manifest 处理和准备完成状态；另测损坏包、错误 ID 和非 CRX 拒绝行为。未替你安装扩展，也未验证香港账号下的实际加载和桌面连接。

- OpenAI 浏览器扩展说明：https://learn.chatgpt.com/zh-Hans/docs/chrome-extension
- Chrome 安装限制：https://developer.chrome.com/docs/extensions/how-to/distribute/install-extensions
- Chrome 137 移除命令行加载：https://groups.google.com/a/chromium.org/g/chromium-extensions/c/1-g8EFx2BBY
- CRX3 格式：https://github.com/chromium/chromium/blob/main/components/crx_file/crx3.proto

开发者测试可运行：
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -PrepareOnly -CrxPath .\official.crx -Destination .\test-output`

此参数只准备文件，不打开浏览器、不覆盖剪贴板、不安装扩展。
