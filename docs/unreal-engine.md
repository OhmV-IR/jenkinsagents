# Unreal Engine on the build agents

Both agent images ship Epic's **prebuilt (Launcher/binary) Unreal Engine 5.8.3** at `UE_ROOT`.
Each target platform is installed on one agent only. When a platform can be built on both hosts,
it goes on Linux.

| Target | Agent | What the image provides |
| --- | --- | --- |
| Linux x64 | Linux | Engine incl. bundled clang toolchain |
| Android, incl. Meta Quest | Linux | Android SDK platform 35, build-tools 35.0.1, NDK r27c, JDK 21 |
| OpenXR | Linux + Windows | Built-in OpenXR plugin (Quest via Android, PC VR via Win64), no extra SDK |
| Windows x64 | Windows | Engine, MSVC 14.50 + Windows SDK 26100, UE prerequisites |
| Windows ARM64 / ARM64EC | Windows | MSVC 14.50 ARM64 tools (UE 5.8 supports ARM64 for game targets only) |
| Microsoft Store (UWP replacement) | Windows | Public Microsoft GDK for UE 5.8's MSGameStore / MSGamingRuntime plug-ins |
| Xbox Series X\|S | — | **Not possible with the binary engine**, see below |
| Dedicated server (Win/Linux) | — | **Not possible with the binary engine**, see below |

| | Linux | Windows |
| --- | --- | --- |
| `UE_ROOT` | `/opt/UnrealEngine` | `C:\UnrealEngine` |
| Run UAT | `$UE_ROOT/Engine/Build/BatchFiles/RunUAT.sh` | `%UE_ROOT%\Engine\Build\BatchFiles\RunUAT.bat` |

## One-time setup

Epic serves the engine only to logged-in accounts. Neither image can download it from Epic
directly, so you need to mirror the archives once. Host them anywhere the Docker hosts can reach
over HTTP(S), such as a LAN file server or a pre-signed object storage URL.

### Linux archive

1. Log in at <https://www.unrealengine.com/linux> and download `Linux_Unreal_Engine_5.8.3.zip`
   (about 25 GB). Upload it unchanged to your mirror.
2. Optional: run `sha256sum Linux_Unreal_Engine_5.8.3.zip` and put the result in the
   `UE_ARCHIVE_SHA256` default in `linux/Dockerfile`.

### Windows archive

The Windows engine exists only as a Launcher install, so you package one:

1. On any Windows PC, install **UE 5.8.3** in the Epic Games Launcher. Under *Options*:
   - **Deselect every target platform**: Android, iOS, Linux, Linux Arm64, tvOS, and so on.
     Android and Linux are built on the Linux agent.
   - Leave *Editor symbols for debugging* off.
   - Keep the defaults for everything else.
2. Run `tools\New-UnrealEngineArchive.ps1 -OutFile <path>\UnrealEngine-5.8.3-Win64.zip`.
   The script checks the version, refuses to package an install that still contains
   non-Windows platforms, drops `.pdb` files and prints the SHA256.
3. Upload the zip to your mirror. Optionally put the SHA256 in the `UE_ARCHIVE_SHA256` default
   in `windows/Dockerfile`.

Studios with paid Unreal seats can download the official `UnrealEngineInstaller.msi` instead.
Install it with `ENGINE_ANDROID_CHECKED=0 ENGINE_LINUX_CHECKED=0`, then package the result
with the same script.

### Jenkins credentials

Add two **Secret text** credentials holding the archive URLs. The `Jenkinsfile` passes them as
`--build-arg UE_ARCHIVE_URL`:

- `unreal_engine_linux_archive_url`
- `unreal_engine_windows_archive_url`

The URL is consumed only in the `unreal-engine` build stage. It never appears in the final
image's history.

### Docker hosts

- **Windows:** Windows containers have a 20 GB per-container disk limit by default, but the
  engine stage needs room for the zip plus the extracted engine. In
  `C:\ProgramData\docker\config\daemon.json`, set
  `{ "storage-opts": ["size=200GB"] }`, then restart the Docker service.
- **Linux:** allow roughly 150 GB of free space for the first build: the zip, the extracted
  engine, the image layer and the BuildKit cache.

## Using it from a pipeline

```sh
# Linux agent: Linux x64
"$UE_ROOT/Engine/Build/BatchFiles/RunUAT.sh" BuildCookRun -project="$WORKSPACE/MyGame.uproject" \
  -platform=Linux -clientconfig=Shipping -build -cook -stage -pak -archive \
  -archivedirectory="$WORKSPACE/out" -unattended -utf8output -nop4
# Linux agent: Android / Meta Quest (Quest uses ASTC textures)
"$UE_ROOT/Engine/Build/BatchFiles/RunUAT.sh" BuildCookRun -project="$WORKSPACE/MyGame.uproject" \
  -platform=Android -cookflavor=ASTC -clientconfig=Shipping -build -cook -stage -pak -package \
  -archive -archivedirectory="$WORKSPACE/out" -unattended -utf8output -nop4
```

```bat
rem Windows agent: Win64 (add -clientarchitecture=arm64 or arm64ec for Windows on ARM)
"%UE_ROOT%\Engine\Build\BatchFiles\RunUAT.bat" BuildCookRun -project="%WORKSPACE%\MyGame.uproject" ^
  -platform=Win64 -clientconfig=Shipping -build -cook -stage -pak -archive ^
  -archivedirectory="%WORKSPACE%\out" -unattended -utf8output -nop4
```

For Meta Quest, enable the **OpenXR** plugin in the project; that is the default for the VR template.
Meta's own *Meta XR* plugin is optional and project-level: vendor it into the project's
`Plugins/` folder if you need it.

## Not supported by the binary engine

- **Dedicated servers** (`-server`, Server targets): Epic's binary builds do not contain server
  binaries ("Server targets are not currently supported from this engine distribution"). You need
  an installed build made from source (`BuildGraph InstalledEngineBuild.xml
  -set:WithServer=true`). Build the Linux server on the Linux agent and the Windows server on the
  Windows agent.
- **Xbox Series X|S**: you need the GDKX, which Microsoft provides only under NDA through ID@Xbox
  or a publisher, and Epic's restricted console platform extensions, which require a source
  engine build. Neither can come from the public Launcher engine. The public GDK installed here
  covers PC/Store only.
- **UWP**: Unreal Engine 5 has no UWP target. Store distribution now goes through Win64 plus
  the Microsoft GDK plug-ins (`.msixvc`), which the Windows agent supports.
