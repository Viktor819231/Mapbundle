# KEK map bundle 1.8

Fair map scripts for Civilization V: Brave New World multiplayer (made for KEK Mod, also work without it).

## Download

Get **KEK-Maps-1.8.zip** from the [Releases](../../releases) page (older versions are there too), or *Code → Download ZIP*.

## Install

1. Unzip. You get a folder **KEK Maps**.
2. Put it in `Steam\steamapps\common\Sid Meier's Civilization V\Assets\Maps\`
   so you have `Assets\Maps\KEK Maps\MirrorSkirmish_v1.8.lua` and so on.
3. Start Civ V. The maps are in the map list.

**Every player in the game needs the same files.**

Every file and every map name carries the bundle version (`MirrorSkirmish_v1.8.lua` = "Mirror Map: Skirmish 1.8"). Different versions can sit side by side; in the lobby, pick a map with the same version number for everyone.

## The maps

**Mirrored (one team per side, for teamer games)**

| Map | What it is |
|---|---|
| Mirror Map: Skirmish | The game's Skirmish (all land), exact left-right mirror, a dead strip in the middle (or none). Every capital gets Horses, Iron, Coal and Aluminium within 3 tiles. |
| Mirror Map: Pangaea | One oval continent, mirrored left-right, with a wide open middle. Resources spread evenly. "Middle of the map" option: Rich / Normal / Barren (a bare 2-3 tile strip, almost a divider); Normal is calmer on duel and tiny. Duel maps are bigger, with no islands linking the two sides. Luxury types scale with map size (duel 4, tiny 6, small 8, regional ones included). Land per player: about 90 tiles by default (75 / 105 / 125 as options). |
| Mirror Map: KEK Archipelago | Our KEK Archipelago, mirrored: start islands with islands of every size around them. Many options (island size, hills, resources, Fish, deep ocean). |
| Mirror Map: East vs West | Mirrored, one team in the east, one in the west. |
| Mirror Map: Ring | Mirrored ring-shaped land. |

**Free for all**

| Map | What it is |
|---|---|
| KEK Archipelago | Archipelago where every capital gets the same food, luxuries and strategic resources. |
| KEK Large Islands | The game's Large Islands made fair: everyone starts alone on an own island of the same size, away from the poles. |
| KEK BitMoreFairPangea 1.8 | The game's Pangaea with the bad outcomes lifted, the rest left as the game makes it. See below. |

Every map has its options on the game setup screen (map size, land, hills, resources, ...).

**City states (all maps):** a city state has at most 1 luxury within 3 tiles (Mercantile ones 2), and a "City states" option: Poor (at most 1 food resource nearby) / Normal / Rich (at least 4 food resources).

## KEK BitMoreFairPangea 1.8

The game's own Pangaea; the worst outcomes lifted and the best starts capped, so starts still vary but none run away.

* **Defaults:** 3 Billion Years, Temperate, Normal rainfall, Low sea level, Strategic Balance, Land -5%, Continent shape "Broader / no inland lakes", Mountain clumps "Thinner clumps".
* **Land option:** Normal / +5% / +7.5% / +10% / -5% (default) / -10%.
* **Continent shape option:** Normal / Unfiltered / Broader / Broader, no inland lakes / Large inland seas / Compact Pangaea, no lakes.
* **Rivers:** at most about 25% of land touches a river (the game's Pangaea ~20%); option "5% fewer" removes more.
* **Mountain clumps option:** Game's own / Thinner clumps (default: thick blocks trimmed from the outside in, the same number of mountains placed again as longer chains and small clumps elsewhere) / No clumps (only chains 1-2 tiles thick and single peaks, mountain groups at least 4 tiles apart, fewer mountains). With trimming on: no 1-tile passes between mountains and no land pockets walled in by mountains.
* **Forest and jungle option:** Game's own / 5% fewer / 10% fewer (the thickest woods first).
* **No big bare areas:** a flat area of bare tundra / desert / snow / plains (no feature, resource or fresh water) keeps at most 7 tiles; snow patches at most 4 tiles. No plains within 3 tiles of snow, no forest right next to it.
* **Tundra:** about half of it hills. Toward the pole: more hills, Sheep, Deer, a little Iron, few forests. Toward the plains: more forest, Deer and rivers.
* **Desert:** about a quarter less; big hill strips in the desert get flat gaps; flat desert on a river is floodplains; the odd oasis.
* **Coast:** some flat coast becomes hills, more where the land behind is hilly, never in a long strip.
* **Capitals:** at least 12 tiles apart where possible; at least one coastal capital every game; a coastal capital stands on a hill; at most 8 mountains within 4 tiles (the nearest ones go). Grassland / tundra starts get 2 hills nearby (tundra 3), jungle 1, plains none. Capital food is the game's own.
* **Best starts capped (only removes, never adds):** within 3 tiles at most 4 food bonus (5 for tundra starts); a capital without fresh water within 2 tiles gets one food bonus; at most 3 Wheat / Bananas / Deer within 4 tiles (tundra Deer not counted); at most 2 of the region's luxury + 1 other luxury within 3 tiles (extras are moved 4-6 tiles out, not deleted).
* **Luxuries:** small maps get one more regional luxury per player (6 instead of the game's 5).
* **City states:** on the coast or at least 5 tiles inland (never 2-4 tiles in, where they block the coast anyway), leaning to coast and tundra (about 2 in 3 on the coast; the game: 9 in 10). A city state has fresh water or at least 3 resources nearby.
* **Strategic Balance:** Horses, Iron, Coal and Aluminium within 3 tiles of every capital.
* **Start biases:** work at least as well as on the game's Pangaea (tested with Morocco, Aztecs, Brazil, Egypt). As in the game, when two civs want the same terrain the earlier lobby slot picks first.

1.4 on 40 maps: food bonus within 3 tiles of a capital 2.89 (the game's 2.84), hills within 2 tiles 3.70 (the game's 3.76).

Measured for 1.3 on 100 maps of each (standard size, 8 players, these defaults): the same spacing between capitals as the game's Pangaea (14.3 vs 14.0 tiles), the same hills (34.5% vs 34.8%) and mountains (7.0% vs 6.6%), no capital with more than 8 mountains around it (the game's: up to 22), 30% of flat tundra empty (the game's: 42%), start biases (England coast, Aztec jungle) work as in the game.
