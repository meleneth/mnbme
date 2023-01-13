docker-compose build
docker-compose up --remove-orphans

open http://localhost:20400

This is a microservices setup that simulates players in a mmorpg.  It currently runs 17 players.

The players join games with a small player limit, dps the boss down, and the person who gets the killing blow gains a medal.  All players are then ejected from the game and look for an open game.

If there are no open games, a new game is created and the player joins it.

If a game is stale, it is cleaned up if bigboard is running

# New Relic integration

if you populate the .env file with these keys, New Relic will get information from the services.  Make sure you edit the license key to provide your own!

```
NEW_RELIC_LICENSE_KEY=7ff03a2c806*mumble*1d66db0bace313faNRAL
NEW_RELIC_MONITOR_MODE=true
```

# Future changes

move stale game cleanup to it's own service instead of putting it in bigboard

server side should not allow players to cheat by spamming gameservice/game/play faster than 1/second

add more redis instances, i.e. accountredis and achievementsredis

stricter definition of what game a player is 'in'

require the player to actually be joined to a game to DPS in it
  (would have to know uuid of an existing game to cheat it, but still)

implement 'player' in a Vue.js app - aside from bigboard.  Implement cheats, and teamplay and multi-character botting
