# KEK map bundle 1.4

Fair map scripts for Civilization V: Brave New World multiplayer (made for KEK Mod, also work without it).

## Download

Get **KEK-Maps-1.4.zip** from the [Releases](../../releases) page (older versions are there too), or *Code → Download ZIP*.

## Install

1. Unzip. You get a folder **KEK Maps**.
2. Put it in `Steam\steamapps\common\Sid Meier's Civilization V\Assets\Maps\`
   so you have `Assets\Maps\KEK Maps\MirrorSkirmish_v1.4.lua` and so on.
3. Start Civ V. The maps are in the map list.

**Every player in the game needs the same files.**

Every file and every map name carries the bundle version (`MirrorSkirmish_v1.4.lua` = "Mirror Map: Skirmish 1.4"). Different versions can sit side by side; in the lobby, pick a map with the same version number for everyone.

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
| KEK BitMoreFairPangea 1.4 | The game's Pangaea with the bad outcomes lifted, the rest left as the game makes it. See below. |

Every map has its options on the game setup screen (map size, land, hills, resources, ...).

**City states (all maps):** a city state has at most 1 luxury within 3 tiles (Mercantile ones 2), and a "City states" option: Poor (at most 1 food resource nearby) / Normal / Rich (at least 4 food resources).

## KEK BitMoreFairPangea 1.4

The game's own Pangaea; only the worst outcomes are changed.

* **Defaults:** 3 Billion Years, Temperate, Normal rainfall, Low sea level, Strategic Balance, Land Normal.
* **Land option:** Normal / +5% / +7.5% / +10%. The extra land goes to the warm middle, not to the poles.
* **Snaky land option:** Reroll (default: a very snaky continent, thin arms everywhere and big inland seas, is rolled again) / Keep.
* **Poles:** as the game makes them (no sea lanes since 1.4).
* **Mountains:** the game's chains, but at most 8 mountains within 4 tiles of a capital.
* **Tundra:** a wider band, a few more hills, forest, Deer and Sheep, extra rivers, small lakes in hilly tundra (toned down in 1.4).
* **Grassland:** a very few more hills and some Cattle on empty grassland.
* **Starts (only ever added to, the game's own start balance stays):** weak starts (mostly flat tundra / desert / snow) get 2 hills nearby; hopeless starts (no fresh water, no hills) get plains and 3 hills. No hill is forced under a capital.
* **Capital food option:** Game's own (default: no extra food at capitals) / Extra food bonus (a capital with few food resources gets 2, weak 3, hopeless 4, nearby; Wine / Cotton / Incense starts with no food get one).
* **Strategic Balance:** Horses, Iron, Coal and Aluminium within 3 tiles of every capital.
* **City states:** a city state has fresh water or at least 3 resources nearby (topped up with food bonuses; no Stone, no extra luxuries).

1.4 on 40 maps: food bonus within 3 tiles of a capital 2.89 (the game's 2.84), hills within 2 tiles 3.70 (the game's 3.76).

Measured for 1.3 on 100 maps of each (standard size, 8 players, these defaults): the same spacing between capitals as the game's Pangaea (14.3 vs 14.0 tiles), the same hills (34.5% vs 34.8%) and mountains (7.0% vs 6.6%), no capital with more than 8 mountains around it (the game's: up to 22), 30% of flat tundra empty (the game's: 42%), start biases (England coast, Aztec jungle) work as in the game.
