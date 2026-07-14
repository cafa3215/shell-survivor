# 版本发布目录

- `latest.json`：当前版本（作品集 CMS 每天巡检此文件）
- `x.y.z.json`：历史归档

发版：

```powershell
cd e:\Desktop\Ai\portfolio
node scripts/publish-release.mjs ..\<项目文件夹> <版本号> "更新说明"
```

然后重新部署该子项目；再到 CMS「发布」页确认。
