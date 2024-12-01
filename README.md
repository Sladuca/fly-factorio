## Fly Factorio

Configuration for hosting a factorio server on https://fly.io.

### Prerequisites

- paid fly account

### Setup

First, look at `fly.toml` and edit the following to your liking:
1. `primary_region` should be set to the region closest to where you expect people to be playing from.
2. set `DLC_SPACE_AGE` to `true` if you have / want the server to use space age
3. set `UPDATE_MODS_ONSTART` to `true` if you want the game to auto-update whenever the game updates.
4. set `SAVE_NAME` to the name of the save file you'd like to use. It defaults to `autosave1`. Typically you'd use this to host a your own save file instead of starting from scratch.

First, create the app with `fly deploy --ha=false`. This will create a new ply app called `factorio-server`.

In order for it to work, you'll also need to:
1. Create a volume. `fly deploy` should tell you how to do it.
2. Allocate a dedicated IPv4 address for the server. you can do this with `fly ips allocate-v4`

Then, you need to set the following secrets in the app:
1. `USERNAME` - your factorio.com username
2. `TOKEN` - game token from factorio.com. You can find this on the profile page of your factorio account, which you can find by clicking on your username in the upper-right-hand corner.

Then, just `fly deploy --ha=false` once more and inshallah the server should work. To connect in-game, use the "connect to address" multiplayer option.
