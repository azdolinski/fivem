# FiveM / RedM Docker Image

Minimal Docker image for [Cfx.re FXServer](https://docs.fivem.net/docs/server-manual/setting-up-a-server-vanilla/) — runs both FiveM and RedM from a single image, switchable via the `GAME` environment variable.

Built on Alpine Linux with tini as PID 1 init. Multi-stage build keeps the final image lean.

## Quick Start

```bash
docker run -d \
  --name fxserver \
  -e LICENSE_KEY=cfxk_your_key_here \
  -e GAME=fivem \
  -p 30120:30120/tcp \
  -p 30120:30120/udp \
  -v fivem-config:/config \
  ghcr.io/azdolinski/fivem:latest
```

Or with Docker Compose:

```bash
cp .env.example .env
# edit .env — set your LICENSE_KEY
docker compose up -d
```

## Image Tags

Images are published to `ghcr.io/azdolinski/fivem` with three types of tags:

| Tag | Example | Description |
|-----|---------|-------------|
| Full build | `28108-2f3d20c4168282a17737970708ccc1524951483a` | Exact FXServer artifact version |
| Build number | `28108` | Short tag pointing to the same image |
| `latest` | `latest` | Most recent FiveM build available |

Check all available tags on the [GitHub Packages page](https://github.com/azdolinski/fivem/pkgs/container/fivem).

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GAME` | `fivem` | Game to run: `fivem` or `redm` |
| `LICENSE_KEY` | *(required)* | Server license key from [portal.cfx.re](https://portal.cfx.re) |
| `SV_HOSTNAME` | `My FXServer` | Server display name |
| `SV_MAXCLIENTS` | `32` | Max connected players |
| `SV_ENFORCE_GAME_BUILD` | FiveM: `3407` / RedM: `1491` | Force a specific client game build |
| `SV_ENDPOINT_PORT` | `30120` | Game port (TCP + UDP) |
| `TXADMIN_PORT` | `40120` | txAdmin web interface port |
| `RCON_PASSWORD` | *(auto-generated)* | RCON password (random on first run if not set) |
| `NO_LICENSE_KEY` | | Set to skip license key injection from env (use it in server.cfg instead) |
| `NO_DEFAULT_CONFIG` | | Set to `1` to skip auto-generated server.cfg (for txAdmin setups) |
| `EXTRA_ARGS` | | Additional FXServer command-line arguments |

## Volumes

| Path | Description |
|------|-------------|
| `/config` | Server configuration, resources, and server.cfg |
| `/txData` | txAdmin persistent data (only needed with `NO_DEFAULT_CONFIG=1`) |

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| `30120` | TCP + UDP | Game traffic |
| `40120` | TCP | txAdmin web interface (only active with txAdmin enabled) |

## txAdmin

To use txAdmin instead of the default server.cfg:

```bash
docker run -d \
  --name fxserver \
  -e LICENSE_KEY=cfxk_your_key_here \
  -e NO_DEFAULT_CONFIG=1 \
  -p 30120:30120/tcp \
  -p 30120:30120/udp \
  -p 40120:40120/tcp \
  -v fivem-config:/config \
  -v fivem-txdata:/txData \
  ghcr.io/azdolinski/fivem:latest
```

Then open `http://localhost:40120` to complete txAdmin setup.

## CI/CD

Two GitHub Actions workflows handle automated image building:

- **Check** (`check.yml`) — Runs daily at 06:17 UTC. Fetches available FiveM builds from Cfx.re, then triggers image builds for both recommended and latest versions.
- **Build** (`build.yml`) — Reusable workflow that builds and pushes the Docker image to GHCR. Skips if the image already exists (unless `force: true`). Also available as `workflow_dispatch` for manual builds.

### Manual Build

You can trigger a manual build from the **Actions** tab in GitHub:

1. Select **Build Docker Image** workflow
2. Click **Run workflow**
3. Enter the build string (e.g. `28108-2f3d20c4168282a17737970708ccc1524951483a`)
4. Toggle **Also tag as latest** and **Force rebuild** as needed

## Build Locally

```bash
docker build \
  --build-arg FXSERVER_VER=28108-2f3d20c4168282a17737970708ccc1524951483a \
  -t fivem:local .
```

## License

This repository only contains Docker/build configuration. FXServer itself is governed by Cfx.re's terms of service.
