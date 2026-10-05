# Images and how they are built

The slow toolchains each live in their own image. The agents are built **on top of** or
**copy from** them, so editing an agent Dockerfile never re-runs the ESP-IDF install, the Visual
Studio install or the Unreal Engine build.

```
Linux                                         Windows
─────                                         ───────
cruizba/ubuntu-dind (pinned digest)           mcr.microsoft.com/windows/server:ltsc2025
  └─ esp-idf-linux:latest        [FROM]         └─ windows-buildtools:latest      [FROM]
       └─ jenkins-agent-linux    [FROM]              │   (choco tools, VS 2026, GDK)
            ├─ ndind             [FROM]              ├─ esp-idf-windows:latest     [FROM]
            └─ unreal-engine-linux:<tag>  [COPY]     │    └─ jenkins-agent-windows [FROM]
                                                     │         └─ unreal-engine-windows:<tag> [COPY]
                                                     └─ (Unreal Engine builder stage) [FROM]
```

| Image | Dockerfile | Rebuilt when |
| --- | --- | --- |
| `windows-buildtools:latest` | `windows-buildtools/` | `BUILD_WINDOWS_BUILDTOOLS`, or a change under `windows-buildtools/` |
| `esp-idf-linux:latest` | `esp-idf/linux/` | `BUILD_ESP_IDF`, or a change under `esp-idf/linux/` |
| `esp-idf-windows:latest` | `esp-idf/windows/` | `BUILD_ESP_IDF`, a change under `esp-idf/windows/`, **or whenever `windows-buildtools` is rebuilt**, so the chain never goes stale |
| `unreal-engine-{linux,windows}:<UE_GIT_TAG>` | `unreal/{linux,windows}/` | `BUILD_UNREAL_ENGINE` only, because the build takes hours. See [unreal-engine.md](unreal-engine.md). |
| `jenkins-agent-*`, `ndind`, `p4-server`, `jenkins-controller` | as before | every pipeline run, as before |

All images are pushed to `localhost:5000`. The agent builds pull their bases from there.

## Why ESP-IDF and VS are base images, not copied directories

- **ESP-IDF:** `eim` creates Python venvs with absolute paths, installs system packages and writes
  per-user state. Those only stay valid when the agent is built on top of the image that ran it.
- **Visual Studio:** registers its instance, the Windows SDK and .NET targeting packs in the
  registry and `ProgramData`. A file copy would lose that.

Unreal Engine and the Android SDK are self-contained directories, so the agents copy them. On
Linux the copy uses `COPY --link`, so their layers keep the same digest across agent rebuilds.

Because the agents build `FROM` these images, the `jenkins` user is created in the ESP-IDF images,
where `eim` must run as it. On Linux its uid/gid is fixed at `JENKINS_UID=1001`. The agent fails
fast if the base image disagrees, because the engine copy's `--chown` relies on it.

## Bootstrapping / changing a toolchain

- **First run:** check `BUILD_WINDOWS_BUILDTOOLS`, `BUILD_ESP_IDF` and `BUILD_UNREAL_ENGINE`. The
  stages run in dependency order: build tools → ESP-IDF → Unreal Engine → agents.
- **Change ESP-IDF versions:** edit `esp-idf/*/eim-config.toml`; the changeset triggers the
  rebuild. Note that `changeset` only sees the commits in that build. If such a build failed,
  re-run with `BUILD_ESP_IDF` checked.
- **Pick up a newer VS 2026 / Windows base:** run with `BUILD_WINDOWS_BUILDTOOLS` checked. It
  also rebuilds `esp-idf-windows`. The Unreal Engine image does **not** need rebuilding: only
  its build stage uses the build tools, not its output.
- On Windows (no `COPY --link`), rebuilding a base image also re-copies the engine layer in the
  agent. This happens only when you rebuild a base on purpose.
