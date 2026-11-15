# content.zipe checker for Minecraft Bedrock

Checks your PC for Minecraft Bedrock packs that contain `content.zipe`, the file behind a new resource pack exploit. Windows only, read-only.

## What's going on

A resource pack with a `content.zipe` file inside can run hidden scripts in your game. You don't even need to download anything yourself: joining a server or Realm is enough, because it can send you its packs automatically. Downloaded `.mcpack`, `.mcaddon` and `.mcworld` files can carry it too.

It can delete your worlds, post on Realms Stories as you (which can get you banned), make you join servers to grab your IP and mess with your friends list. On Windows it can also download and run real malware.

Affects Bedrock on all platforms (PC, phone, console). Java is safe. It's already been reported to Mojang.

**Don't panic.** It only went public recently, so the chance you already have a bad pack is low. It may have been used before that, though, so it's worth checking once.

More info: [Reddit](https://www.reddit.com/r/ibxtoycat/comments/1xwrux7/resource_packs_can_contain_malware_now) · [X](https://x.com/theaddonn/status/2121968232743727464)

## Stay safe until it's patched

- Don't join random servers or Realms
- Only use packs from people you trust
- Update Minecraft as soon as the fix is out
- Send this page to friends who play Bedrock

## Check your PC

1. **[Download check-content-zipe.bat](https://github.com/AxmBro/content-zipe-checker/releases/latest/download/check-content-zipe.bat)**
2. Double-click it. If Windows asks whether to run it, click **Run** (or **More info > Run anyway**)

It's a diagnostic tool: it only reads files and tells you what it found. Nothing is changed, deleted or sent. It can't tell if a pack is actually malicious, and a clean result only covers what's on your PC right now.

**Don't trust random files, including this one.** It's plain text: read it in Notepad, or paste it into any AI and ask what it does. Only download it from this page.

## If it finds something

`content.zipe` means a pack **can** run hidden scripts, not that it did. If you don't fully trust where the pack came from:

| Section | What to do |
|---|---|
| Installed in Minecraft | Remove the pack from Minecraft or delete its folder |
| Downloaded from servers | Close Minecraft, delete the folder, don't join that server again |
| Files on your PC | Don't open or import it, delete it |

Played with a pack you don't trust? Run a full scan in Windows Security.

## Phone and console

The tool is Windows only. The exploit isn't.

- **Phone:** a pack file is a ZIP. Rename it to `.zip`, extract it and look for `content.zipe`. For installed packs, check the folders below.
- **Console:** you can't see the files. Go to **Settings > Storage**, delete packs you don't trust and clear the cached data. If a pack isn't listed there, follow "Stay safe" above.

## Technical details

What it scans, for both Minecraft and Minecraft Preview:

| Location | Folder |
|---|---|
| Installed packs, worlds, Marketplace | `%APPDATA%\Minecraft Bedrock` |
| Packs from servers | `%TEMP%\Minecraft Bedrock\minecraftpe` |
| Old Microsoft Store version (everything) | `%LOCALAPPDATA%\Packages\Microsoft.MinecraftUWP_8wekyb3d8bbwe` |
| Downloads, Desktop | your user folders |

- Opens every `.mc*` file that is a ZIP (`.mcpack`, `.mcaddon`, `.mcworld`, `.mctemplate`, `.mcproject`, `.mceditoraddon`...) and every `.zip`, including packs nested up to 3 levels deep. `.rar` and `.7z` aren't checked, extract them first
- Skips OneDrive online-only files, so nothing gets downloaded
- The `.bat` is a batch/PowerShell hybrid: its first lines start PowerShell, which runs the rest of the same file

### Checking by hand

Look in `resource_packs`, `behavior_packs`, `skin_packs`, `world_templates`, the `development_*` folders and `minecraftWorlds` (worlds can carry their own packs).

| Platform | Folder |
|---|---|
| Windows | `%APPDATA%\Minecraft Bedrock\Users\` (every `games\com.mojang` inside) |
| Windows, packs from servers | `%TEMP%\Minecraft Bedrock\minecraftpe\packcache` |
| Android 12+ | `Android/data/com.mojang.minecraftpe/files/games/com.mojang` |
| Android 11 and older | `games/com.mojang` |
| iPhone / iPad | Files app: `On My iPhone > Minecraft > games > com.mojang` |

Windows paths go into the File Explorer address bar. For Preview, use `Minecraft Bedrock Preview`.

---

I made this to check my own PC and figured others might want to check theirs too. Made by AmBro ([Better Bedrock](https://betterbedrock.com)) with help from Claude.
