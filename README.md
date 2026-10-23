# 车载播放器 CarPlayer

自用 iPhone 视频播放器：本地视频（相册/文件导入）、网络直链、m3u/txt 直播源按电视台分组、外挂 SRT 字幕（UTF-8 / GBK）、横屏大按钮、倍速、后台播放、连播，CarPlay 车机端。

## 安装
1. 到 Releases 下载 `CarPlayer-unsigned.ipa`
2. 用自己的证书签名后安装

## 直播源
「+ → 订阅频道列表」粘贴 m3u 或 txt 地址。支持 `group-title`、`tvg-logo`，以及 DIYP 格式（`央视频道,#genre#` 下面接 `CCTV-1,http://...`）。也可以把 .m3u/.txt 文件放进「文件 → 车载播放器」自动导入。

## CarPlay 车机
- 签名带 `com.apple.developer.carplay-maps`（见 `CarPlayer-video.entitlements`）：车机屏幕直接显示视频画面，左上「片库」选片，地图按钮快退/快进/上下一个。
- 签名带 `com.apple.developer.carplay-audio`（`CarPlayer.entitlements`）：车机上只有列表+声音。
- 两个都没有：不会出现在车机上。普通开发者证书一般没有这两个权限，需要 TrollStore 或含该权限的描述文件。

## 格式
mp4 / m4v / mov / m3u8；mkv、avi 需先转 mp4。
