# 车载播放器 CarPlayer

自用的 iPhone 视频播放器：本地视频 + 网络直链、外挂 SRT 字幕（UTF-8 / GBK 都行）、横屏大按钮、倍速、后台播放、连播。

## 安装
1. 到 Releases 下载最新的 `CarPlayer-unsigned.ipa`
2. 用你自己的证书签名（如 Sideloadly、全能签、爱思助手等），Bundle ID 可改
3. 装好后在「文件」App →「我的 iPhone」→「车载播放器」里放视频和同名 .srt

## 支持格式
mp4 / m4v / mov / m3u8，音频 mp3 / m4a / aac / wav / flac。mkv、avi 系统播放器不支持，需先转成 mp4。

## CarPlay
已带 CarPlay 列表界面（音频方式播放）。只有签名证书含 `com.apple.developer.carplay-audio` 权限才会出现在车机上，见 `CarPlayer.entitlements`。CarPlay 不允许普通 App 在车机屏幕放视频画面。
