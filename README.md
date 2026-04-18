# Blueprint Share

Send blueprints, blueprint books, deconstruction planners, and upgrade planners between two Factorio instances on the same machine, over localhost UDP. Handy when running a regular save and a map editor side-by-side.

Requires Factorio **2.0** or newer.

## Quickstart

Two-way sharing between a Steam copy and a second standalone copy:

1. **Get a second copy.** Steam runs only one instance at a time. Download a standalone build of the same version from <https://www.factorio.com/download> (free for anyone who owns Factorio) and extract it outside the Steam install.
2. **Pick two free ports above 1024** - for example `25001` and `25002`.
3. **Set the launch flag on each copy** so it listens on its own port:
   - **Steam copy** - right-click Factorio -> **Properties -> Launch Options**, enter `--enable-lua-udp=25001`.
   - **Standalone copy** - launch the binary directly: `./factorio --enable-lua-udp=25002`.
4. **Point each copy at the other** in **Mod settings -> Per player -> Blueprint Share -> Destination port**: Steam copy -> `25002`, standalone copy -> `25001`.

**One-way only?** Only the receiver needs the launch flag. The sender just needs **Destination port** pointing at the receiver's listening port.

## Usage

- **Ctrl + B** - Send the blueprint, book, or planner currently in your cursor (or picked up from the blueprint library).
- **Ctrl + R** - Manually receive. With **Auto-receive** on (default) incoming blueprints land in your cursor automatically; use the hotkey in the Map Editor or when Auto-receive is off.

## Settings

Settings live under **Mod settings -> Per player -> Blueprint Share**.

| Setting | Default | Description |
|---|---|---|
| Destination port | `25002` | UDP port to send to. Must match the other instance's `--enable-lua-udp=<port>`. |
| Auto-receive blueprints | `on` | Automatically place incoming blueprints in the cursor. Disable if you prefer to trigger imports with the hotkey. |
| Log level | `Info` | In-game message verbosity. `Quiet` hides all messages; `Debug` shows full diagnostics. The mod log file always records full output. |

## Limitations

- **Localhost only.** No LAN or internet sharing - Factorio binds UDP to `127.0.0.1`.
- **Packet size ≈ 65 KB.** Very large blueprint books can exceed the UDP limit and fail to send. Split the book or trim unused blueprints.
- **Map Editor.** Auto-receive needs the simulation running. The editor is paused by default, so either unpause (**Tools -> Time -> Speed -> Play**) or use **Ctrl + R** to receive manually.
- **Headless servers.** Receiving is disabled when no players are connected.

## Troubleshooting

- **Invalid payload.** - The other instance sent a packet the mod couldn't decode. Usually means a different, unrelated process is sending UDP to your port. Change the port.
- **Blueprint is too large.** - The serialised blueprint exceeds the UDP limit. Send a smaller book.
- **Could not send...** - The OS rejected the send. Check that the destination port is valid and that no firewall rule is blocking localhost UDP.
- **Version mismatch warning** - The other instance is on a different Factorio version. Minor differences usually import fine; major versions may fail silently.
- **Nothing happens on receive** - Confirm the destination instance was launched with `--enable-lua-udp=<port>`.

## License

[MIT](LICENSE)
