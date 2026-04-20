# Blueprint Share

Send blueprints, blueprint books, deconstruction planners, and upgrade planners between two Factorio instances on the same machine, over localhost UDP. Handy when running a regular save and a map editor side-by-side.

Requires Factorio **2.0** or newer.

## Quickstart

Two-way sharing between a Steam copy and a second standalone copy:

1. **Get a second copy.** Steam runs only one instance at a time. Download a standalone build of the same version from <https://www.factorio.com/download> (free for anyone who owns Factorio) and extract it outside the Steam install.
> **Windows:** grab the **ZIP package**, not the installer. The installer shares `%APPDATA%\Factorio` with the Steam copy, so only one can run at a time.
2. **Use port `25001` for the Steam copy and `25002` for the standalone.** Change these only if they conflict with something else on your machine.
3. **Set the launch flag on each copy** so it listens on its own port:
   - **Steam copy** - right-click Factorio -> **Properties -> Launch Options**, enter `--enable-lua-udp=25001`.
   - **Standalone (Linux)** - launch from a terminal as `./factorio --enable-lua-udp=25002`.
   - **Standalone (Windows)** - create a shortcut to `bin\x64\factorio.exe` and append ` --enable-lua-udp=25002` to the **Target** field. Or launch from a terminal: `factorio.exe --enable-lua-udp=25002`.
   - **Standalone (macOS):**
     - Put `factorio.app` in its own folder, e.g. `~/Applications/Factorio-Standalone/`.
     - Create a `config.cfg` next to it with the contents below, or download the ready-made [`macos/config.cfg`](macos/config.cfg) from this repo:
       ```ini
       ; version=13
       [path]
       read-data=__PATH__executable__/../data
       write-data=__PATH__executable__/../../../factorio-data
       ```
     - From that folder, run `open ./factorio.app --args -c "$PWD/config.cfg" --enable-lua-udp=25002` (the `-c` path must be absolute). Factorio will create `factorio-data/` alongside `factorio.app` for saves, mods, and config.
4. **On the standalone,** set **Mod settings -> Per player -> Blueprint Share -> Destination port** to `25001`. The Steam copy needs no change - its default already points at `25002`.

> **One-way only:** Only the receiver needs the launch flag. The sender just needs **Destination port** pointing at the receiver's listening port.

## Usage

- **Ctrl + B** - Send the blueprint, book, or planner currently in your cursor (or picked up from the blueprint library).
- **Ctrl + R** - Manually receive. With **Auto-receive** on (default) incoming blueprints land in your cursor automatically. Use the hotkey in the Map Editor or when Auto-receive is off.

## Settings

Settings live under **Mod settings -> Per player -> Blueprint Share**.

| Setting | Default | Description |
|---|---|---|
| Destination port | `25002` | UDP port to send to. Must match the other instance's `--enable-lua-udp=<port>`. |
| Auto-receive blueprints | `on` | Automatically place incoming blueprints in the cursor. Disable if you prefer to trigger imports with the hotkey. |
| Log level | `Info` | In-game message verbosity. `Quiet` hides all messages. `Debug` shows full diagnostics. The mod log file always records full output. |

## Limitations

- **Localhost only.** No LAN or internet sharing - Factorio binds UDP to `127.0.0.1`.
- **Packet size ≈ 65 KB.** Very large blueprint books can exceed the UDP limit and fail to send. Split the book or trim unused blueprints.
- **Map Editor.** Auto-receive needs the simulation running. The editor is paused by default, so either unpause (**Tools -> Time -> Speed -> Play**) or use **Ctrl + R** to receive manually.
- **Headless servers.** Receiving is disabled when no players are connected.

## Troubleshooting

- **Invalid payload.** - The other instance sent a packet the mod couldn't decode. Usually means a different, unrelated process is sending UDP to your port. Change the port.
- **Blueprint is too large.** - The serialised blueprint exceeds the UDP limit. Send a smaller book.
- **Could not send...** - The OS rejected the send. Check that the destination port is valid and that no firewall rule is blocking localhost UDP.
- **Version mismatch warning** - The other instance is on a different Factorio version. Minor differences usually import fine, major versions may fail with `Import failed.`
- **Import failed.** - The payload arrived but couldn't be imported into the cursor. Usually a Factorio version mismatch between sender and receiver.
- **Blueprint is in preview.** - The library blueprint hasn't finished syncing with the server. Wait for the sync and resend.
- **Nothing happens on receive** - Confirm the destination instance was launched with `--enable-lua-udp=<port>`.
- **Two copies fighting over the same saves/mods/config** - Both installs share the same user data directory. You may see `Couldn't create lock file Factorio\.lock: 32 Is another instance already running?` when starting the second copy. See the [Factorio Wiki](https://wiki.factorio.com/Application_directory#Changing_the_user_data_directory) for per-platform write paths and how to make a copy portable.

## License

[MIT](LICENSE)
