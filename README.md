## Fly Factorio

A small template for creating Factorio dedicated servers on [Fly.io](https://fly.io).

Each server uses:

- `factoriotools/factorio:stable`
- UDP `34197` for Factorio
- TCP `27015` for RCON
- one Fly Volume mounted at `/factorio`
- a dedicated IPv4 address, required for UDP on Fly.io

### Prerequisites

- A paid Fly.io account
- [`flyctl`](https://fly.io/docs/flyctl/install/) installed and authenticated with `fly auth login`
- A Factorio account token from <https://factorio.com/profile> if you want mod updates or a public game listing

### Create a new server

Run the template script with a unique Fly app name and region:

```sh
scripts/new-server.sh --app my-factorio-server --region sjc
```

The script will:

1. generate `generated/my-factorio-server.fly.toml` from `fly.template.toml`
2. create the Fly app if needed
3. create the persistent Fly Volume if needed
4. allocate a dedicated IPv4 address for UDP
5. optionally set Factorio `USERNAME` and `TOKEN` secrets
6. deploy the server

Dedicated IPv4 addresses are a paid Fly.io resource. By default `flyctl` can prompt you before allocation. Add `--yes` to auto-confirm Fly prompts:

```sh
scripts/new-server.sh --app my-factorio-server --region sjc --yes
```

With Factorio credentials:

```sh
scripts/new-server.sh \
  --app my-factorio-server \
  --region sjc \
  --username your_factorio_username \
  --token your_factorio_token
```

Generate resources but skip deploy:

```sh
scripts/new-server.sh --app my-factorio-server --region sjc --no-deploy
```

See all options:

```sh
scripts/new-server.sh --help
```

### Common options

```sh
scripts/new-server.sh \
  --app my-factorio-server \
  --region sjc \
  --volume-size 50 \
  --memory 4gb \
  --cpus 2 \
  --space-age false \
  --update-mods false
```

To load a specific existing save from `/factorio/saves/<name>.zip`:

```sh
scripts/new-server.sh \
  --app my-factorio-server \
  --region sjc \
  --save-name my-save
```

### Deploy an existing generated config

Generated configs are ignored by git. Re-deploy one with:

```sh
fly deploy --app my-factorio-server --config generated/my-factorio-server.fly.toml
```

### Connect

After deployment, connect in Factorio with **Multiplayer → Connect to address**:

```text
my-factorio-server.fly.dev:34197
```

### Operations

Useful commands:

```sh
fly logs --app my-factorio-server
fly status --app my-factorio-server
fly ssh console --app my-factorio-server
fly machine restart --app my-factorio-server
```

Server data lives on the mounted Fly Volume:

```text
/factorio/saves
/factorio/mods
/factorio/config
```

### Notes

- Fly UDP services must bind to `fly-global-services`; the template sets `BIND=fly-global-services`.
- The public UDP port and container UDP port must match; the template uses `34197` for both.
- `UPDATE_MODS_ON_START` is the current `factoriotools/factorio` environment variable name.
- Volume snapshot retention and auto-extension are configured in `fly.template.toml`; adjust the defaults there or in the generated config to control storage costs.
