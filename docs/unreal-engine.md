# Unreal Engine on the build agents

The agents ship an **installed build of Unreal Engine compiled from Epic's GitHub source**, at the
tag given by the `UE_GIT_TAG` build arg / Jenkins parameter (default `5.8.3-release`).

Compiling the engine takes hours, so it lives in its own images, which are only rebuilt on purpose:

| Image | Built from | Contents |
| --- | --- | --- |
| `unreal-engine-linux:<tag>` | `unreal/linux/Dockerfile` | `/opt/UnrealEngine`, `/opt/android-sdk` (data-only, `FROM scratch`) |
| `unreal-engine-windows:<tag>` | `unreal/windows/Dockerfile` | `C:\UnrealEngine` (on nanoserver) |

Images are **pushed to `localhost:5000`** and **pulled through `registry.ohmvir.dev`**. The pull
hostname sits behind Cloudflare, whose 100MB request-body limit rules it out for layer uploads. The
Jenkinsfile logs in to both with the `docker_server_priv_registry` credential.

The agent images (`linux/`, `windows/`) only copy the engine out of these images. On Linux the copy
uses `COPY --link`, so the engine layers keep the same digest when anything else in the agent
changes, and are neither re-pushed nor re-pulled.

## Target platforms

Each target platform is built on one agent only. When both hosts could build a platform, it goes on Linux.

| Target | Agent | How |
| --- | --- | --- |
| Linux x64 (game + server) | Linux | `WithLinux`, `WithServer` |
| Android, incl. Meta Quest | Linux | `WithAndroid`; NDK r27c, build-tools 35.0.1, platform 35, JDK 21 |
| OpenXR | Linux + Windows | Built-in OpenXR plugin (Quest via Android, PC VR via Win64) |
| Windows x64 (game + server) | Windows | `WithWin64`, `WithServer`; MSVC 14.50, Windows SDK 26100 |
| Windows ARM64 / ARM64EC | Windows | MSVC 14.50 ARM64 tools. Any Windows ARM64 option in the tag's `InstalledEngineBuild.xml` is enabled automatically. If there is none, the build logs a warning, and the option can be passed through `UE_BUILDGRAPH_EXTRA_ARGS` |
| Microsoft Store (UWP replacement) | Windows | Public Microsoft GDK, used by UE 5.8's MSGameStore / MSGamingRuntime plug-ins |
| Xbox Series X\|S | — | Needs the NDA-only GDKX and Epic's console platform extensions (see below) |

Platforms that a host never builds are excluded twice. `Setup.sh`/`Setup.bat --exclude=...`
skips their dependencies, and the `-set:With<Platform>=false` options skip their builds. The
editor/template DDC is generated (`WithDDC=true`), and client-only targets are not built
(`WithClient=false`).

| | Linux | Windows |
| --- | --- | --- |
| `UE_ROOT` | `/opt/UnrealEngine` | `C:\UnrealEngine` |
| Run UAT | `$UE_ROOT/Engine/Build/BatchFiles/RunUAT.sh` | `%UE_ROOT%\Engine\Build\BatchFiles\RunUAT.bat` |

## One-time setup

1. **GitHub access.** Create a GitHub account dedicated to CI (recommended, since a classic token
   can read everything the account can). Link it to an Epic account at
   <https://www.unrealengine.com/ue-on-github> and accept the invitation to the EpicGames
   organization. Then create a classic personal access token with the `repo` scope.
2. **Jenkins credential.** Add a *Secret text* credential with the ID `epic_github_token`
   holding that token.
   - **Linux** passes it as a BuildKit secret. It never appears in a layer or in the image history.
   - **Windows** (the classic builder has no secrets) passes it as a build arg to a throwaway
     `source` stage only. It ends up in that stage's local image history on the Windows build
     host, but never in the pushed images.
3. **Windows Docker host.** Containers default to 20 GB of disk, which is far too little for an
   engine build. Set `{ "storage-opts": ["size=400GB"] }` in
   `C:\ProgramData\docker\config\daemon.json` and restart Docker.
   - The build runs with `-m` (Jenkins parameter `UE_WINDOWS_BUILD_MEMORY`, default `32g`),
     because Hyper-V isolated builds default to very little memory.
4. **Hardware.** Budget about 300 GB of free disk per host for the first build. Use 32 GB of RAM
   or more; UnrealBuildTool scales its parallelism to the available cores and memory. Expect
   several hours per host, including DDC generation.
5. **First build.** Run the pipeline with **`BUILD_UNREAL_ENGINE` checked**. This builds and pushes
   both engine images, then the agents. The agent builds fail with "not found" until the engine
   image for `UE_GIT_TAG` exists in the registry.

## Changing engine version

Run the pipeline with `BUILD_UNREAL_ENGINE` checked and the new `UE_GIT_TAG` (for example
`5.8.4-release`), then change the parameter's default in the `Jenkinsfile`.
- **Linux:** the downloaded dependency packs are kept in a BuildKit cache mount, so only changed
  packs are fetched.
- **Windows:** the Visual Studio and GDK layers are reused.
- If the new version renames an installed-build option, the build stops before compiling and
  names the missing option.

Extra BuildGraph options can be passed with `--build-arg UE_BUILDGRAPH_EXTRA_ARGS=...`. For
example, `-set:GameConfigurations=Development;Shipping` skips the DebugGame configuration.

## Using it from a pipeline

```sh
# Linux agent: Linux x64 game, Linux dedicated server (-server -noclient), Android / Meta Quest
"$UE_ROOT/Engine/Build/BatchFiles/RunUAT.sh" BuildCookRun -project="$WORKSPACE/MyGame.uproject" \
  -platform=Linux -clientconfig=Shipping -build -cook -stage -pak -archive \
  -archivedirectory="$WORKSPACE/out" -unattended -utf8output -nop4
"$UE_ROOT/Engine/Build/BatchFiles/RunUAT.sh" BuildCookRun -project="$WORKSPACE/MyGame.uproject" \
  -platform=Linux -server -noclient -serverconfig=Shipping -build -cook -stage -pak -archive \
  -archivedirectory="$WORKSPACE/out-server" -unattended -utf8output -nop4
"$UE_ROOT/Engine/Build/BatchFiles/RunUAT.sh" BuildCookRun -project="$WORKSPACE/MyGame.uproject" \
  -platform=Android -cookflavor=ASTC -clientconfig=Shipping -build -cook -stage -pak -package \
  -archive -archivedirectory="$WORKSPACE/out-android" -unattended -utf8output -nop4
```

```bat
rem Windows agent: Win64 (add -clientarchitecture=arm64 or arm64ec for Windows on ARM; -server -noclient for a server)
"%UE_ROOT%\Engine\Build\BatchFiles\RunUAT.bat" BuildCookRun -project="%WORKSPACE%\MyGame.uproject" ^
  -platform=Win64 -clientconfig=Shipping -build -cook -stage -pak -archive ^
  -archivedirectory="%WORKSPACE%\out" -unattended -utf8output -nop4
```

For Meta Quest, enable the **OpenXR** plugin in the project; that is the default for the VR template.
Meta's own *Meta XR* plugin is optional and project-level.

Projects must be built with this engine. The `.uproject`'s `EngineAssociation` doesn't matter
when you call this engine's `RunUAT` directly. Fab/Marketplace binary plugins built for the
Launcher release of the same version normally load in a source build of the same release tag.

## Not covered

- **Xbox Series X|S** needs two things on top of this source build:
  - Microsoft's GDKX, which is NDA-only (ID@Xbox or a publisher).
  - Epic's console platform extensions, which Epic grants separately to approved console
    developers.

  The extensions are copied into the engine tree before building, after which the Windows engine
  image can be extended with them.
- **UWP** is not a UE5 platform. Store distribution goes through Win64 plus the Microsoft GDK
  plug-ins (`.msixvc`), which the Windows engine and agent support.
