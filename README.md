# KEK map bundle 1.2

Fair map scripts for Civilization V: Brave New World multiplayer (made for KEK Mod, also work without it).

## Download

*Code → Download ZIP* (the newest files). The [Releases](../../releases) page has older versions as zip files.

## Install

1. Unzip. You get a folder **KEK Maps**.
2. Put it in `Steam\steamapps\common\Sid Meier's Civilization V\Assets\Maps\`
   so you have `Assets\Maps\KEK Maps\MirrorSkirmish.lua` and so on.
3. Start Civ V. The maps are in the map list.

**Every player in the game needs the same files.**

## The maps

**Mirrored (one team per side, for teamer games)**

| Map | What it is |
|---|---|
| Mirror Map: Skirmish | The game's Skirmish (all land), exact left-right mirror, a dead strip in the middle (or none). Every capital gets Horses, Iron, Coal and Aluminium within 3 tiles. |
| Mirror Map: Pangaea | One oval continent, mirrored left-right, with a wide open middle. Resources spread evenly, a richer middle band worth fighting for. Land per player: about 90 tiles by default (75 / 105 / 125 as options). |
| Mirror Map: KEK Archipelago | Our KEK Archipelago, mirrored: start islands with islands of every size around them. Many options (island size, hills, resources, Fish, deep ocean). |
| Mirror Map: East vs West | Mirrored, one team in the east, one in the west. |
| Mirror Map: Ring | Mirrored ring-shaped land. |

**Free for all**

| Map | What it is |
|---|---|
| KEK Archipelago | Archipelago where every capital gets the same food, luxuries and strategic resources. |
| KEK Large Islands | The game's Large Islands made fair: everyone starts alone on an own island of the same size, away from the poles. |
| KEK BitMoreFairPangea 1.3 | The game's Pangaea with the bad outcomes lifted, the rest left as the game makes it. See below. |

Every map has its options on the game setup screen (map size, land, hills, resources, ...).

## KEK BitMoreFairPangea 1.3

The game's own Pangaea; only the worst outcomes are changed.

* **Defaults:** 3 Billion Years, Temperate, Normal rainfall, Low sea level, Strategic Balance, Land Normal.
* **Land option:** Normal / +5% / +7.5% / +10%. The extra land goes to the warm middle, not to the poles.
* **Shape:** a very snaky continent (thin arms everywhere, big inland seas) is rolled again.
* **Sea lanes:** about 3 games in 4 a ship can sail around the world (an open lane through the polar ice); the other games stay iced in.
* **Mountains:** the game's chains, but at most 8 mountains within 4 tiles of a capital.
* **Tundra:** a wider band, more hills, forest, Deer and Sheep, extra rivers, small lakes in hilly tundra.
* **Grassland:** a few more hills and Cattle on empty grassland.
* **Starts (only ever added to, the game's own start balance stays):** every capital gets a hill and 2 food bonuses nearby; weak starts (mostly flat tundra / desert / snow) more; hopeless starts (no fresh water, no hills) get plains and more hills and food; a tundra settler stands on a river or a hill; a start with only Wine / Cotton / Incense and no food gets a food bonus.
* **Strategic Balance:** Horses, Iron, Coal and Aluminium within 3 tiles of every capital.
* **City states:** 3 food bonuses nearby and a Stone (no extra luxuries).

Measured on 100 maps of each (standard size, 8 players, these defaults): the same spacing between capitals as the game's Pangaea (14.3 vs 14.0 tiles), the same hills (34.5% vs 34.8%) and mountains (7.0% vs 6.6%), no capital with more than 8 mountains around it (the game's: up to 22), sail around the world 77% (the game's: 18%), 30% of flat tundra empty (the game's: 42%), start biases (England coast, Aztec jungle) work as in the game.
