MIRROR_VARIANT = "eastwest";
------------------------------------------------------------------------------
--	FILE:	 MirrorSkirmish.lua
--	AUTHOR:  Bob Thomas (Sirian) - the original Skirmish.lua this map is built on
--	MIRROR:  Mirror Skirmish for the KEK multiplayer community (2026)
--	PURPOSE: Skirmish, made fair: the east half is an exact mirror image of the
--	         west half (land, rivers, features, resources, ruins, starts and
--	         city states), with a dead strip of 2-3 tiles down the middle
--	         (or no strip). Landmass: Skirmish (all land) or Pangaea (one
--	         continent with ocean around it, no strip by default).
--	         Every capital gets Horses, Iron, Coal (7) and Aluminium (3) within 3 tiles.
--	         Works for 1v1, team vs team and free for all.
------------------------------------------------------------------------------
--	Copyright (c) 2010 Firaxis Games, Inc. All rights reserved.
--	Mirror additions (2026) are free to use and change.
--	Ideas borrowed from the Weevee map script (Leszek Deska's mirroring, and
--	Weevee's team handling) are marked "Weevee" where they are used.
------------------------------------------------------------------------------
--	HOW THE MIRROR WORKS
--	Civ V rows are offset: odd rows sit half a hex further east (y grows to
--	the north). Flipping the map about its vertical centre line is therefore
--	    even rows:  x' = W - 1 - x        odd rows:  x' = W - 2 - x
--	This keeps every neighbour a neighbour, so the copy is exact. On odd rows
--	the plot at x = W - 1 has no partner; it is made plain desert (or plain
--	water on Pangaea) with nothing on it ("lone plot"). With no strip, the
--	odd-row plot at x = (W - 2) / 2 is its own mirror image; it and the two
--	even-row plots touching the centre line get no start, city state (except
--	the odd one out, see below), ruin, wonder or river, and only the
--	self-mirrored plot may carry a resource. The map is generated normally
--	(Skirmish code), then the west half is copied onto the east half after
--	every step that could differ, and one last time at the very end.
------------------------------------------------------------------------------

include("MapGenerator");
include("MultilayeredFractal");
include("FractalWorld");
include("FeatureGenerator");
include("TerrainGenerator");
include("MapmakerUtilities");

------------------------------------------------------------------------------
-- Sea maps: half the game's ruins (user, 11-14). Sea ruins are their own option.
------------------------------------------------------------------------------
MirrorRuinHalf_AddGoodies = AddGoodies;
function AddGoodies()
	MirrorRuinHalf_AddGoodies();
	if mirror_landmass ~= 3 then return end	-- Mirror Archipelago only
	local goody = GameInfo.Improvements["IMPROVEMENT_GOODY_HUT"];
	if goody == nil then return end
	local iW, iH = Map.GetGridSize();
	local ruins = {};
	for i = 0, iW * iH - 1 do
		local plot = Map.GetPlotByIndex(i);
		if not plot:IsWater() and plot:GetImprovementType() == goody.ID then table.insert(ruins, plot) end
	end
	local drop = math.floor(table.maxn(ruins) / 2);
	for n = 1, drop do
		local plot = table.remove(ruins, 1 + Map.Rand(table.maxn(ruins), "Sea maps - half the ruins"));
		plot:SetImprovementType(-1);
	end
	print("Sea maps: ruins halved, removed", drop);
end

-- The game's own versions of the functions that Skirmish replaces further down.
-- The Pangaea landmass uses these, exactly as the game's Pangaea.lua does.
MirrorBase_GenerateTerrainAtPlot = TerrainGenerator.GenerateTerrainAtPlot;
MirrorBase_FeatureInitFractals = FeatureGenerator.__initFractals;
MirrorBase_AddIceAtPlot = FeatureGenerator.AddIceAtPlot;
MirrorBase_AddJunglesAtPlot = FeatureGenerator.AddJunglesAtPlot;
MirrorBase_AdjustTerrainTypes = FeatureGenerator.AdjustTerrainTypes;
MirrorBase_GetRiverValueAtPlot = GetRiverValueAtPlot;
MirrorBase_DoRiver = DoRiver;
MirrorBase_AddRivers = AddRivers;
MirrorBase_AddLakes = AddLakes;

------------------------------------------------------------------------------
function MirrorSkirmishScriptInfo()
	return {
		Name = "Mirror Map: Skirmish 1.1",
		Description = "The game's Skirmish (all land) with an exact left-right mirror and a dead strip in the middle (or none). Starts, rivers, resources, ruins and city states are mirrored, one team per side. Strategic balance: every capital gets Horses, Iron, Coal (7) and Aluminium (3) within 3 tiles.",
		IconAtlas = "WORLDTYPE_ATLAS_2",
		IconIndex = 0,
		SupportsSinglePlayer = true,
		SupportsMultiplayer = true,
		CustomOptions = {
			{
				Name = "Dominant terrain",
				Values = {
					{"TXT_KEY_MAP_SCRIPT_SKIRMISH_GRASSLANDS", "TXT_KEY_MAP_SCRIPT_SKIRMISH_GRASSLANDS_HELP"},
					{"TXT_KEY_MAP_SCRIPT_SKIRMISH_PLAINS", "TXT_KEY_MAP_SCRIPT_SKIRMISH_PLAINS_HELP"},
					{"TXT_KEY_MAP_SCRIPT_SKIRMISH_FOREST", "TXT_KEY_MAP_SCRIPT_SKIRMISH_FOREST_HELP"},
					{"TXT_KEY_MAP_SCRIPT_SKIRMISH_JUNGLE", "TXT_KEY_MAP_SCRIPT_SKIRMISH_JUNGLE_HELP"},
					{"TXT_KEY_MAP_SCRIPT_SKIRMISH_DESERT", "TXT_KEY_MAP_SCRIPT_SKIRMISH_DESERT_HELP"},
					{"TXT_KEY_MAP_SCRIPT_SKIRMISH_TUNDRA", "TXT_KEY_MAP_SCRIPT_SKIRMISH_TUNDRA_HELP"},
					{"TXT_KEY_MAP_SCRIPT_SKIRMISH_HILLS", "TXT_KEY_MAP_SCRIPT_SKIRMISH_HILLS_HELP"},
					{"TXT_KEY_MAP_OPTION_GLOBAL_CLIMATE", "TXT_KEY_MAP_OPTION_GLOBAL_CLIMATE_HELP"},
					"TXT_KEY_MAP_OPTION_RANDOM",
				},
				DefaultValue = 9,
				SortPriority = 1,
			},
			{
				Name = "Water setting",
				Values = {
					{"TXT_KEY_MAP_OPTION_RIVERS", "TXT_KEY_MAP_OPTION_RIVERS_HELP"},
					{"TXT_KEY_MAP_OPTION_SMALL_LAKES", "TXT_KEY_MAP_OPTION_SMALL_LAKES_HELP"},
					{"TXT_KEY_MAP_OPTION_SEAS", "TXT_KEY_MAP_OPTION_SEAS_HELP"},
					{"TXT_KEY_MAP_OPTION_RIVERS_AND_SEAS", "TXT_KEY_MAP_OPTION_RIVERS_AND_SEAS_HELP"},
					{"TXT_KEY_MAP_OPTION_DRY", "TXT_KEY_MAP_OPTION_DRY_HELP"},
					"TXT_KEY_MAP_OPTION_RANDOM",
				},
				DefaultValue = 1,
				SortPriority = 2,
			},
			{
				Name = "TXT_KEY_MAP_OPTION_RESOURCES",
				Values = { -- Only one option here, but this will let all users know that resources are not set at default.
					"TXT_KEY_MAP_OPTION_BALANCED_RESOURCES",
				},
				DefaultValue = 1,
				SortPriority = 3,
			},
			{
				Name = "Middle strip",
				Values = {
					{"Default (Desert)", "The empty desert strip."},
					{"Desert", "Empty flat desert down the middle. Units can walk across."},
					{"Snow", "Empty flat snow down the middle. Units can walk across."},
					{"Mountains with passes", "Mountains down the middle, with a flat pass every few rows."},
					{"Water", "Shallow water down the middle. The two halves are separate landmasses."},
					{"None (land continues)", "No divider: normal mirrored land runs through the middle."},
				},
				DefaultValue = 1,
				SortPriority = 4,
			},
			{
				Name = "Strip width",
				Values = {
					{"2-3 tiles", "The strip is 2 tiles wide on some rows and 3 on the others."},
					{"3-4 tiles", "The strip is 3 tiles wide on some rows and 4 on the others."},
				},
				DefaultValue = 1,
				SortPriority = 5,
			},
			{
				Name = "Map size",
				Values = {
					{"Normal", "Skirmish's own size for the world size picked in the lobby."},
					{"Compact", "About three quarters of the tiles: less room, neighbours closer."},
					{"Brawl", "A bit over half the tiles: little room, neighbours close."},
				},
				DefaultValue = 1,
				SortPriority = 0,
			},
		},
	}
end
------------------------------------------------------------------------------

-------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- MAP VARIANTS
-- One source file makes several maps. The build (tools/build_maps.py) writes
-- one copy per map with MIRROR_VARIANT set on its first line:
--   "skirmish"     Mirror Map: Skirmish (all-land Skirmish)
--   "pangaea"      Mirror Map: Pangaea (the game's Pangaea)
--   "archipelago"  Mirror Archipelago (start islands of 8-18 tiles, many small islands)
--   "eastwest"     Mirror East vs West (two continents, sea between)
--   "ring"         Mirror Ring (a land ring around an inner sea)
------------------------------------------------------------------------------
MIRROR_VARIANT = MIRROR_VARIANT or "skirmish";
mirror_optionIndex = {};	-- GLOBAL option key -> custom option number

function MirrorCoastalStartsOptionDef()
	return {key = "coastal", Name = "Coastal starts",
		Values = {
			{"One per team", "At least one player of each team starts on the coast (free for all: everybody)."},
			{"Everybody", "Every player starts on the coast."},
			{"No rule", "Starts go wherever the land is best."},
		}, DefaultValue = 1};
end
function MirrorWrapOptionDef()
	return {key = "wrap", Name = "World wrap",
		Values = {
			{"Yes", "The map wraps round east-west, like the game's Pangaea and Archipelago. The seam is a second mirror line: players near the west edge face their mirror twins across it."},
			{"No", "Flat map with an east and a west edge."},
		}, DefaultValue = 1};
end
function MirrorAgeOptionDef()
	return {key = "age", Name = "TXT_KEY_MAP_OPTION_WORLD_AGE", Values = {"TXT_KEY_MAP_OPTION_THREE_BILLION_YEARS", "TXT_KEY_MAP_OPTION_FOUR_BILLION_YEARS", "TXT_KEY_MAP_OPTION_FIVE_BILLION_YEARS", "TXT_KEY_MAP_OPTION_RANDOM"}, DefaultValue = 2};
end
function MirrorClimateOptionDefs()
	return {
		{key = "temp", Name = "TXT_KEY_MAP_OPTION_TEMPERATURE", Values = {"TXT_KEY_MAP_OPTION_COOL", "TXT_KEY_MAP_OPTION_TEMPERATE", "TXT_KEY_MAP_OPTION_HOT", "TXT_KEY_MAP_OPTION_RANDOM"}, DefaultValue = 2},
		{key = "rain", Name = "TXT_KEY_MAP_OPTION_RAINFALL", Values = {"TXT_KEY_MAP_OPTION_ARID", "TXT_KEY_MAP_OPTION_NORMAL", "TXT_KEY_MAP_OPTION_WET", "TXT_KEY_MAP_OPTION_RANDOM"}, DefaultValue = 2},
	};
end
function MirrorVariantOptionDefs()
	-- Options of the newer maps, in lobby order.
	local defs = {};
	if MIRROR_VARIANT == "pangaea" then
		defs = {
			{key = "forest", Name = "Forest and jungle",
				Values = {
					{"25%", "Only a quarter of the forests and jungles the game places."},
					{"50%", "Half of the forests and jungles the game places."},
					{"75%", "Three quarters of the forests and jungles the game places."},
					{"100% (the game's)", "All the forests and jungles the game places."},
				}, DefaultValue = 4},
			{key = "strip", Name = "Middle strip",
				Values = {
					{"Default (None)", "No divider: the continent runs through the middle."},
					{"Desert", "Empty flat desert down the middle of the continent. Units can walk across."},
					{"Snow", "Empty flat snow down the middle of the continent. Units can walk across."},
					{"Mountains with passes", "Mountains down the middle, with a flat pass every few rows."},
					{"Water", "Shallow water down the middle. The two halves are separate landmasses."},
					{"None (land continues)", "No divider: the continent runs through the middle."},
				}, DefaultValue = 1},
			{key = "width", Name = "Strip width",
				Values = {
					{"2-3 tiles", "The strip is 2 tiles wide on some rows and 3 on the others."},
					{"3-4 tiles", "The strip is 3 tiles wide on some rows and 4 on the others."},
				}, DefaultValue = 1},
			{key = "sealevel", Name = "TXT_KEY_MAP_OPTION_SEA_LEVEL", Values = {"TXT_KEY_MAP_OPTION_LOW", "TXT_KEY_MAP_OPTION_MEDIUM", "TXT_KEY_MAP_OPTION_HIGH", "TXT_KEY_MAP_OPTION_RANDOM"}, DefaultValue = 2},
			MirrorAgeOptionDef(),
			MirrorWrapOptionDef(),
		};
	elseif MIRROR_VARIANT == "archipelago" then
		defs = {
			{key = "mapsize", Name = "Map size",
				Values = {
					{"Normal", "The game's size for the world size picked in the lobby."},
					{"Compact", "About three quarters of the tiles: less ocean, the islands closer together."},
				}, DefaultValue = 2},
			{key = "startisland", Name = "Start island size",
				Values = {
					{"Small (10-15 tiles)", "Each player starts on an island of 10 to 15 land tiles."},
					{"Medium (15-25 tiles)", "Each player starts on an island of 15 to 25 land tiles."},
					{"Large (20-40 tiles)", "Each player starts on an island of 20 to 40 land tiles."},
					{"Huge (30-50 tiles)", "Each player starts on an island of 30 to 50 land tiles (one size per game, the same for everybody)."},
				}, DefaultValue = 4},
			{key = "expansion", Name = "Big islands (10-30 tiles)",
				Values = {
					{"Few (1 per 2 players)", "About one island of 10-30 tiles for every two players, anywhere on the map."},
					{"Normal (1 per player)", "About one island of 10-30 tiles per player, anywhere on the map."},
					{"Many (2 per player)", "About two islands of 10-30 tiles per player, anywhere on the map."},
					{"None", "No islands of 10-30 tiles (the other islands stay)."},
				}, DefaultValue = 1, hidden = true},
			{key = "ownexpansion", Name = "Own expansion islands (16 tiles)",
				Values = {
					{"None", "No own expansion islands."},
					{"One per player", "Every player gets one island of 16 tiles 3-5 tiles of water off their own coast (same size and hills for everybody)."},
					{"Two per player", "Every player gets two islands of 16 tiles off their own coast."},
				}, DefaultValue = 2},
			{key = "landamount", Name = "Land amount",
				Values = {
					{"Less (about 23% land)", "Fewer small islands outside the start and expansion islands."},
					{"Normal (about 25% land)", "A bit more land than Less."},
					{"More (about 28% land)", "More islands, water gaps of at most about 3 tiles."},
					{"Lots (about 36% land)", "Much more land, water gaps of at most about 2 tiles. With Map size Normal the extra room is open sea (about 32% land)."},
				}, DefaultValue = 4},
			{key = "islands", Name = "Small islands (1-10 tiles)",
				Values = {
					{"Few", "Some islands of 5-10 tiles and a few of 1-3."},
					{"Normal", "Many islands of 5-10 tiles, some of 1-3."},
					{"Lots", "Lots of islands of 5-10 and 1-3 tiles."},
				}, DefaultValue = 2},
			{key = "gaps", Name = "Distance between islands",
				Values = {
					{"Close (clusters)", "Islands sit 1-2 tiles of water apart, in groups."},
					{"Normal", "Islands sit about 2-3 tiles of water apart."},
					{"Far", "Islands are spread out with open water between them."},
				}, DefaultValue = 1, hidden = true},
			{key = "shapes", Name = "Island shapes",
				Values = {
					{"Mixed", "Round, irregular and long thin islands."},
					{"Round", "Compact islands."},
					{"Long and thin", "Mostly stringy islands (start islands stay compact)."},
				}, DefaultValue = 1, hidden = true},
			{key = "hills", Name = "Hills",
				Values = {
					{"1 (about 20%)", "About one land tile in five is a hill. Thin islands get more, round ones fewer."},
					{"2 (about 30%)", "About three land tiles in ten are hills (the old default). Thin islands get more, round ones fewer."},
					{"3 (about 42%)", "More hills. Thin islands get more, round ones fewer."},
					{"4 (about 56%)", "Lots of hills. Thin islands get more, round ones fewer."},
					{"5 (about 76%)", "Most of the land is hills. Thin islands get more, round ones fewer."},
					{"6 (about 90%)", "Nearly all hills. Thin islands get more, round ones fewer."},
				}, DefaultValue = 5},
			{key = "density", Name = "Land resources (bonus)",
				Values = {
					{"1", "About 4% of free land tiles get an extra bonus resource; capitals get 2 land bonus within 3 tiles."},
					{"2", "About 8% extra (the old default); capitals get 3 land bonus within 3 tiles."},
					{"3", "About 12% extra; capitals get 3 land bonus within 3 tiles."},
					{"4", "About 16% extra; capitals get 4 land bonus within 3 tiles."},
					{"5", "About 20% extra; capitals get 4 land bonus within 3 tiles."},
					{"6", "About 25% extra; capitals get 5 land bonus within 3 tiles."},
				}, DefaultValue = 3},
			{key = "seaamount", Name = "Sea resources (Fish)",
				Values = {
					{"1", "1 Fish per 8 coast tiles of an island."},
					{"2", "1 Fish per 6 coast tiles (the old default)."},
					{"3", "1 Fish per 5 coast tiles."},
					{"4", "1 Fish per 4 coast tiles."},
					{"4.5", "1 Fish per 3.75 coast tiles."},
					{"5", "1 Fish per 3.5 coast tiles."},
					{"6", "1 Fish per 3 coast tiles."},
				}, DefaultValue = 6},
			{key = "ocean", Name = "Deep ocean (share of the water)",
				Values = {
					{"5%", "Shallow coast nearly everywhere."},
					{"15%", "Mostly shallow coast."},
					{"25%", "Coast around and between the islands, deep ocean in the open stretches."},
					{"35%", "More deep ocean between island groups."},
					{"45%", "Coast near the islands, a lot of deep ocean."},
				}, DefaultValue = 4, hidden = true},
			{key = "searesources", Name = "Fish spread",
				Values = {
					{"Even", "Fish spread evenly round every island by coast length, never two side by side. Every capital gets the same."},
					{"Varied", "Some islands rich in Fish, some with none (capitals still the same)."},
				}, DefaultValue = 1, hidden = true},
			{key = "coastlux", Name = "Coastal luxuries (Whales, Pearls, Crab)",
				Values = {
					{"The game's", "Only what the game places."},
					{"More", "Every capital gets one within 3 tiles, plus about one more per player on other islands' coasts."},
					{"Lots", "Every capital gets one, plus about two more per player."},
				}, DefaultValue = 1, hidden = true},
			{key = "atolls", Name = "Atolls",
				Values = {
					{"The game's", "Only what the game places."},
					{"More", "About two extra atolls per player on open coasts."},
					{"Lots", "About four extra atolls per player."},
				}, DefaultValue = 2, hidden = true},
			MirrorWrapOptionDef(),
		};
	elseif MIRROR_VARIANT == "eastwest" then
		defs = {
			{key = "mapsize", Name = "Map size",
				Values = {
					{"Normal", "The game's size for the world size picked in the lobby."},
					{"Compact", "About three quarters of the tiles: less room, neighbours closer."},
					{"Brawl", "A bit over half the tiles: little room, neighbours close."},
				}, DefaultValue = 1},
			MirrorAgeOptionDef(),
			{key = "gap", Name = "Sea between",
				Values = {
					{"Normal (the game's)", "The game's West vs East channel: 3-4 tiles of water, 1-2 in the middle rows."},
					{"Wide", "Two more tiles of water: 5-6 tiles, 3-4 in the middle rows."},
				}, DefaultValue = 1},
			MirrorCoastalStartsOptionDef(),
		};
	elseif MIRROR_VARIANT == "ring" then
		defs = {
			{key = "mapsize", Name = "Map size",
				Values = {
					{"Normal", "The game's size for the world size picked in the lobby."},
					{"Compact", "About three quarters of the tiles: less room, neighbours closer."},
					{"Brawl", "A bit over half the tiles: little room, neighbours close."},
				}, DefaultValue = 1},
			{key = "ringterrain", Name = "TXT_KEY_MAP_OPTION_DOMINANT_TERRAIN",
				Values = {
					{"TXT_KEY_MAP_SCRIPT_SKIRMISH_GRASSLANDS", "TXT_KEY_MAP_SCRIPT_SKIRMISH_GRASSLANDS_HELP"},
					{"TXT_KEY_MAP_SCRIPT_SKIRMISH_PLAINS", "TXT_KEY_MAP_SCRIPT_SKIRMISH_PLAINS_HELP"},
					{"TXT_KEY_MAP_SCRIPT_SKIRMISH_FOREST", "TXT_KEY_MAP_SCRIPT_SKIRMISH_FOREST_HELP"},
					{"TXT_KEY_MAP_SCRIPT_SKIRMISH_JUNGLE", "TXT_KEY_MAP_SCRIPT_SKIRMISH_JUNGLE_HELP"},
					"TXT_KEY_MAP_OPTION_RANDOM",
				}, DefaultValue = 5},
			{key = "ringshape", Name = "TXT_KEY_MAP_OPTION_LAND_SHAPE",
				Values = {
					{"TXT_KEY_MAP_OPTION_NATURAL", "TXT_KEY_MAP_OPTION_NATURAL_HELP"},
					{"TXT_KEY_MAP_OPTION_PRESSED", "TXT_KEY_MAP_OPTION_PRESSED_HELP"},
					{"TXT_KEY_MAP_OPTION_SOLID", "TXT_KEY_MAP_OPTION_SOLID_HELP"},
					"TXT_KEY_MAP_OPTION_RANDOM",
				}, DefaultValue = 4},
			{key = "isthmus", Name = "TXT_KEY_MAP_OPTION_ISTHMUS_WIDTH",
				Values = {
					{"TXT_KEY_MAP_OPTION_PLOTS_WIDE_TWO", "TXT_KEY_MAP_OPTION_PLOTS_WIDE_TWO_HELP"},
					{"TXT_KEY_MAP_OPTION_PLOTS_WIDE_THREE", "TXT_KEY_MAP_OPTION_PLOTS_WIDE_THREE_HELP"},
					{"TXT_KEY_MAP_OPTION_PLOTS_WIDE_FOUR", "TXT_KEY_MAP_OPTION_PLOTS_WIDE_FOUR_HELP"},
					"TXT_KEY_MAP_OPTION_RANDOM",
				}, DefaultValue = 2},
			MirrorCoastalStartsOptionDef(),
		};
	end
	if MIRROR_VARIANT ~= "ring" then	-- Ring.lua has no climate options
		for loop, def in ipairs(MirrorClimateOptionDefs()) do
			table.insert(defs, def);
		end
	end
	table.insert(defs, {key = "resources", Name = "TXT_KEY_MAP_OPTION_RESOURCES", Values = {"TXT_KEY_MAP_OPTION_BALANCED_RESOURCES"}, DefaultValue = 1});
	return defs;
end
mirror_hiddenValue = {};	-- GLOBAL hidden option key -> its fixed value (not shown in the lobby)
function MirrorVisibleOptionDefs()
	local out = {};
	for _, def in ipairs(MirrorVariantOptionDefs()) do
		if not def.hidden then table.insert(out, def) end
	end
	return out;
end
function MirrorBuildOptionIndex()
	mirror_optionIndex = {};
	mirror_hiddenValue = {};
	if MIRROR_VARIANT == "skirmish" then
		local keys = {"terrain", "water", "resources", "strip", "width", "mapsize"};
		for n, key in ipairs(keys) do mirror_optionIndex[key] = n end
	else
		for _, def in ipairs(MirrorVariantOptionDefs()) do
			if def.hidden then mirror_hiddenValue[def.key] = def.DefaultValue end
		end
		for n, def in ipairs(MirrorVisibleOptionDefs()) do mirror_optionIndex[def.key] = n end
	end
end
MirrorBuildOptionIndex();
------------------------------------------------------------------------------
function MirrorOpt(key, default)
	-- The lobby value of a map option, or the default if this map has no such option.
	if mirror_hiddenValue[key] ~= nil then return mirror_hiddenValue[key] end
	local n = mirror_optionIndex[key];
	if n == nil then return default end
	local value = Map.GetCustomOption(n);
	if value == nil or value < 1 then return default end
	return value;
end
------------------------------------------------------------------------------
function MirrorLandmassOption()
	-- 1 Skirmish, 2 Pangaea, 3 Archipelago, 4 East vs West, 5 Ring
	if MIRROR_VARIANT == "archipelago" then return 3 end
	if MIRROR_VARIANT == "eastwest" then return 4 end
	if MIRROR_VARIANT == "ring" then return 5 end
	if MIRROR_VARIANT == "pangaea" then return 2 end
	return 1;
end
------------------------------------------------------------------------------
function GetMapScriptInfo()
	if MIRROR_VARIANT == "skirmish" then
		return MirrorSkirmishScriptInfo();
	end
	local names = {
		pangaea = {"Mirror Map: Pangaea 1.1", "The game's Pangaea (one continent, ocean around it), with an exact left-right mirror, one team per side. Optional strip down the middle. Strategic balance: every capital gets Horses, Iron, Coal (7) and Aluminium (3) within 3 tiles."},
		archipelago = {"Mirror Map: KEK Archipelago 1.1", "Our KEK Archipelago, mirrored left-right for team games. Every player starts on an island of 20-40 tiles (option, up to 30-50), with islands of every size (1-30 tiles) all over the map and clusters of smaller islands; extra hills, Fish spread evenly, more coastal luxuries and atolls. Every player also gets an own 16-tile expansion island off their coast (option), and small islands get extra Fish. Options for sizes, gaps, shapes, ocean and resources. Strategic balance: Horses, Iron (9), Coal (7) and Aluminium (3) within 3 tiles of every capital."},
		eastwest = {"Mirror Map: East vs West 1.1", "The game's West vs East, mirrored: all land with a water channel down the middle, one team per side. At least one player of each team starts on the coast. Strategic balance: Horses, Iron, Coal (7) and Aluminium (3) within 3 tiles of every capital."},
		ring = {"Mirror Map: Ring 1.1", "The game's Ring, mirrored: a loop of land joining one sub-continent per player, a polar island with the city states in the middle. Teams start on the west and east halves. Strategic balance: Horses, Iron, Coal (7) and Aluminium (3) within 3 tiles of every capital."},
	};
	local options = {};
	for n, def in ipairs(MirrorVisibleOptionDefs()) do
		table.insert(options, {Name = def.Name, Values = def.Values, DefaultValue = def.DefaultValue, SortPriority = n});
	end
	return {
		Name = names[MIRROR_VARIANT][1],
		Description = names[MIRROR_VARIANT][2],
		IconAtlas = "WORLDTYPE_ATLAS_2",
		IconIndex = 0,
		SupportsSinglePlayer = true,
		SupportsMultiplayer = true,
		CustomOptions = options,
	};
end
------------------------------------------------------------------------------

function GetMapInitData(worldSize)
	-- This function can reset map grid sizes or world wrap settings.
	--
	-- East vs West and Ring: the game's own (smaller) sizes for those scripts.
	local landmass = MirrorLandmassOption();
	local own = nil;
	if landmass == 4 then
		own = {[0] = {20, 14}, {30, 20}, {36, 24}, {44, 28}, {52, 32}, {64, 40}};
	elseif landmass == 5 then
		own = {[0] = {32, 20}, {44, 28}, {52, 32}, {64, 40}, {84, 52}, {104, 64}};
	end
	if own ~= nil then
		local world = GameInfo.Worlds[worldSize];
		local size = nil;
		if world ~= nil then size = own[world.ID] end
		if size == nil then size = own[3] end
		local f = ({1.0, 0.87, 0.74})[MirrorOpt("mapsize", 1)] or 1.0;
		local w, h = math.floor(size[1] * f + 0.5), math.floor(size[2] * f + 0.5);
		if w % 2 == 1 then w = w + 1 end
		return {Width = w, Height = h, WrapX = false};
	end
	-- Pangaea landmass: the game's normal map sizes, as the game's Pangaea uses
	-- (but without wrapping round east-west: the mirror needs two map edges).
	if MirrorLandmassOption() >= 2 then
		local world = GameInfo.Worlds[worldSize];
		if world ~= nil then
			local width, height = world.GridWidth, world.GridHeight;
			if MIRROR_VARIANT == "pangaea" then
				-- Mirror Pangaea (user): fewer tiles on the small world sizes, duel -30%,
				-- tiny -40%, small -50% (each side x the square root). Not when the game
				-- has more players than the world size is made for.
				local cut = ({[0] = 0.3, [1] = 0.4, [2] = 0.5})[world.ID] or 0;
				local ok, numPlayers = pcall(function()
					local n = 0;
					for i = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
						local st = PreGame.GetSlotStatus(i);
						if st == SlotStatus.SS_TAKEN or st == SlotStatus.SS_COMPUTER then n = n + 1 end
					end
					return n;
				end);
				if ok and numPlayers > (world.DefaultPlayers or 99) then cut = 0 end
				local f = math.sqrt(1 - cut);
				width, height = math.floor(width * f + 0.5), math.floor(height * f + 0.5);
			end
			if MIRROR_VARIANT == "archipelago" then
				-- Map size option: Normal / Compact (about 3/4 of the tiles) / Brawl (about 0.55)
				local f = ({1.0, 0.87, 0.74})[MirrorOpt("mapsize", 2)] or 1.0;
				width, height = math.floor(width * f + 0.5), math.floor(height * f + 0.5);
			end
			if width % 2 == 1 then
				width = width + 1;	-- the mirror needs an even width
			end
			return {
				Width = width,
				Height = height,
				WrapX = (MirrorOpt("wrap", 2) == 1),	-- Pangaea / Archipelago: option, default yes
			};
		end
	end
	--
	-- Skirmish is a world without oceans, so use grid sizes two levels below normal.
	local worldsizes = {
		[GameInfo.Worlds.WORLDSIZE_DUEL.ID] = {24, 16},
		[GameInfo.Worlds.WORLDSIZE_TINY.ID] = {32, 20},
		[GameInfo.Worlds.WORLDSIZE_SMALL.ID] = {40, 24},
		[GameInfo.Worlds.WORLDSIZE_STANDARD.ID] = {52, 32},
		[GameInfo.Worlds.WORLDSIZE_LARGE.ID] = {64, 40},
		[GameInfo.Worlds.WORLDSIZE_HUGE.ID] = {84, 52}
		}
	local grid_size = worldsizes[worldSize];
	if grid_size ~= nil then
		-- Map size option: Normal / Compact (about 3/4 of the tiles) / Brawl (about 0.55)
		local f = ({1.0, 0.87, 0.74})[MirrorOpt("mapsize", 1)] or 1.0;
		local w = math.floor(grid_size[1] * f + 0.5);
		if w % 2 == 1 then w = w + 1 end
		grid_size = {w, math.floor(grid_size[2] * f + 0.5)};
	end
	-- Mirror Skirmish: with a dead strip (instead of Skirmish's usable middle band),
	-- two columns are added, so the strip does not eat into the players' land.
	-- With no strip ("None"), Skirmish's own sizes and middle band are used.
	if MirrorOpt("strip", 1) ~= 6 and grid_size ~= nil then
		grid_size = {grid_size[1] + 2, grid_size[2]};
	end
	--
	local world = GameInfo.Worlds[worldSize];
	if(world ~= nil) then
	return {
		Width = grid_size[1],
		Height = grid_size[2],
		WrapX = false,
	};
     end
end
-------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- MIRROR GEOMETRY AND COPY TOOLS
------------------------------------------------------------------------------
-- Plot kinds (indexed by plot index, 0-based like the engine)
MIRROR_WEST, MIRROR_EAST, MIRROR_STRIP, MIRROR_LONE, MIRROR_AXIS = 1, 2, 3, 4, 5;
mirror_kind = {};			-- GLOBAL plot kind table
mirror_twin = {};			-- GLOBAL twin plot index, or -1
mirror_axisDist = {};		-- GLOBAL distance of the hex centre from the centre line, in hex widths
mirror_side = {};			-- GLOBAL -1 hex centre west of the centre line, 0 on it, 1 east of it
mirror_centre = {};			-- GLOBAL (no strip only) the plots touching the centre line: no start, city state, ruin or wonder
mirror_continent = {};		-- GLOBAL (Pangaea) plot belongs to the continent, not the surrounding ocean
mirror_landmass = 1;		-- 1 Skirmish (all land), 2 Pangaea
mirror_stripType = 1;		-- 0 none, 1 desert, 2 snow, 3 mountains with passes, 4 water
mirror_stripHalf = 1.0;		-- strip = hex centres within this distance of the centre line (0 = no strip)
mirror_passRows = {};		-- rows (y) that are passes through a mountain strip
mirror_axisCityIndex = -1;	-- plot index of a city state sitting on the centre line (odd count), or -1
mirror_initDone = false;
mirror_wrap = false;		-- GLOBAL the map wraps east-west (Pangaea, Archipelago)
------------------------------------------------------------------------------
function MirrorInit()
	local iW, iH = Map.GetGridSize();
	mirror_landmass = MirrorLandmassOption();
	-- Strip option: 1 default, 2 desert, 3 snow, 4 mountains, 5 water, 6 none.
	local stripOption = MirrorOpt("strip", 1);
	if mirror_landmass >= 3 then stripOption = 6 end	-- the new landmasses have no strip
	if stripOption == 1 then
		if mirror_landmass == 2 then
			mirror_stripType = 0;	-- Pangaea: no divider unless one is picked
		else
			mirror_stripType = 1;
		end
	elseif stripOption >= 2 and stripOption <= 5 then
		mirror_stripType = stripOption - 1;
	else
		mirror_stripType = 0;
	end
	mirror_stripHalf = 1.0;
	if MirrorOpt("width", 1) == 2 then
		mirror_stripHalf = 1.5;
	end
	if mirror_stripType == 0 then
		mirror_stripHalf = 0;
	end
	local axis = (iW - 1) / 2;
	for y = 0, iH - 1 do
		local odd = (y % 2 == 1);
		for x = 0, iW - 1 do
			local i = y * iW + x;
			local centre = x;
			if odd then centre = x + 0.5 end
			local dist = math.abs(centre - axis);
			mirror_axisDist[i] = dist;
			if dist < 0.0001 then
				mirror_side[i] = 0;
			elseif centre < axis then
				mirror_side[i] = -1;
			else
				mirror_side[i] = 1;
			end
			local tx = iW - 1 - x;
			if odd then tx = iW - 2 - x end
			if tx < 0 then
				mirror_twin[i] = -1;
			else
				mirror_twin[i] = y * iW + tx;
			end
			mirror_centre[i] = false;
			if mirror_stripType ~= 0 and dist <= mirror_stripHalf + 0.0001 then
				mirror_kind[i] = MIRROR_STRIP;
			elseif mirror_twin[i] == -1 then
				mirror_kind[i] = MIRROR_LONE;
			elseif dist < 0.0001 then
				mirror_kind[i] = MIRROR_AXIS;	-- its own mirror image (odd rows, no strip)
			elseif centre < axis then
				mirror_kind[i] = MIRROR_WEST;
			else
				mirror_kind[i] = MIRROR_EAST;
			end
			if mirror_stripType == 0 and dist <= 0.5001 then
				mirror_centre[i] = true;
			end
			mirror_continent[i] = true;
		end
	end
	-- Passes through a mountain strip: every fourth row, counted from the middle row.
	mirror_passRows = {};
	local mid = math.floor(iH / 2);
	for y = 1, iH - 2 do
		if (y - mid) % 4 == 0 then
			mirror_passRows[y] = true;
		end
	end
	-- World wrap: the flip x -> W-1-x also flips about the seam between the
	-- east and west edges. The odd-row plot at x = W-1 sits on that line and is
	-- its own mirror image (instead of a lone plot); the plots touching the seam
	-- get no start, city state, ruin or wonder, like those at the centre line.
	mirror_wrap = (Map.IsWrapX ~= nil and Map.IsWrapX()) and true or false;	-- GLOBAL
	if mirror_wrap then
		for y = 0, iH - 1 do
			for x = 0, iW - 1 do
				local i = y * iW + x;
				local c = x;
				if y % 2 == 1 then c = x + 0.5 end
				local seamDist = math.min(c + 0.5, (iW - 0.5) - c);
				if mirror_kind[i] == MIRROR_LONE then
					mirror_kind[i] = MIRROR_AXIS;
					mirror_twin[i] = i;
					mirror_side[i] = 0;
				end
				if seamDist <= 0.5001 then
					mirror_centre[i] = true;
				end
			end
		end
	end
	mirror_axisCityIndex = -1;
	mirror_initDone = true;
	print("Mirror Skirmish: landmass", mirror_landmass, "strip type", mirror_stripType, "strip half width", mirror_stripHalf);
end
------------------------------------------------------------------------------
function MirrorKindAt(x, y)
	local iW, iH = Map.GetGridSize();
	return mirror_kind[y * iW + x];
end
------------------------------------------------------------------------------
function MirrorTwinX(x, y)
	-- Returns the mirrored x on the same row, or nil for a lone plot.
	local iW, iH = Map.GetGridSize();
	local tx = iW - 1 - x;
	if y % 2 == 1 then tx = iW - 2 - x end
	if tx < 0 then return nil end
	return tx;
end
------------------------------------------------------------------------------
function MirrorTwinDistance(x, y)
	-- Hex distance between a plot and its mirror image (0 on the centre line).
	local tx = MirrorTwinX(x, y);
	if tx == nil then return 0 end
	return Map.PlotDistance(x, y, tx, y);
end
------------------------------------------------------------------------------
function MirrorIsBlockedIndex(i)
	-- Strip and lone plots must stay empty (the one centre-line city state aside).
	local k = mirror_kind[i];
	return k == MIRROR_STRIP or k == MIRROR_LONE;
end
------------------------------------------------------------------------------
function MirrorIsNoSiteIndex(i)
	-- No start, city state, ruin or natural wonder here: strip, lone plots, and
	-- (with no strip) the plots touching the centre line.
	return MirrorIsBlockedIndex(i) or mirror_centre[i] == true;
end
------------------------------------------------------------------------------
function MirrorIsNoResourceIndex(i)
	-- Resources are allowed on a centre-line plot only if it is its own mirror image.
	if MirrorIsBlockedIndex(i) then return true end
	return mirror_centre[i] == true and mirror_kind[i] ~= MIRROR_AXIS;
end
------------------------------------------------------------------------------
function MirrorFlow(flow)
	-- Flipping east and west turns NE into NW and SE into SW; N and S stay.
	if flow == FlowDirectionTypes.FLOWDIRECTION_NORTHEAST then
		return FlowDirectionTypes.FLOWDIRECTION_NORTHWEST;
	elseif flow == FlowDirectionTypes.FLOWDIRECTION_NORTHWEST then
		return FlowDirectionTypes.FLOWDIRECTION_NORTHEAST;
	elseif flow == FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST then
		return FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST;
	elseif flow == FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST then
		return FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST;
	end
	return flow;
end
------------------------------------------------------------------------------
function MirrorCopyPlot(src, dst, bPlotType, bTerrain, bFeature, bResource, bImprovement)
	-- Order matters: plot type first (it can reset terrain), then terrain, feature, resource.
	if bPlotType and dst:GetPlotType() ~= src:GetPlotType() then
		dst:SetPlotType(src:GetPlotType(), false, false);
	end
	if bTerrain and dst:GetTerrainType() ~= src:GetTerrainType() then
		dst:SetTerrainType(src:GetTerrainType(), false, false);
	end
	if bFeature and dst:GetFeatureType() ~= src:GetFeatureType() then
		dst:SetFeatureType(src:GetFeatureType(), -1);
	end
	if bResource then
		local res = src:GetResourceType(-1);
		if res == -1 then
			if dst:GetResourceType(-1) ~= -1 then
				dst:SetResourceType(-1, 0);
			end
		elseif dst:GetResourceType(-1) ~= res or dst:GetNumResource() ~= src:GetNumResource() then
			dst:SetResourceType(res, src:GetNumResource());
		end
	end
	if bImprovement and dst:GetImprovementType() ~= src:GetImprovementType() then
		dst:SetImprovementType(src:GetImprovementType());
	end
end
------------------------------------------------------------------------------
function MirrorWestToEast(bPlotType, bTerrain, bFeature, bResource, bImprovement)
	-- Copies the chosen layers of every west plot onto its east twin.
	local iW, iH = Map.GetGridSize();
	for i = 0, iW * iH - 1 do
		if mirror_kind[i] == MIRROR_WEST then
			local src = Map.GetPlotByIndex(i);
			local dst = Map.GetPlotByIndex(mirror_twin[i]);
			MirrorCopyPlot(src, dst, bPlotType, bTerrain, bFeature, bResource, bImprovement);
		end
	end
end
------------------------------------------------------------------------------
function MirrorWholeMap(bImprovements)
	MirrorWestToEast(true, true, true, true, bImprovements == true);
	MirrorRivers();
	MirrorApplyStrip();
	MirrorFixLonePlots();
end
------------------------------------------------------------------------------
function MirrorClearRiverEdgesAround(plot)
	-- Clears all six river edges of a plot. Each edge is stored on the plot to
	-- its west / north-west / north-east, so three of them live on neighbours.
	plot:SetWOfRiver(false, FlowDirectionTypes.NO_FLOWDIRECTION);
	plot:SetNWOfRiver(false, FlowDirectionTypes.NO_FLOWDIRECTION);
	plot:SetNEOfRiver(false, FlowDirectionTypes.NO_FLOWDIRECTION);
	local x, y = plot:GetX(), plot:GetY();
	local westPlot = Map.PlotDirection(x, y, DirectionTypes.DIRECTION_WEST);
	if westPlot ~= nil and westPlot:IsWOfRiver() then
		westPlot:SetWOfRiver(false, FlowDirectionTypes.NO_FLOWDIRECTION);
	end
	local nwPlot = Map.PlotDirection(x, y, DirectionTypes.DIRECTION_NORTHWEST);
	if nwPlot ~= nil and nwPlot:IsNWOfRiver() then
		nwPlot:SetNWOfRiver(false, FlowDirectionTypes.NO_FLOWDIRECTION);
	end
	local nePlot = Map.PlotDirection(x, y, DirectionTypes.DIRECTION_NORTHEAST);
	if nePlot ~= nil and nePlot:IsNEOfRiver() then
		nePlot:SetNEOfRiver(false, FlowDirectionTypes.NO_FLOWDIRECTION);
	end
end
------------------------------------------------------------------------------
function MirrorRivers()
	-- Rivers run along plot edges. A plot stores its east edge (W of river),
	-- south-east edge (NW of river) and south-west edge (NE of river). Only
	-- edges between two west plots are kept; each is copied to its mirror edge:
	--   east edge of P       -> west edge of P'  (stored on the plot west of P'), flow N/S unchanged
	--   south-east edge of P -> south-west edge of P', flow NE<->NW, SW<->SE
	--   south-west edge of P -> south-east edge of P', flow NW<->NE, SE<->SW
	local iW, iH = Map.GetGridSize();
	local edges = {};
	for i = 0, iW * iH - 1 do
		if mirror_kind[i] == MIRROR_WEST then
			local plot = Map.GetPlotByIndex(i);
			local x, y = plot:GetX(), plot:GetY();
			if plot:IsWOfRiver() then
				local adj = Map.PlotDirection(x, y, DirectionTypes.DIRECTION_EAST);
				if adj ~= nil and mirror_kind[adj:GetY() * iW + adj:GetX()] == MIRROR_WEST then
					table.insert(edges, {i, 1, plot:GetRiverEFlowDirection()});
				else
					plot:SetWOfRiver(false, FlowDirectionTypes.NO_FLOWDIRECTION);
				end
			end
			if plot:IsNWOfRiver() then
				local adj = Map.PlotDirection(x, y, DirectionTypes.DIRECTION_SOUTHEAST);
				if adj ~= nil and mirror_kind[adj:GetY() * iW + adj:GetX()] == MIRROR_WEST then
					table.insert(edges, {i, 2, plot:GetRiverSEFlowDirection()});
				else
					plot:SetNWOfRiver(false, FlowDirectionTypes.NO_FLOWDIRECTION);
				end
			end
			if plot:IsNEOfRiver() then
				local adj = Map.PlotDirection(x, y, DirectionTypes.DIRECTION_SOUTHWEST);
				if adj ~= nil and mirror_kind[adj:GetY() * iW + adj:GetX()] == MIRROR_WEST then
					table.insert(edges, {i, 3, plot:GetRiverSWFlowDirection()});
				else
					plot:SetNEOfRiver(false, FlowDirectionTypes.NO_FLOWDIRECTION);
				end
			end
		end
	end
	-- Wipe every river flag that is not stored on a west plot.
	for i = 0, iW * iH - 1 do
		if mirror_kind[i] ~= MIRROR_WEST then
			local plot = Map.GetPlotByIndex(i);
			plot:SetWOfRiver(false, FlowDirectionTypes.NO_FLOWDIRECTION);
			plot:SetNWOfRiver(false, FlowDirectionTypes.NO_FLOWDIRECTION);
			plot:SetNEOfRiver(false, FlowDirectionTypes.NO_FLOWDIRECTION);
		end
	end
	-- Lay down the mirror edges.
	for loop, edge in ipairs(edges) do
		local twin = Map.GetPlotByIndex(mirror_twin[edge[1]]);
		local tx, ty = twin:GetX(), twin:GetY();
		if edge[2] == 1 then
			local westOfTwin = Map.PlotDirection(tx, ty, DirectionTypes.DIRECTION_WEST);
			if westOfTwin ~= nil then
				westOfTwin:SetWOfRiver(true, MirrorFlow(edge[3]));
			end
		elseif edge[2] == 2 then
			twin:SetNEOfRiver(true, MirrorFlow(edge[3]));
		else
			twin:SetNWOfRiver(true, MirrorFlow(edge[3]));
		end
	end
	MirrorLayCrossRiver();
end
------------------------------------------------------------------------------
function MirrorWaterTerrainAt(x, y)
	-- Coast next to land, deep ocean elsewhere (decided by plot types only, which are mirrored).
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
		local adj = Map.PlotDirection(x, y, direction);
		if adj ~= nil and not adj:IsWater() then
			return TerrainTypes.TERRAIN_COAST;
		end
	end
	return TerrainTypes.TERRAIN_OCEAN;
end
------------------------------------------------------------------------------
function MirrorStripLooksAt(x, y)
	-- What a strip plot becomes: plot type and terrain.
	local iW, iH = Map.GetGridSize();
	local i = y * iW + x;
	if i == mirror_axisCityIndex then
		return PlotTypes.PLOT_LAND, TerrainTypes.TERRAIN_PLAINS;
	end
	if mirror_continent[i] ~= true then
		-- Pangaea: where the strip crosses the ocean around the continent it stays ocean.
		return PlotTypes.PLOT_OCEAN, MirrorWaterTerrainAt(x, y);
	end
	local plotType, terrain = PlotTypes.PLOT_LAND, TerrainTypes.TERRAIN_DESERT;
	if mirror_stripType == 2 then
		terrain = TerrainTypes.TERRAIN_SNOW;
	elseif mirror_stripType == 3 then
		if mirror_passRows[y] ~= true then
			plotType = PlotTypes.PLOT_MOUNTAIN;
		end
	elseif mirror_stripType == 4 then
		plotType, terrain = PlotTypes.PLOT_OCEAN, TerrainTypes.TERRAIN_COAST;
	end
	return plotType, terrain;
end
------------------------------------------------------------------------------
function MirrorApplyStrip()
	-- The dead strip: nothing on it. No features, resources, ruins or rivers.
	-- The only exception is a city state on the centre line (odd number of them).
	local iW, iH = Map.GetGridSize();
	-- Plot types first (water terrain depends on the land around it), then the rest.
	for pass = 1, 2 do
		for i = 0, iW * iH - 1 do
			if mirror_kind[i] == MIRROR_STRIP then
				local plot = Map.GetPlotByIndex(i);
				local x, y = plot:GetX(), plot:GetY();
				local plotType, terrain = MirrorStripLooksAt(x, y);
				if plot:GetPlotType() ~= plotType then
					plot:SetPlotType(plotType, false, false);
				end
				if pass == 2 then
					if plot:GetTerrainType() ~= terrain then
						plot:SetTerrainType(terrain, false, false);
					end
					if plot:GetFeatureType() ~= FeatureTypes.NO_FEATURE then
						plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
					end
					if plot:GetResourceType(-1) ~= -1 then
						plot:SetResourceType(-1, 0);
					end
					if plot:GetImprovementType() ~= -1 then
						plot:SetImprovementType(-1);
					end
					MirrorClearRiverEdgesAround(plot);
				end
			end
		end
	end
	-- No strip: the plots touching the centre line carry no ruins, no natural
	-- wonders, and resources only if they are their own mirror image.
	if mirror_stripType == 0 or mirror_wrap then
		for i = 0, iW * iH - 1 do
			if mirror_centre[i] == true and i ~= mirror_axisCityIndex then
				local plot = Map.GetPlotByIndex(i);
				if plot:GetImprovementType() ~= -1 then
					plot:SetImprovementType(-1);
				end
				if MirrorIsNoResourceIndex(i) and plot:GetResourceType(-1) ~= -1 then
					plot:SetResourceType(-1, 0);
				end
				local feature = plot:GetFeatureType();
				if feature ~= FeatureTypes.NO_FEATURE and GameInfo.Features[feature] ~= nil and GameInfo.Features[feature].NaturalWonder then
					plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
				end
			end
		end
		if mirror_axisCityIndex >= 0 then
			MirrorPrepareAxisCityPlot(Map.GetPlotByIndex(mirror_axisCityIndex));
		end
	end
end
------------------------------------------------------------------------------
function MirrorPrepareAxisCityPlot(plot)
	-- The centre-line city state needs flat, settleable land and nothing on its tile.
	if plot:IsWater() or plot:IsMountain() then
		plot:SetPlotType(PlotTypes.PLOT_LAND, false, false);
	end
	local terrain = plot:GetTerrainType();
	if terrain == TerrainTypes.TERRAIN_SNOW or terrain == TerrainTypes.TERRAIN_COAST or terrain == TerrainTypes.TERRAIN_OCEAN then
		plot:SetTerrainType(TerrainTypes.TERRAIN_PLAINS, false, false);
	end
	if plot:GetFeatureType() ~= FeatureTypes.NO_FEATURE then
		plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
	end
	if plot:GetResourceType(-1) ~= -1 then
		plot:SetResourceType(-1, 0);
	end
	if plot:GetImprovementType() ~= -1 then
		plot:SetImprovementType(-1);
	end
	MirrorClearRiverEdgesAround(plot);
end
------------------------------------------------------------------------------
function MirrorFixLonePlots()
	-- The east edge plot of each odd row has no twin. It gets nothing of value:
	-- plain empty desert, or plain water if the tile next to it is water (Pangaea).
	local iW, iH = Map.GetGridSize();
	for y = 1, iH - 1, 2 do
		local i = y * iW + iW - 1;
		if mirror_kind[i] == MIRROR_LONE then
			local plot = Map.GetPlotByIndex(i);
			local westPlot = Map.GetPlot(iW - 2, y);
			local plotType, terrain = PlotTypes.PLOT_LAND, TerrainTypes.TERRAIN_DESERT;
			if mirror_landmass >= 2 and westPlot ~= nil and westPlot:IsWater() then
				plotType, terrain = PlotTypes.PLOT_OCEAN, westPlot:GetTerrainType();
			end
			if plot:GetPlotType() ~= plotType then
				plot:SetPlotType(plotType, false, false);
			end
			if plot:GetTerrainType() ~= terrain then
				plot:SetTerrainType(terrain, false, false);
			end
			if plot:GetFeatureType() ~= FeatureTypes.NO_FEATURE then
				plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
			end
			if plot:GetResourceType(-1) ~= -1 then
				plot:SetResourceType(-1, 0);
			end
			if plot:GetImprovementType() ~= -1 then
				plot:SetImprovementType(-1);
			end
			MirrorClearRiverEdgesAround(plot);
		end
	end
end
------------------------------------------------------------------------------
function MirrorContinentArt()
	-- Continent art (which art set the land uses) is only looks, but mirror it too.
	local iW, iH = Map.GetGridSize();
	local probe = Map.GetPlot(0, 0);
	if probe == nil or probe.GetContinentArtType == nil or probe.SetContinentArtType == nil then
		return
	end
	for i = 0, iW * iH - 1 do
		if mirror_kind[i] == MIRROR_WEST then
			local src = Map.GetPlotByIndex(i);
			local dst = Map.GetPlotByIndex(mirror_twin[i]);
			dst:SetContinentArtType(src:GetContinentArtType());
		end
	end
end
------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MultilayeredFractal:GeneratePlotsByRegion()
	-- Sirian's MultilayeredFractal controlling function.
	-- You -MUST- customize this function for each script using MultilayeredFractal.
	--
	-- This implementation is specific to Skirmish.
	local iW, iH = Map.GetGridSize();
	local fracFlags = {FRAC_WRAP_X = true, FRAC_POLAR = true};
	self.wholeworldPlotTypes = table.fill(PlotTypes.PLOT_LAND, iW * iH);

	-- Get user inputs.
	dominant_terrain = MirrorOpt("terrain", 9) -- GLOBAL variable.
	if dominant_terrain == 9 then -- Random
		dominant_terrain = 1 + Map.Rand(8, "Random Type of Dominant Terrain - Skirmish LUA");
	end
	userInputWaterSetting = MirrorOpt("water", 1) -- GLOBAL variable.
	if userInputWaterSetting == 6 then -- Random
		userInputWaterSetting = 1 + Map.Rand(5, "Random Water Setting - Skirmish LUA");
	end

	-- Lake density: applies only to Small Lakes and Seas settings.
	if userInputWaterSetting >= 2 and userInputWaterSetting <= 4 then
		local lake_list = {0, 93, 85, 85};
		local lake_grains = {0, 5, 3, 3};
		local lakes = lake_list[userInputWaterSetting];
		local lake_grain = lake_grains[userInputWaterSetting];

		local lakesFrac = Fractal.Create(iW, iH, lake_grain, fracFlags, -1, -1);
		local iLakesThreshold = lakesFrac:GetHeight(lakes);

		for y = 1, iH - 2 do
			for x = 0, iW - 1 do
				local i = y * iW + x + 1; -- add one because Lua arrays start at 1
				local lakeVal = lakesFrac:GetHeight(x, y);
				if lakeVal >= iLakesThreshold then
					self.wholeworldPlotTypes[i] = PlotTypes.PLOT_OCEAN;
				end
			end
		end
	end

	-- Apply hills and mountains.
	if dominant_terrain == 7 then -- Hills dominate.
		local worldsizes = {
			[GameInfo.Worlds.WORLDSIZE_DUEL.ID] = 4,
			[GameInfo.Worlds.WORLDSIZE_TINY.ID] = 4,
			[GameInfo.Worlds.WORLDSIZE_SMALL.ID] = 5,
			[GameInfo.Worlds.WORLDSIZE_STANDARD.ID] = 5,
			[GameInfo.Worlds.WORLDSIZE_LARGE.ID] = 5,
			[GameInfo.Worlds.WORLDSIZE_HUGE.ID] = 5,
			}
		local grain = worldsizes[Map.GetWorldSize()];

		local terrainFrac = Fractal.Create(iW, iH, grain, fracFlags, -1, -1);
		local iHillsThreshold = terrainFrac:GetHeight(70);
		local iPeaksThreshold = terrainFrac:GetHeight(95);
		local iHillsClumps = terrainFrac:GetHeight(10);

		local hillsFrac = Fractal.Create(iW, iH, grain, fracFlags, -1, -1);
		local iHillsBottom1 = hillsFrac:GetHeight(20);
		local iHillsTop1 = hillsFrac:GetHeight(30);
		local iHillsBottom2 = hillsFrac:GetHeight(70);
		local iHillsTop2 = hillsFrac:GetHeight(80);

		for x = 0, iW - 1 do
			for y = 0, iH - 1 do
				local i = y * iW + x + 1;
				local val = terrainFrac:GetHeight(x, y);
				if val >= iPeaksThreshold then
					self.wholeworldPlotTypes[i] = PlotTypes.PLOT_MOUNTAIN;
				elseif val >= iHillsThreshold or val <= iHillsClumps then
					self.wholeworldPlotTypes[i] = PlotTypes.PLOT_HILLS;
				else
					local hillsVal = hillsFrac:GetHeight(x, y);
					if hillsVal >= iHillsBottom1 and hillsVal <= iHillsTop1 then
						self.wholeworldPlotTypes[i] = PlotTypes.PLOT_HILLS;
					elseif hillsVal >= iHillsBottom2 and hillsVal <= iHillsTop2 then
						self.wholeworldPlotTypes[i] = PlotTypes.PLOT_HILLS;
					end
				end
			end
		end

	else -- Normal hills and mountains.
		local args = {
			adjust_plates = 1.2,
		};
		self:ApplyTectonics(args)
	end

	-- Mirror Skirmish: with a strip, Skirmish's four-column buffer zone with random
	-- mountains is replaced by the dead strip, which is laid down after this
	-- function. With no strip ("None") Skirmish's own buffer zone is kept (its
	-- code below, unchanged); the mirror copy then makes it symmetric.
	if mirror_stripType == 0 then
		-- Create buffer zone in middle four columns. This will create some choke points.
		--
		-- Turn all plots in buffer zone to land.
		for x = iW / 2 - 2, iW / 2 + 1 do
			for y = 1, iH - 2 do
				local i = y * iW + x + 1;
				self.wholeworldPlotTypes[i] = PlotTypes.PLOT_LAND;
			end
		end
		-- Add mountains in top and bottom rows of buffer zone.
		for x = iW / 2 - 2, iW / 2 + 1 do
			local i = x + 1;
			self.wholeworldPlotTypes[i] = PlotTypes.PLOT_MOUNTAIN;
			local i = (iH - 1) * iW + x + 1;
			self.wholeworldPlotTypes[i] = PlotTypes.PLOT_MOUNTAIN;
		end
		-- Add random smattering of mountains to middle two columns of buffer zone.
		local west_half, east_half = {}, {};
		for loop = 1, iH - 2 do
			table.insert(west_half, loop);
			table.insert(east_half, loop);
		end
		local west_shuffled = GetShuffledCopyOfTable(west_half)
		local east_shuffled = GetShuffledCopyOfTable(east_half)
		local iNumMountainsPerColumn = math.max(math.floor(iH * 0.225), math.floor((iH / 4) - 1));
		local x_west, x_east = iW / 2 - 1, iW / 2;
		for loop = 1, iNumMountainsPerColumn do
			local y_west, y_east = west_shuffled[loop], east_shuffled[loop];
			local i_west_plot = y_west * iW + x_west + 1;
			local i_east_plot = y_east * iW + x_east + 1;
			self.wholeworldPlotTypes[i_west_plot] = PlotTypes.PLOT_MOUNTAIN;
			self.wholeworldPlotTypes[i_east_plot] = PlotTypes.PLOT_MOUNTAIN;
		end
		-- Hills need to be added near mountains, but this needs to wait until after plot types have been initially set.
	end

	-- Plot Type generation completed. Return global plot array.
	return self.wholeworldPlotTypes
end
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- PANGAEA LANDMASS: the game's own Pangaea.lua (Bob Thomas, Firaxis), mirrored.
-- PangaeaFractalWorld below is copied from Pangaea.lua (a map script cannot
-- include another map script). Only change: Sea Level and World Age are
-- options 7 and 8 in this map's option list (they are 4 and 1 in Pangaea.lua).
------------------------------------------------------------------------------
PangaeaFractalWorld = {};
------------------------------------------------------------------------------
function PangaeaFractalWorld.Create(fracXExp, fracYExp)
	local gridWidth, gridHeight = Map.GetGridSize();
	
	local data = {
		InitFractal = FractalWorld.InitFractal,
		ShiftPlotTypes = FractalWorld.ShiftPlotTypes,
		ShiftPlotTypesBy = FractalWorld.ShiftPlotTypesBy,
		DetermineXShift = FractalWorld.DetermineXShift,
		DetermineYShift = FractalWorld.DetermineYShift,
		GenerateCenterRift = FractalWorld.GenerateCenterRift,
		GeneratePlotTypes = PangaeaFractalWorld.GeneratePlotTypes,	-- Custom method
		
		iFlags = Map.GetFractalFlags(),
		
		fracXExp = fracXExp,
		fracYExp = fracYExp,
		
		iNumPlotsX = gridWidth,
		iNumPlotsY = gridHeight,
		plotTypes = table.fill(PlotTypes.PLOT_OCEAN, gridWidth * gridHeight)
	};
		
	return data;
end	
------------------------------------------------------------------------------
function PangaeaFractalWorld:GeneratePlotTypes(args)
	if(args == nil) then args = {}; end
	
	local sea_level_low = 63;
	local sea_level_normal = 68;
	local sea_level_high = 73;
	local world_age_old = 2;
	local world_age_normal = 3;
	local world_age_new = 5;
	--
	local extra_mountains = 6;
	local grain_amount = 3;
	local adjust_plates = 1.3;
	local shift_plot_types = true;
	local tectonic_islands = true;
	local hills_ridge_flags = self.iFlags;
	local peaks_ridge_flags = self.iFlags;
	local has_center_rift = false;
	
	local sea_level = MirrorOpt("sealevel", 2)
	if sea_level == 4 then
		sea_level = 1 + Map.Rand(3, "Random Sea Level - Lua");
	end
	local world_age = MirrorOpt("age", 2)
	if world_age == 4 then
		world_age = 1 + Map.Rand(3, "Random World Age - Lua");
	end

	-- Set Sea Level according to user selection.
	local water_percent = sea_level_normal;
	if sea_level == 1 then -- Low Sea Level
		water_percent = sea_level_low
	elseif sea_level == 3 then -- High Sea Level
		water_percent = sea_level_high
	else -- Normal Sea Level
	end

	-- Set values for hills and mountains according to World Age chosen by user.
	local adjustment = world_age_normal;
	if world_age == 3 then -- 5 Billion Years
		adjustment = world_age_old;
		adjust_plates = adjust_plates * 0.75;
	elseif world_age == 1 then -- 3 Billion Years
		adjustment = world_age_new;
		adjust_plates = adjust_plates * 1.5;
	else -- 4 Billion Years
	end
	-- Apply adjustment to hills and peaks settings.
	local hillsBottom1 = 28 - adjustment;
	local hillsTop1 = 28 + adjustment;
	local hillsBottom2 = 72 - adjustment;
	local hillsTop2 = 72 + adjustment;
	local hillsClumps = 1 + adjustment;
	local hillsNearMountains = 91 - (adjustment * 2) - extra_mountains;
	local mountains = 97 - adjustment - extra_mountains;

	-- Hills and Mountains handled differently according to map size - Bob
	local WorldSizeTypes = {};
	for row in GameInfo.Worlds() do
		WorldSizeTypes[row.Type] = row.ID;
	end
	local sizekey = Map.GetWorldSize();
	-- Fractal Grains
	local sizevalues = {
		[WorldSizeTypes.WORLDSIZE_DUEL]     = 3,
		[WorldSizeTypes.WORLDSIZE_TINY]     = 3,
		[WorldSizeTypes.WORLDSIZE_SMALL]    = 4,
		[WorldSizeTypes.WORLDSIZE_STANDARD] = 4,
		[WorldSizeTypes.WORLDSIZE_LARGE]    = 5,
		[WorldSizeTypes.WORLDSIZE_HUGE]		= 5
	};
	local grain = sizevalues[sizekey] or 3;
	-- Tectonics Plate Counts
	local platevalues = {
		[WorldSizeTypes.WORLDSIZE_DUEL]		= 6,
		[WorldSizeTypes.WORLDSIZE_TINY]     = 9,
		[WorldSizeTypes.WORLDSIZE_SMALL]    = 12,
		[WorldSizeTypes.WORLDSIZE_STANDARD] = 18,
		[WorldSizeTypes.WORLDSIZE_LARGE]    = 24,
		[WorldSizeTypes.WORLDSIZE_HUGE]     = 30
	};
	local numPlates = platevalues[sizekey] or 5;
	-- Add in any plate count modifications passed in from the map script. - Bob
	numPlates = numPlates * adjust_plates;

	-- Generate continental fractal layer and examine the largest landmass. Reject
	-- the result until the largest landmass occupies 84% or more of the total land.
	local done = false;
	local iAttempts = 0;
	local iWaterThreshold, biggest_area, iNumTotalLandTiles, iNumBiggestAreaTiles, iBiggestID;
	while done == false do
		local grain_dice = Map.Rand(7, "Continental Grain roll - LUA Pangaea");
		if grain_dice < 4 then
			grain_dice = 1;
		else
			grain_dice = 2;
		end
		local rift_dice = Map.Rand(3, "Rift Grain roll - LUA Pangaea");
		if rift_dice < 1 then
			rift_dice = -1;
		end
		
		self.continentsFrac = nil;
		self:InitFractal{continent_grain = grain_dice, rift_grain = rift_dice};
		iWaterThreshold = self.continentsFrac:GetHeight(water_percent);
		
		iNumTotalLandTiles = 0;
		for x = 0, self.iNumPlotsX - 1 do
			for y = 0, self.iNumPlotsY - 1 do
				local i = y * self.iNumPlotsX + x;
				local val = self.continentsFrac:GetHeight(x, y);
				if(val <= iWaterThreshold) then
					self.plotTypes[i] = PlotTypes.PLOT_OCEAN;
				else
					self.plotTypes[i] = PlotTypes.PLOT_LAND;
					iNumTotalLandTiles = iNumTotalLandTiles + 1;
				end
			end
		end

		SetPlotTypes(self.plotTypes);
		Map.RecalculateAreas();
		
		biggest_area = Map.FindBiggestArea(false);
		iNumBiggestAreaTiles = biggest_area:GetNumTiles();
		-- Now test the biggest landmass to see if it is large enough.
		if iNumBiggestAreaTiles >= iNumTotalLandTiles * 0.84 then
			done = true;
			iBiggestID = biggest_area:GetID();
		end
		iAttempts = iAttempts + 1;
		
		--[[ Printout for debug use only
		print("-"); print("--- Pangaea landmass generation, Attempt#", iAttempts, "---");
		print("- This attempt successful: ", done);
		print("- Total Land Plots in world:", iNumTotalLandTiles);
		print("- Land Plots belonging to biggest landmass:", iNumBiggestAreaTiles);
		print("- Percentage of land belonging to Pangaea: ", 100 * iNumBiggestAreaTiles / iNumTotalLandTiles);
		print("- Continent Grain for this attempt: ", grain_dice);
		print("- Rift Grain for this attempt: ", rift_dice);
		print("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -");
		print(".");
		]]--
	end
	
	-- Generate fractals to govern hills and mountains
	self.hillsFrac = Fractal.Create(self.iNumPlotsX, self.iNumPlotsY, grain, self.iFlags, self.fracXExp, self.fracYExp);
	self.mountainsFrac = Fractal.Create(self.iNumPlotsX, self.iNumPlotsY, grain, self.iFlags, self.fracXExp, self.fracYExp);
	self.hillsFrac:BuildRidges(numPlates, hills_ridge_flags, 1, 2);
	self.mountainsFrac:BuildRidges((numPlates * 2) / 3, peaks_ridge_flags, 6, 1);
	-- Get height values
	local iHillsBottom1 = self.hillsFrac:GetHeight(hillsBottom1);
	local iHillsTop1 = self.hillsFrac:GetHeight(hillsTop1);
	local iHillsBottom2 = self.hillsFrac:GetHeight(hillsBottom2);
	local iHillsTop2 = self.hillsFrac:GetHeight(hillsTop2);
	local iHillsClumps = self.mountainsFrac:GetHeight(hillsClumps);
	local iHillsNearMountains = self.mountainsFrac:GetHeight(hillsNearMountains);
	local iMountainThreshold = self.mountainsFrac:GetHeight(mountains);
	local iPassThreshold = self.hillsFrac:GetHeight(hillsNearMountains);
	-- Get height values for tectonic islands
	local iMountain100 = self.mountainsFrac:GetHeight(100);
	local iMountain99 = self.mountainsFrac:GetHeight(99);
	local iMountain97 = self.mountainsFrac:GetHeight(97);
	local iMountain95 = self.mountainsFrac:GetHeight(95);

	-- Because we haven't yet shifted the plot types, we will not be able to take advantage 
	-- of having water and flatland plots already set. We still have to generate all data
	-- for hills and mountains, too, then shift everything, then set plots one more time.
	for x = 0, self.iNumPlotsX - 1 do
		for y = 0, self.iNumPlotsY - 1 do
		
			local i = y * self.iNumPlotsX + x;
			local val = self.continentsFrac:GetHeight(x, y);
			local mountainVal = self.mountainsFrac:GetHeight(x, y);
			local hillVal = self.hillsFrac:GetHeight(x, y);
	
			if(val <= iWaterThreshold) then
				self.plotTypes[i] = PlotTypes.PLOT_OCEAN;
				
				if tectonic_islands then -- Build islands in oceans along tectonic ridge lines - Brian
					if (mountainVal == iMountain100) then -- Isolated peak in the ocean
						self.plotTypes[i] = PlotTypes.PLOT_MOUNTAIN;
					elseif (mountainVal == iMountain99) then
						self.plotTypes[i] = PlotTypes.PLOT_HILLS;
					elseif (mountainVal == iMountain97) or (mountainVal == iMountain95) then
						self.plotTypes[i] = PlotTypes.PLOT_LAND;
					end
				end
					
			else
				if (mountainVal >= iMountainThreshold) then
					if (hillVal >= iPassThreshold) then -- Mountain Pass though the ridgeline - Brian
						self.plotTypes[i] = PlotTypes.PLOT_HILLS;
					else -- Mountain
						self.plotTypes[i] = PlotTypes.PLOT_MOUNTAIN;
					end
				elseif (mountainVal >= iHillsNearMountains) then
					self.plotTypes[i] = PlotTypes.PLOT_HILLS; -- Foot hills - Bob
				else
					if ((hillVal >= iHillsBottom1 and hillVal <= iHillsTop1) or (hillVal >= iHillsBottom2 and hillVal <= iHillsTop2)) then
						self.plotTypes[i] = PlotTypes.PLOT_HILLS;
					else
						self.plotTypes[i] = PlotTypes.PLOT_LAND;
					end
				end
			end
		end
	end

	self:ShiftPlotTypes();
	
	-- Now shift everything toward one of the poles, to reduce how much jungles tend to dominate this script.
	local shift_dice = Map.Rand(2, "Shift direction - LUA Pangaea");
	local iStartRow, iNumRowsToShift;
	local bFoundPangaea, bDoShift = false, false;
	if shift_dice == 1 then
		-- Shift North
		for y = self.iNumPlotsY - 2, 1, -1 do
			for x = 0, self.iNumPlotsX - 1 do
				local i = y * self.iNumPlotsX + x;
				if self.plotTypes[i] == PlotTypes.PLOT_HILLS or self.plotTypes[i] == PlotTypes.PLOT_LAND then
					local plot = Map.GetPlot(x, y);
					local iAreaID = plot:GetArea();
					if iAreaID == iBiggestID then
						bFoundPangaea = true;
						iStartRow = y + 1;
						if iStartRow < self.iNumPlotsY - 4 then -- Enough rows of water space to do a shift.
							bDoShift = true;
						end
						break
					end
				end
			end
			-- Check to see if we've found the Pangaea.
			if bFoundPangaea == true then
				break
			end
		end
	else
		-- Shift South
		for y = 1, self.iNumPlotsY - 2 do
			for x = 0, self.iNumPlotsX - 1 do
				local i = y * self.iNumPlotsX + x;
				if self.plotTypes[i] == PlotTypes.PLOT_HILLS or self.plotTypes[i] == PlotTypes.PLOT_LAND then
					local plot = Map.GetPlot(x, y);
					local iAreaID = plot:GetArea();
					if iAreaID == iBiggestID then
						bFoundPangaea = true;
						iStartRow = y - 1;
						if iStartRow > 3 then -- Enough rows of water space to do a shift.
							bDoShift = true;
						end
						break
					end
				end
			end
			-- Check to see if we've found the Pangaea.
			if bFoundPangaea == true then
				break
			end
		end
	end
	if bDoShift == true then
		if shift_dice == 1 then -- Shift North
			local iRowsDifference = self.iNumPlotsY - iStartRow - 2;
			local iRowsInPlay = math.floor(iRowsDifference * 0.7);
			local iRowsBase = math.ceil(iRowsDifference * 0.3);
			local rows_dice = Map.Rand(iRowsInPlay, "Number of Rows to Shift - LUA Pangaea");
			local iNumRows = math.min(iRowsDifference - 1, iRowsBase + rows_dice);
			local iNumEvenRows = 2 * math.floor(iNumRows / 2); -- MUST be an even number or we risk breaking a 1-tile isthmus and splitting the Pangaea.
			local iNumRowsToShift = math.max(2, iNumEvenRows);
			--print("-"); print("Shifting lands northward by this many plots: ", iNumRowsToShift); print("-");
			-- Process from top down.
			for y = (self.iNumPlotsY - 1) - iNumRowsToShift, 0, -1 do
				for x = 0, self.iNumPlotsX - 1 do
					local sourcePlotIndex = y * self.iNumPlotsX + x + 1;
					local destPlotIndex = (y + iNumRowsToShift) * self.iNumPlotsX + x + 1;
					self.plotTypes[destPlotIndex] = self.plotTypes[sourcePlotIndex]
				end
			end
			for y = 0, iNumRowsToShift - 1 do
				for x = 0, self.iNumPlotsX - 1 do
					local i = y * self.iNumPlotsX + x + 1;
					self.plotTypes[i] = PlotTypes.PLOT_OCEAN;
				end
			end
		else -- Shift South
			local iRowsDifference = iStartRow - 1;
			local iRowsInPlay = math.floor(iRowsDifference * 0.7);
			local iRowsBase = math.ceil(iRowsDifference * 0.3);
			local rows_dice = Map.Rand(iRowsInPlay, "Number of Rows to Shift - LUA Pangaea");
			local iNumRows = math.min(iRowsDifference - 1, iRowsBase + rows_dice);
			local iNumEvenRows = 2 * math.floor(iNumRows / 2); -- MUST be an even number or we risk breaking a 1-tile isthmus and splitting the Pangaea.
			local iNumRowsToShift = math.max(2, iNumEvenRows);
			--print("-"); print("Shifting lands southward by this many plots: ", iNumRowsToShift); print("-");
			-- Process from bottom up.
			for y = 0, (self.iNumPlotsY - 1) - iNumRowsToShift do
				for x = 0, self.iNumPlotsX - 1 do
					local sourcePlotIndex = (y + iNumRowsToShift) * self.iNumPlotsX + x + 1;
					local destPlotIndex = y * self.iNumPlotsX + x + 1;
					self.plotTypes[destPlotIndex] = self.plotTypes[sourcePlotIndex]
				end
			end
			for y = self.iNumPlotsY - iNumRowsToShift, self.iNumPlotsY - 1 do
				for x = 0, self.iNumPlotsX - 1 do
					local i = y * self.iNumPlotsX + x + 1;
					self.plotTypes[i] = PlotTypes.PLOT_OCEAN;
				end
			end
		end
	end

	return self.plotTypes;
end
------------------------------------------------------------------------------
function MirrorLandPieces()
	-- Groups the land into connected pieces (mountains count as land).
	-- Returns the piece number of each plot, the piece sizes and the biggest size.
	local iW, iH = Map.GetGridSize();
	local piece, sizes, numPieces, biggest = {}, {}, 0, 0;
	for i = 0, iW * iH - 1 do
		local plot = Map.GetPlotByIndex(i);
		if piece[i] == nil and not plot:IsWater() then
			numPieces = numPieces + 1;
			piece[i] = numPieces;
			local stack, size = {i}, 0;
			while table.maxn(stack) > 0 do
				local c = table.remove(stack);
				size = size + 1;
				local cp = Map.GetPlotByIndex(c);
				for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
					local adj = Map.PlotDirection(cp:GetX(), cp:GetY(), direction);
					if adj ~= nil and not adj:IsWater() then
						local j = adj:GetY() * iW + adj:GetX();
						if piece[j] == nil then
							piece[j] = numPieces;
							table.insert(stack, j);
						end
					end
				end
			end
			sizes[numPieces] = size;
			biggest = math.max(biggest, size);
		end
	end
	return piece, sizes, biggest;
end
------------------------------------------------------------------------------
function MirrorPangaeaCrossesMiddle()
	-- After mirroring, the continent must be one piece across the centre line
	-- (a biggest-size piece that holds a west plot and its own mirror image) and,
	-- as Pangaea.lua demands of its own map, hold 84% or more of all land.
	-- Returns: crosses, enough land.
	local iW, iH = Map.GetGridSize();
	local piece, sizes, biggest = MirrorLandPieces();
	local total = 0;
	for n, size in ipairs(sizes) do
		total = total + size;
	end
	local bEnough = biggest >= total * 0.84;
	if mirror_stripType == 4 then	-- a water strip makes two equal halves
		bEnough = biggest * 2 >= total * 0.84;
	end
	for i = 0, iW * iH - 1 do
		if mirror_kind[i] == MIRROR_WEST and piece[i] ~= nil and sizes[piece[i]] == biggest
			and piece[mirror_twin[i]] == piece[i] then
			return true, bEnough
		end
	end
	return false, bEnough
end
------------------------------------------------------------------------------
function MirrorBridgePangaea()
	-- Last resort if the continent keeps missing the centre line: join it to its
	-- mirror image with a row of land, from its plot closest to the centre line.
	local iW, iH = Map.GetGridSize();
	local piece, sizes, biggest = MirrorLandPieces();
	local best, bestDist = -1, 9999;
	for i = 0, iW * iH - 1 do
		if mirror_kind[i] == MIRROR_WEST and piece[i] ~= nil and sizes[piece[i]] == biggest and mirror_axisDist[i] < bestDist then
			best, bestDist = i, mirror_axisDist[i];
		end
	end
	if best < 0 then return end
	local y = math.floor(best / iW);
	for x = best % iW, iW - 1 - (best % iW) do
		local plot = Map.GetPlot(x, y);
		if plot ~= nil and plot:IsWater() then
			plot:SetPlotType(PlotTypes.PLOT_LAND, false, false);
		end
	end
	MirrorWestToEast(true, false, false, false, false);
	print("Mirror Skirmish: Pangaea joined across the middle on row", y);
end
------------------------------------------------------------------------------
function MirrorGeneratePangaeaPlotTypes()
	-- The game's own Pangaea plot types, then the west half is mirrored. If the
	-- continent does not reach the centre line, the mirror would make two
	-- continents, so the land is rolled again (the core script itself re-rolls
	-- until its Pangaea is big enough), with a land bridge as the last resort.
	local iW, iH = Map.GetGridSize();
	local bNeedCrossing = (mirror_stripType ~= 4);	-- a water strip splits the halves anyway
	mirror_pangaeaAttempts = 0;						-- GLOBAL, for logs and tests
	local iMaxAttempts = 20;
	-- The user's rule of thumb: a Pangaea is good when the middle of the map is
	-- wide. The first continent that fills at least MIRROR_MIDDLE_SHARE of the
	-- middle band of the map with land is kept as it is (so maps still
	-- differ); a continent joined by a thin neck is rolled again (up to 6 times,
	-- then the one with the widest middle is used).
	local iWanted = 6;
	local best, bestScore, accepted = nil, -1, 0;
	mirror_pangaeaMiddleLog = "";	-- GLOBAL, for logs and tests
	for attempt = 1, iMaxAttempts do
		mirror_pangaeaAttempts = attempt;
		local fractal_world = PangaeaFractalWorld.Create();
		local plotTypes = fractal_world:GeneratePlotTypes();
		SetPlotTypes(plotTypes);
		MirrorWestToEast(true, false, false, false, false);
		local bCrosses, bEnough = MirrorPangaeaCrossesMiddle();
		if (bCrosses or not bNeedCrossing) and bEnough then
			accepted = accepted + 1;
			local middle = MirrorPangaeaMiddleWidth();
			mirror_pangaeaMiddleLog = mirror_pangaeaMiddleLog .. string.format("%.2f ", middle);
			if middle >= MIRROR_MIDDLE_SHARE or not bNeedCrossing then
				best, bestScore = nil, middle;
				break
			end
			if middle > bestScore then
				best, bestScore = MirrorCopyPlotTypes(), middle;
			end
			if accepted >= iWanted then break end
		end
	end
	if best ~= nil then
		MirrorRestorePlotTypes(best);
	elseif accepted == 0 then
		local bCrosses = MirrorPangaeaCrossesMiddle();
		if bNeedCrossing and not bCrosses then
			MirrorBridgePangaea();
		end
		mirror_pangaeaAttempts = iMaxAttempts + 1;
	end
	print("Mirror Skirmish: Pangaea middle width (share of rows) per accepted continent:", mirror_pangaeaMiddleLog);
	MirrorSmoothPangaea();
	MirrorPangaeaCoastIslands();
	-- An explicit strip is laid down only where the continent is; over the ocean it stays ocean.
	for i = 0, iW * iH - 1 do
		mirror_continent[i] = not Map.GetPlotByIndex(i):IsWater();
	end
	for i = 0, iW * iH - 1 do
		if mirror_side[i] == -1 and mirror_twin[i] >= 0 then
			mirror_continent[mirror_twin[i]] = mirror_continent[i];
		end
	end
end
------------------------------------------------------------------------------
function MirrorCopyPlotTypes()
	local iW, iH = Map.GetGridSize();
	local t = {};
	for i = 0, iW * iH - 1 do
		t[i] = Map.GetPlotByIndex(i):GetPlotType();
	end
	return t;
end
------------------------------------------------------------------------------
function MirrorRestorePlotTypes(t)
	local iW, iH = Map.GetGridSize();
	for i = 0, iW * iH - 1 do
		local plot = Map.GetPlotByIndex(i);
		if plot:GetPlotType() ~= t[i] then
			plot:SetPlotType(t[i], false, false);
		end
	end
end
------------------------------------------------------------------------------
MIRROR_MIDDLE_SHARE = 0.45;	-- wide middles measure 0.5-0.8, thin necks or webs of arms 0.2-0.4
function MirrorPangaeaMiddleWidth()
	-- How much of the middle of the map is land: the band within a tenth of the
	-- map width of the centre line, rows 15-85% (no polar ice). Low = the halves
	-- meet at a thin neck or a web of thin arms; high = a wide middle.
	local iW, iH = Map.GetGridSize();
	local band = math.max(3, iW * 0.1);
	local land, total = 0, 0;
	for y = math.floor(iH * 0.15), math.ceil(iH * 0.85) - 1 do
		for x = 0, iW - 1 do
			local i = y * iW + x;
			if mirror_axisDist[i] <= band then
				total = total + 1;
				if not Map.GetPlotByIndex(i):IsWater() then land = land + 1 end
			end
		end
	end
	return land / math.max(1, total);
end
------------------------------------------------------------------------------
function MirrorPangaeaRaggedness()
	-- Coast tiles per 100 land tiles on the west half: a ragged continent of
	-- inlets and thin arms has many, a solid one few.
	local iW, iH = Map.GetGridSize();
	local land, coast = 0, 0;
	for i = 0, iW * iH - 1 do
		if mirror_kind[i] == MIRROR_WEST and not Map.GetPlotByIndex(i):IsWater() then
			land = land + 1;
			for loop, j in ipairs(MirrorNeighbours(i)) do
				if Map.GetPlotByIndex(j):IsWater() then
					coast = coast + 1;
					break
				end
			end
		end
	end
	return math.floor(coast * 100 / math.max(1, land));
end
------------------------------------------------------------------------------
function MirrorSmoothPangaea()
	-- One light pass on the west half, then mirrored: sea tiles with 4 or more land
	-- neighbours become land (fills narrow bays; inland lakes, which touch no
	-- other water, stay), and land tiles with only one land neighbour become
	-- sea (thin spits). Lone island tiles are left alone.
	local iW, iH = Map.GetGridSize();
	for pass = 1, 1 do
		local toLand, toSea = {}, {};
		for i = 0, iW * iH - 1 do
			if mirror_kind[i] == MIRROR_WEST then
				local plot = Map.GetPlotByIndex(i);
				local landN, waterN = 0, 0;
				for loop, j in ipairs(MirrorNeighbours(i)) do
					if Map.GetPlotByIndex(j):IsWater() then waterN = waterN + 1 else landN = landN + 1 end
				end
				if plot:IsWater() then
					if landN >= 4 and waterN >= 1 then table.insert(toLand, i) end
				elseif landN == 1 and plot:GetPlotType() ~= PlotTypes.PLOT_MOUNTAIN then
					table.insert(toSea, i);
				end
			end
		end
		for loop, i in ipairs(toLand) do
			Map.GetPlotByIndex(i):SetPlotType(PlotTypes.PLOT_LAND, false, false);
		end
		for loop, i in ipairs(toSea) do
			Map.GetPlotByIndex(i):SetPlotType(PlotTypes.PLOT_OCEAN, false, false);
		end
		MirrorWestToEast(true, false, false, false, false);
	end
	MirrorBreakMountainChains(3);
end
------------------------------------------------------------------------------
function MirrorBreakMountainChains(maxRun)
	-- No huge mountain chains: no group of touching mountains bigger than
	-- maxRun tiles (1 next to a mirror line, where the mirror doubles it).
	-- The cut tiles become hills, so the land keeps its production.
	local iW, iH = Map.GetGridSize();
	local kept = {};
	local function GroupSize(start)
		local seen, stack, size = {[start] = true}, {start}, 0;
		while table.maxn(stack) > 0 do
			local c = table.remove(stack);
			size = size + 1;
			for loop, j in ipairs(MirrorNeighbours(c)) do
				if kept[j] and not seen[j] then
					seen[j] = true;
					table.insert(stack, j);
				end
			end
		end
		return size;
	end
	local cut = 0;
	for i = 0, iW * iH - 1 do
		if mirror_kind[i] == MIRROR_WEST and Map.GetPlotByIndex(i):GetPlotType() == PlotTypes.PLOT_MOUNTAIN then
			local limit = maxRun;
			if mirror_axisDist[i] <= 1.5 or mirror_centre[i] == true then limit = 1 end
			-- crowded: already 3 kept mountains within 2 tiles (a range of small groups)
			local near, seen2 = 0, {[i] = true};
			for loop, j in ipairs(MirrorNeighbours(i)) do
				if not seen2[j] then
					seen2[j] = true;
					if kept[j] then near = near + 1 end
				end
				for loop2, j2 in ipairs(MirrorNeighbours(j)) do
					if not seen2[j2] then
						seen2[j2] = true;
						if kept[j2] then near = near + 1 end
					end
				end
			end
			kept[i] = true;
			if near >= 3 or GroupSize(i) > limit then
				kept[i] = nil;
				Map.GetPlotByIndex(i):SetPlotType(PlotTypes.PLOT_HILLS, false, false);
				cut = cut + 1;
			end
		end
	end
	MirrorWestToEast(true, false, false, false, false);
	print("Mirror Skirmish: mountain chains broken up, tiles turned to hills:", cut);
end
------------------------------------------------------------------------------
function MirrorMainWestArea()
	-- The area (landmass) holding most of the west land: the Pangaea continent.
	-- Also returns the area of its east mirror image (the same one unless a
	-- water strip splits the halves).
	local iW, iH = Map.GetGridSize();
	local counts = {};
	for i = 0, iW * iH - 1 do
		local plot = Map.GetPlotByIndex(i);
		if mirror_kind[i] == MIRROR_WEST and not plot:IsWater() and not plot:IsMountain() then
			local a = plot:GetArea();
			counts[a] = (counts[a] or 0) + 1;
		end
	end
	local bestArea, bestCount, bestPlot = -1, 0, -1;
	for i = 0, iW * iH - 1 do
		local plot = Map.GetPlotByIndex(i);
		if mirror_kind[i] == MIRROR_WEST and not plot:IsWater() and not plot:IsMountain() then
			local a = plot:GetArea();
			if counts[a] > bestCount then
				bestArea, bestCount, bestPlot = a, counts[a], i;
			end
		end
	end
	local eastArea = bestArea;
	if bestPlot >= 0 then
		eastArea = Map.GetPlotByIndex(mirror_twin[bestPlot]):GetArea();
	end
	return bestArea, eastArea;
end
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- NEW LANDMASSES: ARCHIPELAGO (3), EAST VS WEST (4), RING (5)
-- All three are drawn on the west half only and then mirrored. They use the
-- game's own terrain, rivers, lakes and features (like Pangaea) and have no
-- strip down the middle.
------------------------------------------------------------------------------
mirror_islandOf = {};		-- GLOBAL (archipelago) west plot index -> island number
mirror_islands = {};		-- GLOBAL (archipelago) islands: {kind = "start"/"medium"/"small", plots = {...}}
mirror_startIslands = {};	-- GLOBAL (archipelago) island numbers of the start islands, west side
mirror_coastArgs = nil;		-- GLOBAL args for GenerateCoasts (archipelago: how far the shallow coast reaches)
mirror_neighbours = {};		-- cache: plot index -> neighbour indices
------------------------------------------------------------------------------
function MirrorNeighbours(i)
	local list = mirror_neighbours[i];
	if list ~= nil then return list end
	local iW, iH = Map.GetGridSize();
	list = {};
	local x, y = i % iW, math.floor(i / iW);
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
		local adj = Map.PlotDirection(x, y, direction);
		if adj ~= nil then
			table.insert(list, adj:GetY() * iW + adj:GetX());
		end
	end
	mirror_neighbours[i] = list;
	return list;
end
------------------------------------------------------------------------------
function MirrorPlannedSpots()
	-- How many start spots each side will get, without using the dice (the same
	-- answer MirrorPlanSides gives later): two teams = the bigger team; otherwise
	-- the bigger side of the most even split that keeps teams together.
	local iNumCivs, iNumCityStates, player_ID_list = GetPlayerAndTeamInfo();
	local sizes, index = {}, {};
	for loop, player_ID in ipairs(player_ID_list) do
		local team_ID = Players[player_ID]:GetTeam();
		if index[team_ID] == nil then
			table.insert(sizes, 0);
			index[team_ID] = table.maxn(sizes);
		end
		sizes[index[team_ID]] = sizes[index[team_ID]] + 1;
	end
	if table.maxn(sizes) == 2 then
		return math.max(sizes[1], sizes[2], 1);
	end
	local total = 0;
	for loop, size in ipairs(sizes) do total = total + size end
	local reached = {};
	reached[0] = true;
	for loop, size in ipairs(sizes) do
		for s = total - size, 0, -1 do
			if reached[s] then reached[s + size] = true end
		end
	end
	local best = 0;
	for s = math.floor(total / 2), 0, -1 do
		if reached[s] then best = s; break end
	end
	return math.max(total - best, 1);
end
------------------------------------------------------------------------------
function MirrorRelief(landList, hillShare, mountainShare, grain)
	-- Hills and mountains on the given land plots (west indices) from a fractal,
	-- like the game's own maps: the highest values become mountains, the next hills.
	if table.maxn(landList) == 0 then return end
	local iW, iH = Map.GetGridSize();
	local frac = Fractal.Create(iW, iH, grain or 4, Map.GetFractalFlags(), -1, -1);
	local values = {};
	for loop, i in ipairs(landList) do
		table.insert(values, {i = i, v = frac:GetHeight(i % iW, math.floor(i / iW)) * 1000 + loop});
	end
	table.sort(values, function(a, b) return a.v > b.v end);
	local n = table.maxn(values);
	local nMountains = math.floor(n * mountainShare + 0.5);
	local nHills = math.floor(n * hillShare + 0.5);
	for rank, entry in ipairs(values) do
		local plot = Map.GetPlotByIndex(entry.i);
		if rank <= nMountains then
			plot:SetPlotType(PlotTypes.PLOT_MOUNTAIN, false, false);
		elseif rank <= nMountains + nHills then
			plot:SetPlotType(PlotTypes.PLOT_HILLS, false, false);
		end
	end
end
------------------------------------------------------------------------------
function MirrorAgeShares()
	-- World age: hill and mountain shares of the land (old = flatter).
	local age = MirrorOpt("age", 2);
	if age == 4 then age = 1 + Map.Rand(3, "Mirror - random world age") end
	if age == 1 then return 0.22, 0.07 end
	if age == 3 then return 0.15, 0.03 end
	return 0.18, 0.05;
end
------------------------------------------------------------------------------
function MirrorAllOcean()
	local iW, iH = Map.GetGridSize();
	for i = 0, iW * iH - 1 do
		Map.GetPlotByIndex(i):SetPlotType(PlotTypes.PLOT_OCEAN, false, false);
	end
end
------------------------------------------------------------------------------
function MirrorKeepContinentFlags()
	local iW, iH = Map.GetGridSize();
	for i = 0, iW * iH - 1 do
		mirror_continent[i] = not Map.GetPlotByIndex(i):IsWater();
	end
end
------------------------------------------------------------------------------
-- ARCHIPELAGO
------------------------------------------------------------------------------
function MirrorArchipelagoAllowed(i)
	-- West plots that may become island land: off the map edges, off the poles,
	-- and at least a hex from the centre line (so no island touches its own twin).
	local iW, iH = Map.GetGridSize();
	local x, y = i % iW, math.floor(i / iW);
	return mirror_kind[i] == MIRROR_WEST and mirror_axisDist[i] >= 1.0
		and x >= 1 and y >= 2 and y <= iH - 3;
end
------------------------------------------------------------------------------
function MirrorPangaeaCoastIslands()
	-- Now and then (2 maps in 3) a few small islands of 1-4 tiles just off the
	-- coast of the continent, with 1-2 water tiles between, in mirror pairs.
	local iW, iH = Map.GetGridSize();
	if Map.Rand(3, "Mirror Pangaea - coast islands or not") == 0 then
		print("Mirror Skirmish: no coast islands this time");
		return
	end
	local wanted = 1 + Map.Rand(math.max(1, math.floor(iW / 20)), "Mirror Pangaea - coast island count");
	-- Water distance to the nearest land (up to 4).
	local dist, queue, head = {}, {}, 1;
	for i = 0, iW * iH - 1 do
		if not Map.GetPlotByIndex(i):IsWater() then
			dist[i] = 0;
			table.insert(queue, i);
		end
	end
	while head <= table.maxn(queue) do
		local c = queue[head];
		head = head + 1;
		if dist[c] < 4 then
			for loop, j in ipairs(MirrorNeighbours(c)) do
				if dist[j] == nil then
					dist[j] = dist[c] + 1;
					table.insert(queue, j);
				end
			end
		end
	end
	local blocked = {};	-- new island tiles and the water round them
	local function Usable(j)
		local x, y = j % iW, math.floor(j / iW);
		return mirror_kind[j] == MIRROR_WEST and not mirror_centre[j] and not blocked[j]
			and dist[j] ~= nil and dist[j] >= 2 and dist[j] <= 3
			and y >= math.floor(iH * 0.15) and y <= math.ceil(iH * 0.85)
			and MirrorTwinDistance(x, y) >= 5;	-- never touching its own mirror image
	end
	local seeds = {};
	for i = 0, iW * iH - 1 do
		if Usable(i) then table.insert(seeds, i) end
	end
	local placed, tries = 0, 0;
	while placed < wanted and tries < wanted * 12 and table.maxn(seeds) > 0 do
		tries = tries + 1;
		local seed = seeds[1 + Map.Rand(table.maxn(seeds), "Mirror Pangaea - coast island spot")];
		if Usable(seed) then
			local size = 1 + Map.Rand(4, "Mirror Pangaea - coast island size");
			local tiles = {seed};
			local inIsland = {[seed] = true};
			while table.maxn(tiles) < size do
				local cands = {};
				for loop, t in ipairs(tiles) do
					for loop2, nb in ipairs(MirrorNeighbours(t)) do
						if not inIsland[nb] and Usable(nb) then table.insert(cands, nb) end
					end
				end
				if table.maxn(cands) == 0 then break end
				local nb = cands[1 + Map.Rand(table.maxn(cands), "Mirror Pangaea - coast island shape")];
				inIsland[nb] = true;
				table.insert(tiles, nb);
			end
			for loop, t in ipairs(tiles) do
				local plotType = PlotTypes.PLOT_LAND;
				if Map.Rand(3, "Mirror Pangaea - coast island hill") == 0 then plotType = PlotTypes.PLOT_HILLS end
				Map.GetPlotByIndex(t):SetPlotType(plotType, false, false);
				blocked[t] = true;
				for loop2, nb in ipairs(MirrorNeighbours(t)) do blocked[nb] = true end
			end
			placed = placed + 1;
		end
	end
	MirrorWestToEast(true, false, false, false, false);
	print("Mirror Skirmish: coast islands per side:", placed);
end
------------------------------------------------------------------------------
function MirrorGrowIsland(id, seed, size, isLand, shape)
	-- Grows an island from a seed plot, one tile at a time. No tile may touch
	-- another island, so every island stays its own landmass. Shapes:
	--   "round"   prefers tiles with many island neighbours (compact blobs)
	--   "uniform" mild preference (irregular but solid)
	--   "stringy" prefers tiles touching the island on one side only (long, thin, branching)
	shape = shape or "round";
	local function CanUse(j)
		if isLand[j] or not MirrorArchipelagoAllowed(j) then return false end
		for loop, nb in ipairs(MirrorNeighbours(j)) do
			if isLand[nb] and mirror_islandOf[nb] ~= id then return false end
		end
		return true
	end
	if not CanUse(seed) then return nil end
	local tiles, inIsland = {}, {};
	local function Add(j)
		table.insert(tiles, j);
		inIsland[j] = true;
		isLand[j] = true;
		mirror_islandOf[j] = id;
	end
	Add(seed);
	while table.maxn(tiles) < size do
		local cands, weights, total = {}, {}, 0;
		local seen = {};
		for loop, t in ipairs(tiles) do
			for loop2, nb in ipairs(MirrorNeighbours(t)) do
				if not seen[nb] and not inIsland[nb] and CanUse(nb) then
					seen[nb] = true;
					local touching = 0;
					for loop3, nb2 in ipairs(MirrorNeighbours(nb)) do
						if inIsland[nb2] then touching = touching + 1 end
					end
					local w = touching * touching;
					if shape == "uniform" then
						w = touching + 1;
					elseif shape == "stringy" then
						if touching == 1 then w = 10 elseif touching == 2 then w = 1 else w = 0 end
					end
					table.insert(cands, nb);
					table.insert(weights, w);
					total = total + w;
				end
			end
		end
		if total == 0 then
			-- (stringy with no thin tile left: take any free neighbour)
			for n = 1, table.maxn(weights) do weights[n] = 1 end
			total = table.maxn(weights);
		end
		if total == 0 then break end
		local roll = Map.Rand(total, "Mirror Archipelago - island shape");
		for n, w in ipairs(weights) do
			if roll < w then Add(cands[n]); break end
			roll = roll - w;
		end
	end
	return tiles;
end
------------------------------------------------------------------------------
function MirrorUpdateDistToLand(dist, tiles, range)
	-- Distance to the nearest land, kept up to date as islands are added (capped at range).
	local iW, iH = Map.GetGridSize();
	for loop, t in ipairs(tiles) do
		local tx, ty = t % iW, math.floor(t / iW);
		for dy = -range, range do
			for dx = -range - 1, range + 1 do
				local x, y = tx + dx, ty + dy;
				if x >= 0 and x < iW and y >= 0 and y < iH then
					local d = Map.PlotDistance(tx, ty, x, y);
					local j = y * iW + x;
					if d <= range and d < dist[j] then dist[j] = d end
				end
			end
		end
	end
end
------------------------------------------------------------------------------
function MirrorArchipelagoSettings()
	-- All archipelago knobs in one place (lobby options -> numbers).
	local o = {};
	local startOpt = MirrorOpt("startisland", 3);
	o.startMin, o.startMax = 20, 40;
	if startOpt == 1 then o.startMin, o.startMax = 10, 15 elseif startOpt == 2 then o.startMin, o.startMax = 15, 25 elseif startOpt == 4 then o.startMin, o.startMax = 30, 50 end
	local expOpt = MirrorOpt("expansion", 2);
	o.expansionPerPlayer = ({0.5, 1, 2, 0})[expOpt] or 1;
	o.ownPerPlayer = ({0, 1, 2})[MirrorOpt("ownexpansion", 2)] or 1;	-- own expansion islands per start island
	local islandsOpt = MirrorOpt("islands", 2);
	o.otherShare = ({0.08, 0.13, 0.18})[islandsOpt] or 0.13;
	local gapOpt = MirrorOpt("gaps", 2);
	o.gapTarget = ({2, 3, 5})[gapOpt] or 3;		-- preferred water distance to the nearest island
	o.fillDist = ({4, 4, 6})[gapOpt] or 4;		-- stepping stones wherever water is this far from any land
	local landOpt = MirrorOpt("landamount", 4);
	o.otherShare = o.otherShare * (({1.25, 1.5, 2.1, 2.6})[landOpt] or 1.25);
	-- Map size Normal (user 11-15): the extra room is open ocean, not more islands - the same
	-- island land as Compact (Compact is 0.87 x 0.87 of the tiles).
	if MIRROR_VARIANT == "archipelago" and MirrorOpt("mapsize", 2) == 1 then o.otherShare = o.otherShare * 0.757 end
	o.fillDist = math.max(3, o.fillDist + (({0, 0, 0, -1})[landOpt] or 0));
	if landOpt == 3 then o.fillDist = math.min(o.fillDist, 4) end
	local shapeOpt = MirrorOpt("shapes", 1);
	o.shapes = ({{"round", "uniform", "stringy"}, {"round", "uniform"}, {"stringy", "uniform"}})[shapeOpt] or {"round", "uniform", "stringy"};
	local hillOpt = MirrorOpt("hills", 2);
	o.hillChance = ({20, 30, 42, 56, 76, 90})[hillOpt] or 30;
	local oceanOpt = MirrorOpt("ocean", 3);
	o.oceanShare = ({0.05, 0.15, 0.25, 0.35, 0.45})[oceanOpt] or 0.25;
	local resOpt = MirrorOpt("density", 4);						-- land resources 1-6 (2 = the old default)
	o.landBonus = ({0.04, 0.08, 0.12, 0.16, 0.20, 0.25})[resOpt] or 0.16;	-- chance per free land tile outside capitals
	o.capitalBonus = ({2, 3, 3, 4, 4, 5})[resOpt] or 4;				-- land bonus within 3 tiles of every capital
	local seaOpt = MirrorOpt("seaamount", 3);						-- sea resources 1-6 (2 = the old default)
	o.coastPerFish = ({8, 6, 5, 4, 3.75, 3.5, 3})[seaOpt] or 5;			-- island coast tiles per Fish
	o.capitalFish = ({1, 2, 2, 3, 3, 3, 3})[seaOpt] or 2;	-- the capital food cap decides the final split (Fish at most 3)				-- Fish within 3 tiles of every capital
	o.seaMode = MirrorOpt("searesources", 1);					-- 1 even, 2 varied
	o.coastLux = MirrorOpt("coastlux", 2);						-- 1 game's, 2 more, 3 lots
	o.atolls = MirrorOpt("atolls", 2);							-- 1 game's, 2 more, 3 lots
	return o;
end
------------------------------------------------------------------------------
function MirrorGenerateArchipelagoPlotTypes()
	local iW, iH = Map.GetGridSize();
	MirrorAllOcean();
	mirror_islandOf, mirror_islands, mirror_startIslands = {}, {}, {};
	mirror_ownExpansionCount = 0;
	local o = MirrorArchipelagoSettings();
	local isLand, dist = {}, {};
	local allowed = {};
	for i = 0, iW * iH - 1 do
		dist[i] = 99;
		if MirrorArchipelagoAllowed(i) then table.insert(allowed, i) end
	end
	local nAllowed = table.maxn(allowed);
	local function ExpansionSize()
		-- Big islands anywhere on the map (user): 40 in 100 of 20-30 tiles, 60 of 10-20.
		local roll = Map.Rand(100, "Mirror Archipelago - expansion island kind");
		if roll < 40 then return 20 + Map.Rand(11, "Mirror Archipelago - expansion island size") end
		return 10 + Map.Rand(11, "Mirror Archipelago - expansion island size");
	end
	local function PickShape(list)
		return list[1 + Map.Rand(table.maxn(list), "Mirror Archipelago - island shape kind")];
	end

	-- Start islands: one per spot, spread out (far from each other, from each
	-- other's mirror images, from their own mirror image and from the map edges),
	-- in the middle rows. Round or uniform, never stringy.
	local k = MirrorPlannedSpots();
	local seeds = {};
	for n = 1, k do
		local best, bestScore = -1, -1;
		for attempt = 1, 400 do
			local i = allowed[1 + Map.Rand(nAllowed, "Mirror Archipelago - start island spot")];
			local x, y = i % iW, math.floor(i / iW);
			local edge = math.min(y, iH - 1 - y);
			if not mirror_wrap then edge = math.min(edge, x) end
			local score = math.min(MirrorTwinDistance(x, y), 3 * edge);
			for loop, s in ipairs(seeds) do
				local sx, sy = s % iW, math.floor(s / iW);
				score = math.min(score, Map.PlotDistance(x, y, sx, sy));
				local tsx = MirrorTwinX(sx, sy);
				if tsx ~= nil then score = math.min(score, Map.PlotDistance(x, y, tsx, sy)) end
			end
			local bTemperate = (y >= math.floor(iH * 0.28) and y <= math.ceil(iH * 0.72) - 1);
			if bTemperate and score > bestScore and dist[i] >= 3 then best, bestScore = i, score end
		end
		if best >= 0 then table.insert(seeds, best) end
	end
	-- One size for this game (in the chosen range); every start island is that size +-2 tiles.
	local startBase = o.startMin + Map.Rand(o.startMax - o.startMin + 1, "Mirror Archipelago - start island base size");
	for n, seed in ipairs(seeds) do
		local id = table.maxn(mirror_islands) + 1;
		local size = math.max(o.startMin, math.min(o.startMax, startBase - 2 + Map.Rand(5, "Mirror Archipelago - start island size")));
		local tiles = MirrorGrowIsland(id, seed, size, isLand, PickShape({"round", "uniform"}));
		if tiles ~= nil then
			mirror_islands[id] = {kind = "start", plots = tiles};
			table.insert(mirror_startIslands, id);
			MirrorUpdateDistToLand(dist, tiles, 8);
		end
	end
	print("Mirror Archipelago: start islands", table.maxn(mirror_startIslands), "for", k, "spots, size", o.startMin, "-", o.startMax);

	-- A seed for the next island: preferably the chosen water distance from the
	-- nearest land (2 = tight clusters, 5 = spread out), with a little noise.
	local function PickSeed(minDist, bTemperate, target)
		target = target or o.gapTarget;
		local best, bestScore = -1, -99999;
		-- Now and then an island starts a new group in the most open water, so the
		-- clusters cover the whole map instead of leaving empty oceans.
		local bNewGroup = (o.gapTarget < 5 and Map.Rand(100, "Mirror Archipelago - new island group") < 35);
		for attempt = 1, 40 do
			local i = allowed[1 + Map.Rand(nAllowed, "Mirror Archipelago - island spot")];
			local y = math.floor(i / iW);
			local okRow = not bTemperate or (y >= math.floor(iH * 0.18) and y <= math.ceil(iH * 0.82));
			if dist[i] >= minDist and okRow then
				local score = -math.abs(math.min(dist[i], 8) - target) * 10 + Map.Rand(12, "Mirror Archipelago - island spot jitter");
				if bNewGroup then score = math.min(dist[i], 8) * 10 + Map.Rand(12, "Mirror Archipelago - island spot jitter") end
				if score > bestScore then best, bestScore = i, score end
			end
		end
		return best;
	end
	local land = 0;
	for i, flag in pairs(isLand) do land = land + 1 end
	local startLand = land;

	-- Own expansion islands (as KEK Large Islands): every start island gets the
	-- same number of MIRROR_OWN_EXPANSION_SIZE-tile islands, 3-5 tiles of water off
	-- its own coast and closer to it than to any other start island or mirror
	-- image of one. A round where any start island gets none is undone for all.
	if o.ownPerPlayer > 0 and table.maxn(mirror_startIslands) > 0 then
		local function Steps(sources, maxD)
			local d, queue, head = {}, {}, 1;
			for loop, s in ipairs(sources) do
				if d[s] == nil then d[s] = 0; table.insert(queue, s); end
			end
			while head <= table.maxn(queue) do
				local i = queue[head];
				head = head + 1;
				if d[i] < maxD then
					for loop, nb in ipairs(MirrorNeighbours(i)) do
						if d[nb] == nil then d[nb] = d[i] + 1; table.insert(queue, nb); end
					end
				end
			end
			return d;
		end
		local distOwn, distOther = {}, {};
		for r, id in ipairs(mirror_startIslands) do
			distOwn[r] = Steps(mirror_islands[id].plots, 7);
			local others = {};
			for r2, id2 in ipairs(mirror_startIslands) do
				for loop, t in ipairs(mirror_islands[id2].plots) do
					if r2 ~= r then table.insert(others, t) end
					if mirror_twin[t] ~= nil and mirror_twin[t] >= 0 then table.insert(others, mirror_twin[t]) end
				end
			end
			distOther[r] = Steps(others, 8);
		end
		for round = 1, o.ownPerPlayer do
			local made, ok = {}, true;
			for r, id in ipairs(mirror_startIslands) do
				local cands = {};
				for loop, i in ipairs(allowed) do
					local d = distOwn[r][i];
					if d ~= nil and d >= 4 and d <= 6 and dist[i] >= 3 and not isLand[i]
						and (distOther[r][i] == nil or distOther[r][i] > d + 1) then
						table.insert(cands, i);
					end
				end
				local tiles = nil;
				for try = 1, 12 do
					if table.maxn(cands) == 0 then break end
					local seed = table.remove(cands, 1 + Map.Rand(table.maxn(cands), "Mirror Archipelago - own expansion spot"));
					local newId = table.maxn(mirror_islands) + table.maxn(made) + 1;
					tiles = MirrorGrowIsland(newId, seed, MIRROR_OWN_EXPANSION_SIZE, isLand, "round");
					if tiles ~= nil and table.maxn(tiles) < MIRROR_OWN_EXPANSION_SIZE then
						for loop, j in ipairs(tiles) do isLand[j] = nil; mirror_islandOf[j] = nil end
						tiles = nil;
					end
					if tiles ~= nil then break end
				end
				if tiles == nil then ok = false; break end
				table.insert(made, tiles);
			end
			if not ok then
				for loop, tiles in ipairs(made) do
					for loop2, j in ipairs(tiles) do isLand[j] = nil; mirror_islandOf[j] = nil end
				end
				break
			end
			for loop, tiles in ipairs(made) do
				local id = table.maxn(mirror_islands) + 1;
				for loop2, j in ipairs(tiles) do mirror_islandOf[j] = id end
				mirror_islands[id] = {kind = "own", plots = tiles};
				MirrorUpdateDistToLand(dist, tiles, 8);
				land = land + table.maxn(tiles);
			end
			mirror_ownExpansionCount = round;
		end
		print("Mirror Archipelago: own expansion islands per player", mirror_ownExpansionCount, "of", o.ownPerPlayer);
	end

	-- Expansion islands sit between two capitals (about as far from both), not
	-- next to one: shared, contested land instead of a private backyard.
	local capitalSeeds = {};
	for loop, id in ipairs(mirror_startIslands) do
		local c = mirror_islands[id].plots[1];
		table.insert(capitalSeeds, {c % iW, math.floor(c / iW)});
		if mirror_twin[c] ~= nil and mirror_twin[c] >= 0 then
			local t = mirror_twin[c];
			table.insert(capitalSeeds, {t % iW, math.floor(t / iW)});
		end
	end
	local function PickContestedSeed()
		local best, bestScore = -1, -99999;
		for attempt = 1, 60 do
			local i = allowed[1 + Map.Rand(nAllowed, "Mirror Archipelago - expansion island spot")];
			local x, y = i % iW, math.floor(i / iW);
			local okRow = (y >= math.floor(iH * 0.18) and y <= math.ceil(iH * 0.82));
			if dist[i] >= 3 and okRow then
				local d1, d2 = 999, 999;
				for loop, c in ipairs(capitalSeeds) do
					local d = Map.PlotDistance(x, y, c[1], c[2]);
					if d < d1 then d1, d2 = d, d1 elseif d < d2 then d2 = d end
				end
				if d1 >= 6 then
					local score = -(d2 - d1) * 10 - math.abs(math.min(dist[i], 8) - 4) * 4 + Map.Rand(12, "Mirror Archipelago - expansion spot jitter");
					if score > bestScore then best, bestScore = i, score end
				end
			end
		end
		return best;
	end
	-- Expansion islands of 20-30 tiles.
	local nExpansion = math.floor(k * o.expansionPerPlayer + 0.5);
	for n = 1, nExpansion do
		local seed = PickSeed(3, true);	-- anywhere, not between two capitals (user)
		if seed >= 0 then
			local id = table.maxn(mirror_islands) + 1;
			local tiles = MirrorGrowIsland(id, seed, ExpansionSize(), isLand, PickShape(o.shapes));
			if tiles ~= nil then
				local kind = "expansion";
				if table.maxn(tiles) < 5 then kind = "small" elseif table.maxn(tiles) < 10 then kind = "medium" end
				mirror_islands[id] = {kind = kind, plots = tiles};
				MirrorUpdateDistToLand(dist, tiles, 8);
				land = land + table.maxn(tiles);
			end
		end
	end

	-- Other islands until the land share is reached: 3 medium (5-10 tiles) to every small one (1-3).
	local target = land + math.floor(nAllowed * o.otherShare);
	local failures = 0;
	while land < target and failures < 60 do
		local kind, size = "small", 1 + Map.Rand(3, "Mirror Archipelago - small island size");
		if Map.Rand(4, "Mirror Archipelago - island kind") < 3 then
			kind, size = "medium", 5 + Map.Rand(6, "Mirror Archipelago - medium island size");
			-- varied sizes over the map (user): some of 10-15 and 15-20 as well
			local roll = Map.Rand(100, "Mirror Archipelago - bigger island roll");
			if roll < 25 then size = 10 + Map.Rand(6, "Mirror Archipelago - island size 10-15")
			elseif roll < 40 then size = 15 + Map.Rand(6, "Mirror Archipelago - island size 15-20") end
		end
		local seed = PickSeed(2, false);
		local tiles = nil;
		if seed >= 0 then
			local id = table.maxn(mirror_islands) + 1;
			local shape = "round";
			if kind == "medium" then shape = PickShape(o.shapes) end
			tiles = MirrorGrowIsland(id, seed, size, isLand, shape);
			if tiles ~= nil then
				if kind == "medium" and table.maxn(tiles) < 5 then kind = "small" end
				mirror_islands[id] = {kind = kind, plots = tiles};
				MirrorUpdateDistToLand(dist, tiles, 8);
				land = land + table.maxn(tiles);
			end
		end
		if tiles == nil then failures = failures + 1 else failures = 0 end
	end

	-- Stepping stones: small islands wherever open water would otherwise stay
	-- wider than about 3 tiles, so the islands join up into one sea of land
	-- with no clear borders between the players.
	local stoneFails = 0;
	while stoneFails < 40 do
		local open = {};
		for loop, i in ipairs(allowed) do
			local y = math.floor(i / iW);
			if dist[i] >= o.fillDist and y >= math.floor(iH * 0.12) and y <= math.ceil(iH * 0.88) then
				table.insert(open, i);
			end
		end
		if table.maxn(open) == 0 then break end
		local seed = open[1 + Map.Rand(table.maxn(open), "Mirror Archipelago - stepping stone spot")];
		local id = table.maxn(mirror_islands) + 1;
		local stoneSizes = {1, 1, 2, 2, 3, 3, 4, 5, 6, 7, 8, 10, 12};	-- varied, more small than big
		local size = stoneSizes[1 + Map.Rand(table.maxn(stoneSizes), "Mirror Archipelago - stepping stone size")];
		local tiles = MirrorGrowIsland(id, seed, size, isLand, PickShape(o.shapes));
		if tiles == nil then
			stoneFails = stoneFails + 1;
		else
			local kind = "medium";
			if table.maxn(tiles) < 5 then kind = "small" end
			mirror_islands[id] = {kind = kind, plots = tiles};
			MirrorUpdateDistToLand(dist, tiles, 8);
			land = land + table.maxn(tiles);
		end
	end
	-- Hills (option) and a few mountains on the bigger islands, none on start islands.
	-- The thinner the island (share of its tiles with 3+ water neighbours), the
	-- more hills (and later Fish): round about 0.75x the option, stringy up to 1.3x.
	local anyLand = {};
	for id, island in ipairs(mirror_islands) do
		for loop, i in ipairs(island.plots) do anyLand[i] = true end
	end
	for id, island in ipairs(mirror_islands) do
		local thinTiles = 0;
		for loop, i in ipairs(island.plots) do
			local water = 0;
			for loop2, nb in ipairs(MirrorNeighbours(i)) do
				if not anyLand[nb] then water = water + 1 end
			end
			if water >= 3 then thinTiles = thinTiles + 1 end
		end
		island.thin = thinTiles / math.max(1, table.maxn(island.plots));
	end
	local startMountain = (Map.Rand(2, "Mirror Archipelago - start island mountain") == 0);
	for id, island in ipairs(mirror_islands) do
		local n = table.maxn(island.plots);
		if island.kind == "own" then
			-- own expansion islands: exactly the same number of hills on each, no mountains
			local hills = math.floor(n * o.hillChance / 100 + 0.5);
			local order = {};
			for loop, i in ipairs(island.plots) do table.insert(order, i) end
			for loop, i in ipairs(island.plots) do
				Map.GetPlotByIndex(i):SetPlotType(PlotTypes.PLOT_LAND, false, false);
			end
			for h = 1, math.min(hills, n) do
				local i = table.remove(order, 1 + Map.Rand(table.maxn(order), "Mirror Archipelago - own expansion hill"));
				Map.GetPlotByIndex(i):SetPlotType(PlotTypes.PLOT_HILLS, false, false);
			end
		else
		for loop, i in ipairs(island.plots) do
			local plotType = PlotTypes.PLOT_LAND;
			local hillChance = math.min(97, math.floor(o.hillChance * (0.5 + 0.8 * island.thin) + 0.5));
			if Map.Rand(100, "Mirror Archipelago - hills") < hillChance then plotType = PlotTypes.PLOT_HILLS end
			Map.GetPlotByIndex(i):SetPlotType(plotType, false, false);
		end
		end
		if island.kind ~= "start" and island.kind ~= "small" and island.kind ~= "own" and n >= 7 then
			local mountains = 0;
			if Map.Rand(100, "Mirror Archipelago - mountain") < 35 then mountains = 1 end
			if island.kind == "expansion" then mountains = 1 + Map.Rand(2, "Mirror Archipelago - mountains") end
			for m = 1, mountains do
				local i = island.plots[1 + Map.Rand(n, "Mirror Archipelago - mountain spot")];
				Map.GetPlotByIndex(i):SetPlotType(PlotTypes.PLOT_MOUNTAIN, false, false);
			end
		end
		-- Now and then (1 game in 2) every start island gets one mountain, inland
		-- when possible (user: Machu Picchu needs one). The same for everybody.
		if island.kind == "start" and startMountain and n >= 10 then
			local own, inland = {}, {};
			for loop, t in ipairs(island.plots) do own[t] = true end
			for loop, t in ipairs(island.plots) do
				local all = true;
				for loop2, j2 in ipairs(MirrorNeighbours(t)) do
					if not own[j2] then all = false end
				end
				if all then table.insert(inland, t) end
			end
			local list = island.plots;
			if table.maxn(inland) > 0 then list = inland end
			local t = list[1 + Map.Rand(table.maxn(list), "Mirror Archipelago - start island mountain spot")];
			Map.GetPlotByIndex(t):SetPlotType(PlotTypes.PLOT_MOUNTAIN, false, false);
		end
	end
	-- Speed vs scaling (user, 11-14): bigger free islands get fresh water, a
	-- lake tile inside (1 from 15 tiles, 2 from 28); start islands never.
	for id, island in ipairs(mirror_islands) do
		local n = table.maxn(island.plots);
		if island.kind ~= "start" and island.kind ~= "own" and n >= 15 then
			local own = {};
			for loop, t in ipairs(island.plots) do own[t] = true end
			local inland = {};
			for loop, t in ipairs(island.plots) do
				local all = true;
				for loop2, j2 in ipairs(MirrorNeighbours(t)) do if not own[j2] then all = false end end
				if all and not Map.GetPlotByIndex(t):IsMountain() then table.insert(inland, t) end
			end
			local want = 1;
			if n >= 28 then want = 2 end
			local made = {};
			while table.maxn(made) < want and table.maxn(inland) > 0 do
				local t = table.remove(inland, 1 + Map.Rand(table.maxn(inland), "Mirror Archipelago - island lake"));
				local far = true;
				for loop, m in ipairs(made) do
					if Map.PlotDistance(t % iW, math.floor(t / iW), m % iW, math.floor(m / iW)) < 3 then far = false end
				end
				if far then
					Map.GetPlotByIndex(t):SetPlotType(PlotTypes.PLOT_OCEAN, false, false);
					own[t] = nil;
					mirror_islandOf[t] = nil;
					table.insert(made, t);
				end
			end
			if table.maxn(made) > 0 then
				local keep = {};
				for loop, t in ipairs(island.plots) do if own[t] then table.insert(keep, t) end end
				island.plots = keep;
			end
		end
	end
	print("Mirror Archipelago: islands", table.maxn(mirror_islands), "land", land, "(start", startLand, ") of", nAllowed);
	MirrorWestToEast(true, false, false, false, false);
	MirrorKeepContinentFlags();
end
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- EAST VS WEST: the game's West_vs_East.lua land, mirrored
-- All land, a channel of water down the middle (narrower in the middle rows),
-- lakes from a fractal, hills and mountains from the game's tectonics, no ice.
------------------------------------------------------------------------------
function MirrorGenerateEastWestPlotTypes()
	local iW, iH = Map.GetGridSize();
	local layered = MultilayeredFractal.Create();
	layered.wholeworldPlotTypes = table.fill(PlotTypes.PLOT_LAND, iW * iH);
	-- The channel: the game makes it 4 columns wide (2 in the four middle rows).
	-- Mirrored that is 4/3 tiles wide on even/odd rows (2/1 in the middle rows).
	local wide = (MirrorOpt("gap", 1) == 2);
	local half, midHalf = 1.5, 0.5;
	if wide then half, midHalf = 2.5, 1.5 end
	local mid = math.floor(iH / 2);
	for i = 0, iW * iH - 1 do
		local y = math.floor(i / iW);
		local limit = half;
		if y >= mid - 2 and y <= mid + 1 then limit = midHalf end
		if mirror_axisDist[i] <= limit + 0.0001 then
			layered.wholeworldPlotTypes[i + 1] = PlotTypes.PLOT_OCEAN;
		end
	end
	-- Lakes (the game's 8% of the map).
	local lakesFrac = Fractal.Create(iW, iH, 3, {}, 6, 6);
	local iLakesThreshold = lakesFrac:GetHeight(92);
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			if lakesFrac:GetHeight(x, y) >= iLakesThreshold then
				layered.wholeworldPlotTypes[y * iW + x + 1] = PlotTypes.PLOT_OCEAN;
			end
		end
	end
	local world_age = MirrorOpt("age", 2);
	if world_age == 4 then
		world_age = 1 + Map.Rand(3, "Random World Age - Lua");
	end
	layered:ApplyTectonics({world_age = world_age});
	SetPlotTypes(layered.wholeworldPlotTypes);
	MirrorWestToEast(true, false, false, false, false);
	MirrorKeepContinentFlags();
	mirror_coastArgs = {bExpandCoasts = false};
end
------------------------------------------------------------------------------
-- RING: the game's Ring.lua land, mirrored
-- A loop of land (the "isthmus") joins one fractal sub-continent per player;
-- a polar island sits in the middle (city states live there).
------------------------------------------------------------------------------
mirror_ringCentre = nil;	-- GLOBAL {westX, eastX, southY, northY} of the polar centre (made symmetric)
mirror_ringCentreOnly = false;
function MirrorRingPlotsByRegion(self)
	dominant_terrain = MirrorOpt("ringterrain", 5) -- GLOBAL variable, as in Ring.lua.
	if dominant_terrain == 5 then -- Random
		dominant_terrain = 1 + Map.Rand(4, "Random Type of Dominant Terrain - Ring LUA");
	end
	local landmass_type = MirrorOpt("ringshape", 4);
	if landmass_type == 4 then
		landmass_type = 1 + Map.Rand(3, "Landmass Type - Lua");
	end
	local bridge_width = MirrorOpt("isthmus", 2)
	if bridge_width == 4 then -- Random
		bridge_width = 2 + Map.Rand(3, "Random Bridge Width - Ring LUA");
	else
		bridge_width = bridge_width + 1;
	end
	local ring_corners = {
		{},
		{{0.167, 0.3}, {0.167, 0.7}, {0.833, 0.7}, {0.833, 0.3}, {0.167, 0.3}}, -- 2 civs
		{{0.125, 0.125}, {0.125, 0.875}, {0.875, 0.875}, {0.875, 0.125}, {0.125, 0.125}},
		{{0.167, 0.167}, {0.167, 0.833}, {0.833, 0.833}, {0.833, 0.167}, {0.167, 0.167}},
		{{0.125, 0.167}, {0.125, 0.833}, {0.875, 0.833}, {0.875, 0.167}, {0.125, 0.167}}, -- 5 civs
		{{0.1, 0.167}, {0.1, 0.833}, {0.9, 0.833}, {0.9, 0.167}, {0.1, 0.167}},
		{{0.1, 0.125}, {0.1, 0.875}, {0.9, 0.875}, {0.9, 0.125}, {0.1, 0.125}},
		{{0.167, 0.167}, {0.167, 0.833}, {0.833, 0.833}, {0.833, 0.167}, {0.167, 0.167}},
		{{0.083, 0.1}, {0.083, 0.9}, {0.917, 0.9}, {0.917, 0.1}, {0.083, 0.1}},
		{{0.083, 0.083}, {0.083, 0.917}, {0.917, 0.917}, {0.917, 0.083}, {0.083, 0.083}}, -- 10 civs
		{{0.1, 0.167}, {0.1, 0.833}, {0.9, 0.833}, {0.9, 0.167}, {0.1, 0.167}},
		{{0.1, 0.167}, {0.1, 0.833}, {0.9, 0.833}, {0.9, 0.167}, {0.1, 0.167}},
	};
	-- Mirror: the land is laid out for the number of start spots on both sides
	-- (always even), not for the players in the lobby.
	local iNumCivs = math.max(2, math.min(12, 2 * MirrorPlannedSpots()));
	local ring_coords = ring_corners[iNumCivs];
	local iW, iH = Map.GetGridSize()
	local offsetstart = 0 - math.floor(bridge_width / 2);
	for ring_loop = 1, 4 do
		local start_coords, end_coords = ring_coords[ring_loop], ring_coords[ring_loop + 1];
		local startx = math.floor(start_coords[1] * iW);
		local starty = math.floor(start_coords[2] * iH);
		local endx = math.floor(end_coords[1] * iW);
		local endy = math.floor(end_coords[2] * iH);
		if math.abs(endy-starty) < math.abs(endx-startx) then
			if startx > endx then
				startx, starty, endx, endy = endx, endy, startx, starty;
			end
			local y = starty;
			for x = startx, endx do
				for offset = offsetstart, offsetstart + bridge_width - 1 do
					if Map.GetPlot(x, y + offset) ~= nil then
						self.wholeworldPlotTypes[(y + offset) * iW + x + 1] = PlotTypes.PLOT_LAND;
					end
				end
			end
		else
			if starty > endy then
				startx, starty, endx, endy = endx, endy, startx, starty;
			end
			local x = startx;
			for y = starty, endy do
				for offset = offsetstart, offsetstart + bridge_width - 1 do
					if Map.GetPlot(x + offset, y) ~= nil then
						self.wholeworldPlotTypes[y * iW + (x + offset) + 1] = PlotTypes.PLOT_LAND;
					end
				end
			end
		end
	end
	local center_isle_data = {
		{},
		{0.4, 0.6, 0.4, 0.6},
		{0.4, 0.7, 0.35, 0.65},
		{0.4, 0.6, 0.4, 0.6},
		{0.32, 0.68, 0.4, 0.6},
		{0.3, 0.7, 0.4, 0.6},
		{0.3, 0.7, 0.37, 0.63},
		{0.4, 0.6, 0.4, 0.6},
		{0.3, 0.7, 0.37, 0.63},
		{0.3, 0.7, 0.33, 0.67},
		{0.3, 0.7, 0.4, 0.6},
		{0.3, 0.7, 0.4, 0.6},
	};
	local center_isle = center_isle_data[iNumCivs];
	centWestX = math.floor(iW * center_isle[1]); -- GLOBALS, as in Ring.lua
	centEastX = iW - 1 - centWestX;              -- (mirror: symmetric about the centre line)
	local centWidth = centEastX - centWestX + 1;
	centSouthY = math.floor(iH * center_isle[3]);
	centNorthY = math.floor(iH * center_isle[4]) - 1;
	local centHeight = centNorthY - centSouthY + 1;
	mirror_ringCentre = {centWestX, centEastX, centSouthY, centNorthY};
	local args = {};
	args.iWaterPercent = 65;
	args.iRegionWidth = centWidth;
	args.iRegionHeight = centHeight;
	args.iRegionWestX = centWestX;
	args.iRegionSouthY = centSouthY;
	args.iRegionGrain = 4 - landmass_type;
	args.iRegionHillsGrain = 3;
	args.iRegionPlotFlags = self.iHorzFlags;
	self:GenerateFractalLayer(args)
	local templates = {
		{},
		{{0.0, 0.333, 0.0, 1.0}, {0.667, 1.0, 0.0, 1.0}},
		{{0.0, 0.25, 0.25, 0.75}, {0.5, 1.0, 0.75, 1.0}, {0.5, 1.0, 0.0, 0.25}},
		{{0.0, 0.333, 0.333, 0.667}, {0.333, 0.667, 0.667, 1.0}, {0.667, 1.0, 0.333, 0.667}, {0.333, 0.667, 0.0, 0.333}},
		{{0.0, 0.25, 0.333, 1.0}, {0.25, 0.75, 0.667, 1.0}, {0.75, 1.0, 0.333, 1.0}, {0.5, 1.0, 0.0, 0.333}, {0.0, 0.5, 0.0, 0.333}},
		{{0.0, 0.4, 0.667, 1.0}, {0.4, 0.8, 0.667, 1.0}, {0.8, 1.0, 0.333, 1.0}, {0.6, 1.0, 0.0, 0.333}, {0.2, 0.6, 0.0, 0.333}, {0.0, 0.2, 0.0, 0.667}},
		{{0.0, 0.4, 0.75, 1.0}, {0.4, 0.8, 0.75, 1.0}, {0.8, 1.0, 0.5, 1.0}, {0.8, 1.0, 0.0, 0.5}, {0.4, 0.8, 0.0, 0.25}, {0.0, 0.4, 0.0, 0.25}, {0.0, 0.2, 0.25, 0.75}},
		{{0.0, 0.3, 0.35, 0.65}, {0.0, 0.3, 0.7, 1.0}, {0.35, 0.65, 0.7, 1.0}, {0.7, 1.0, 0.7, 1.0}, {0.7, 1.0, 0.35, 0.65}, {0.7, 1.0, 0.0, 0.3}, {0.35, 0.65, 0.0, 0.3}, {0.0, 0.3, 0.0, 0.3}},
		{{0.0, 0.167, 0.6, 1.0}, {0.167, 0.5, 0.8, 1.0}, {0.5, 0.833, 0.8, 1.0}, {0.833, 1.0, 0.6, 1.0}, {0.833, 1.0, 0.2, 0.6}, {0.667, 1.0, 0.0, 0.2}, {0.333, 0.667, 0.0, 0.2}, {0.0, 0.333, 0.0, 0.2}, {0.0, 0.167, 0.2, 0.6}},
		{{0.0, 0.167, 0.5, 0.833}, {0.0, 0.333, 0.833, 1.0}, {0.333, 0.667, 0.833, 1.0}, {0.667, 1.0, 0.833, 1.0}, {0.833, 1.0, 0.5, 0.833}, {0.833, 1.0, 0.167, 0.5}, {0.667, 1.0, 0.0, 0.167}, {0.333, 0.667, 0.0, 0.167}, {0.0, 0.333, 0.0, 0.167}, {0.0, 0.167, 0.167, 0.5}},
		{{0.0, 0.2, 0.167, 0.5}, {0.0, 0.2, 0.5, 0.833}, {0.2, 0.4, 0.667, 1.0}, {0.4, 0.6, 0.667, 1.0}, {0.6, 0.8, 0.667, 1.0}, {0.8, 1.0, 0.667, 1.0}, {0.8, 1.0, 0.333, 0.667}, {0.8, 1.0, 0.0, 0.333}, {0.6, 0.8, 0.0, 0.333}, {0.4, 0.6, 0.0, 0.333}, {0.2, 0.4, 0.0, 0.333}},
		{{0.0, 0.2, 0.333, 0.667}, {0.0, 0.2, 0.667, 1.0}, {0.2, 0.4, 0.667, 1.0}, {0.4, 0.6, 0.667, 1.0}, {0.6, 0.8, 0.667, 1.0}, {0.8, 1.0, 0.667, 1.0}, {0.8, 1.0, 0.333, 0.667}, {0.8, 1.0, 0.0, 0.333}, {0.6, 0.8, 0.0, 0.333}, {0.4, 0.6, 0.0, 0.333}, {0.2, 0.4, 0.0, 0.333}, {0.0, 0.2, 0.0, 0.333}},
	};
	local template_data = templates[iNumCivs];
	for region_loop = 1, iNumCivs do
		local region_template = template_data[region_loop];
		local iWestX = math.max(1, math.floor((iW - 1) * region_template[1]));
		local iEastX = math.min(iW - 2, math.floor((iW - 1) * region_template[2] - 1));
		local iSouthY = math.max(1, math.floor((iH - 1) * region_template[3]));
		local iNorthY = math.min(iH - 2, math.floor((iH - 1) * region_template[4] - 1));
		local iWidth = iEastX - iWestX + 1;
		local iHeight = iNorthY - iSouthY + 1;
		local args = {};
		args.iWaterPercent = 55;
		args.iRegionWidth = iWidth;
		args.iRegionHeight = iHeight;
		args.iRegionWestX = iWestX;
		args.iRegionSouthY = iSouthY;
		args.iRegionGrain = 4 - landmass_type;
		args.iRegionHillsGrain = 3;
		args.iRegionPlotFlags = self.iNoFlags;
		self:GenerateFractalLayer(args)
		local args = {};
		args.iWaterPercent = 55;
		args.iRegionWidth = iWidth;
		args.iRegionHeight = iHeight;
		args.iRegionWestX = iWestX;
		args.iRegionSouthY = iSouthY;
		args.iRegionGrain = 1;
		args.iRegionHillsGrain = 3;
		args.iRegionPlotFlags = self.iHorzFlags;
		args.iRegionFracXExp = 5;
		args.iRegionFracYExp = 5;
		self:GenerateFractalLayer(args)
	end
	return self.wholeworldPlotTypes
end
------------------------------------------------------------------------------
function MirrorGenerateRingPlotTypes()
	local layered = MultilayeredFractal.Create();
	local plots = MirrorRingPlotsByRegion(layered);
	SetPlotTypes(plots);
	MirrorWestToEast(true, false, false, false, false);
	MirrorKeepContinentFlags();
	mirror_coastArgs = nil;	-- Ring.lua: the game's normal coasts
end
------------------------------------------------------------------------------
function MirrorInRingCentre(x, y)
	local c = mirror_ringCentre;
	return c ~= nil and x > c[1] and x < c[2] and y > c[3] and y < c[4];
end
------------------------------------------------------------------------------
function MirrorRingTerrainAtPlot(self, iX, iY)
	-- Ring.lua's terrain: Skirmish-like dominant terrain, a polar (tundra) centre.
	local terrainVal = self.terrainGrass;
	local plot = Map.GetPlot(iX, iY);
	if (plot:IsWater()) then
		local val = plot:GetTerrainType();
		if val == TerrainTypes.NO_TERRAIN then
			val = self.terrainGrass;
			plot:SetPlotType(PlotTypes.PLOT_LAND, false, false);
		end
		return val;
	end
	if iX >= centWestX and iX <= centEastX and iY >= centSouthY and iY <= centNorthY then
		local desertVal = self.deserts:GetHeight(iX, iY);
		local plainsVal = self.plains:GetHeight(iX, iY);
		if desertVal >= self.deserts:GetHeight(95) then
			terrainVal = self.terrainSnow;
		elseif plainsVal >= self.plains:GetHeight(88) then
			terrainVal = self.terrainPlains;
		else
			terrainVal = self.terrainTundra;
		end
	elseif dominant_terrain == 2 then -- Plains
		local desertVal = self.deserts:GetHeight(iX, iY);
		local plainsVal = self.plains:GetHeight(iX, iY);
		if desertVal >= self.deserts:GetHeight(95) then
			terrainVal = self.terrainDesert;
		elseif plainsVal <= self.plains:GetHeight(90) then
			terrainVal = self.terrainPlains;
		end
	elseif dominant_terrain == 4 then -- Jungle
		-- All grass all the time!
	else -- Grassland / Forest
		local plainsVal = self.plains:GetHeight(iX, iY);
		if plainsVal >= self.plains:GetHeight(90) then
			terrainVal = self.terrainPlains;
		end
	end
	return terrainVal;
end
------------------------------------------------------------------------------
function MirrorRingInitFractals(self)
	local width = self.iGridW;
	local height = self.iGridH;
	self.jungles		= Fractal.Create(width, height, self.jungle_grain, self.fractalFlags, self.fracXExp, self.fracYExp);
	self.forests		= Fractal.Create(width, height, self.forest_grain, self.fractalFlags, self.fracXExp, self.fracYExp);
	self.forestclumps	= Fractal.Create(width, height, self.clump_grain, self.fractalFlags, self.fracXExp, self.fracYExp);
	self.marsh			= Fractal.Create(width, height, 4, self.fractalFlags, self.fracXExp, self.fracYExp);
	self.iJungleBottom	= self.jungles:GetHeight((100 - self.iJunglePercent)/2)
	self.iJungleTop		= self.jungles:GetHeight((100 + self.iJunglePercent)/2)
	self.iJungleRange	= (self.iJungleTop - self.iJungleBottom) * self.iJungleFactor;
	self.iForestLevel	= self.forests:GetHeight(80)
	self.iClumpLevel	= self.forestclumps:GetHeight(94)
	self.iMarshLevel	= self.marsh:GetHeight(100 - self.fMarshPercent)
	if dominant_terrain == 3 then -- Forest
		self.iClumpLevel	= self.forestclumps:GetHeight(65)
		self.iForestLevel	= self.forests:GetHeight(55)
	end
end
------------------------------------------------------------------------------
function MirrorRingAddJunglesAtPlot(self, plot, iX, iY, lat)
	if dominant_terrain == 4 then -- Jungle
		if (iX < centWestX or iX > centEastX or iY < centSouthY or iY > centNorthY) then
			local jungle_height = self.jungles:GetHeight(iX, iY);
			if jungle_height <= self.jungles:GetHeight(90) and jungle_height >= self.jungles:GetHeight(15) then
				if plot:IsFlatlands() or plot:IsHills() then
					plot:SetFeatureType(self.featureJungle, -1);
				end
			end
		end
	end
end
------------------------------------------------------------------------------
-- West_vs_East.lua's latitudes (squeezed toward the equator, no ice).
MirrorBase_TerrainLatitude = TerrainGenerator.GetLatitudeAtPlot;
function TerrainGenerator:GetLatitudeAtPlot(iX, iY)
	if mirror_landmass ~= 4 then
		return MirrorBase_TerrainLatitude(self, iX, iY);
	end
	local lat = math.abs((self.iHeight / 2) - iY) / (self.iHeight / 2);
	lat = lat + (128 - self.variation:GetHeight(iX, iY))/(255.0 * 5.0);
	lat = 0.8 * (math.clamp(lat, 0, 1));
	return lat;
end
MirrorBase_FeatureLatitude = FeatureGenerator.GetLatitudeAtPlot;
function FeatureGenerator:GetLatitudeAtPlot(iX, iY)
	if mirror_landmass ~= 4 then
		return MirrorBase_FeatureLatitude(self, iX, iY);
	end
	local lat = math.abs((self.iGridH/2) - iY)/(self.iGridH/2);
	return 0.8 * lat;
end
------------------------------------------------------------------------------
-- ARCHIPELAGO COASTS: an exact share of the water is deep ocean
------------------------------------------------------------------------------
function MirrorArchipelagoCoasts()
	-- Water next to land is always coast. Of the rest, the tiles nearest to land
	-- (with a little noise for natural edges) become coast until only the chosen
	-- share of all water is deep ocean.
	local iW, iH = Map.GetGridSize();
	local share = MirrorArchipelagoSettings().oceanShare;
	local dist, queue, head = {}, {}, 1;
	local nWater = 0;
	for i = 0, iW * iH - 1 do
		local plot = Map.GetPlotByIndex(i);
		if plot:IsWater() then
			nWater = nWater + 1;
		else
			dist[i] = 0;
			table.insert(queue, i);
		end
	end
	while head <= table.maxn(queue) do
		local c = queue[head];
		head = head + 1;
		for loop, nb in ipairs(MirrorNeighbours(c)) do
			if dist[nb] == nil then
				dist[nb] = dist[c] + 1;
				table.insert(queue, nb);
			end
		end
	end
	local far = {};
	for i = 0, iW * iH - 1 do
		local plot = Map.GetPlotByIndex(i);
		if plot:IsWater() then
			if (dist[i] or 99) <= 1 then
				plot:SetTerrainType(TerrainTypes.TERRAIN_COAST, false, false);
			else
				table.insert(far, {i = i, key = (dist[i] or 99) * 100 + Map.Rand(150, "Mirror Archipelago - coast edge") * 1000 / 1000});
			end
		end
	end
	table.sort(far, function(a, b) if a.key ~= b.key then return a.key < b.key end return a.i < b.i end);
	local nOcean = math.floor(nWater * share + 0.5);
	local nCoast = table.maxn(far) - nOcean;
	for rank, entry in ipairs(far) do
		local terrain = TerrainTypes.TERRAIN_OCEAN;
		if rank <= nCoast then terrain = TerrainTypes.TERRAIN_COAST end
		Map.GetPlotByIndex(entry.i):SetTerrainType(terrain, false, false);
	end
	print("Mirror Archipelago: water", nWater, "deep ocean", math.min(nOcean, table.maxn(far)));
end
------------------------------------------------------------------------------
------------------------------------------------------------------------------
function MirrorGenerateNewLandmassPlotTypes()
	if mirror_landmass == 3 then
		MirrorGenerateArchipelagoPlotTypes();
	elseif mirror_landmass == 4 then
		MirrorGenerateEastWestPlotTypes();
	else
		MirrorGenerateRingPlotTypes();
	end
end
------------------------------------------------------------------------------
-- ARCHIPELAGO START REGIONS: one region per start island
------------------------------------------------------------------------------
function MirrorArchipelagoRegions(asp)
	local iW, iH = Map.GetGridSize();
	local k = asp.mirror_k;
	asp.mirror_regionArea = {};
	asp.regionData = {};
	local function Box(tiles)
		local x0, y0, x1, y1 = 9999, 9999, -1, -1;
		for loop, i in ipairs(tiles) do
			local x, y = i % iW, math.floor(i / iW);
			x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y);
		end
		return x0, y0, x1 - x0 + 1, y1 - y0 + 1;
	end
	local twins = {};
	for r = 1, k do
		local id = mirror_startIslands[r];
		if id == nil then
			-- Not enough room for a start island (should not happen): fall back to the biggest free island.
			print("Mirror Archipelago WARNING: no start island for spot", r);
			local bestId, bestSize = 1, -1;
			for n, island in ipairs(mirror_islands) do
				if island.kind ~= "start" and table.maxn(island.plots) > bestSize then bestId, bestSize = n, table.maxn(island.plots) end
			end
			id = bestId;
			mirror_islands[id].kind = "start";
			mirror_startIslands[r] = id;
		end
		local tiles = mirror_islands[id].plots;
		local x, y, w, h = Box(tiles);
		-- the area of a passable tile: a mountain (the start island's peak) is an area of its own
		local area = Map.GetPlotByIndex(tiles[1]):GetArea();
		for loop, i in ipairs(tiles) do
			local p = Map.GetPlotByIndex(i);
			if not p:IsMountain() and not p:IsWater() then area = p:GetArea(); break end
		end
		local fert = 0;
		for loop, i in ipairs(tiles) do
			fert = fert + asp:MeasureStartPlacementFertilityOfPlot(i % iW, math.floor(i / iW), true);
		end
		local n = table.maxn(tiles);
		table.insert(asp.regionData, {x, y, w, h, area, fert, n, fert / n});
		asp.mirror_regionArea[r] = area;
		twins[r] = {};
		for loop, i in ipairs(tiles) do table.insert(twins[r], mirror_twin[i]) end
	end
	for r = 1, k do
		local data = asp.regionData[r];
		local x, y, w, h = Box(twins[r]);
		local area = Map.GetPlotByIndex(twins[r][1]):GetArea();
		for loop, i in ipairs(twins[r]) do
			local p = Map.GetPlotByIndex(i);
			if not p:IsMountain() and not p:IsWater() then area = p:GetArea(); break end
		end
		table.insert(asp.regionData, {x, y, w, h, area, data[6], data[7], data[8]});
		asp.mirror_regionArea[k + r] = area;
	end
	asp.mirror_startIslandArea = {};
	for r = 1, 2 * k do asp.mirror_startIslandArea[asp.mirror_regionArea[r]] = true end
end
------------------------------------------------------------------------------
-- COASTAL STARTS (East vs West, Ring)
------------------------------------------------------------------------------
mirror_seaAreaOK = nil;	-- GLOBAL water areas that count as "the sea" for coastal starts
function MirrorIsSeaCoast(plot)
	-- Coastal on the sea, not on a lake or a small bay: East vs West = the channel
	-- (the biggest water body); Ring = any water of 20 tiles or more.
	if mirror_seaAreaOK == nil then
		local iW, iH = Map.GetGridSize();
		local sizes, biggest, biggestArea = {}, 0, -1;
		for i = 0, iW * iH - 1 do
			local p = Map.GetPlotByIndex(i);
			if p:IsWater() then
				local a = p:GetArea();
				sizes[a] = (sizes[a] or 0) + 1;
				if sizes[a] > biggest then biggest, biggestArea = sizes[a], a end
			end
		end
		mirror_seaAreaOK = {};
		for a, n in pairs(sizes) do
			if (mirror_landmass == 4 and a == biggestArea) or (mirror_landmass ~= 4 and n >= 20) then
				mirror_seaAreaOK[a] = true;
			end
		end
	end
	if plot:IsWater() then return false end
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
		local adj = Map.PlotDirection(plot:GetX(), plot:GetY(), direction);
		if adj ~= nil and adj:IsWater() and mirror_seaAreaOK[adj:GetArea()] then return true end
	end
	return false
end
function MirrorCoastalRegions(asp)
	-- Which west regions must start on the coast. Mirrored, so the east team gets the same.
	local need = {};
	if mirror_landmass == 3 then	-- Archipelago: everyone on the coast (user)
		for r = 1, asp.mirror_k do need[r] = true end
		return need
	end
	if mirror_landmass ~= 4 and mirror_landmass ~= 5 then return need end
	local mode = MirrorOpt("coastal", 3);
	if mode == 3 then return need end
	local k = asp.mirror_k;
	if mode == 2 or not asp.mirror_twoTeams then
		for r = 1, k do need[r] = true end
		return need
	end
	-- One per team: the region with the most coastal land.
	local iW, iH = Map.GetGridSize();
	local bestR, bestCount = 1, -1;
	for r = 1, k do
		local data = asp.regionData[r];
		local count = 0;
		for y = data[2], data[2] + data[4] - 1 do
			for x = data[1], data[1] + data[3] - 1 do
				local plot = Map.GetPlot(x, y);
				if plot ~= nil and mirror_kind[y * iW + x] == MIRROR_WEST and MirrorIsSeaCoast(plot) and not plot:IsMountain()
					and (asp.mirror_mainArea == -1 or plot:GetArea() == asp.mirror_mainArea) then
					count = count + 1;
				end
			end
		end
		if count > bestCount then bestR, bestCount = r, count end
	end
	need[bestR] = true;
	return need
end
------------------------------------------------------------------------------
-- FISH AROUND ISLANDS (archipelago, "Varied")
------------------------------------------------------------------------------
function MirrorIslandFish(asp)
	-- Archipelago resources (west side; the final mirror copies them east):
	--  1. capitals levelled: exactly N Fish and at least M land bonus within 3 tiles,
	--     plus one sea luxury when coastal luxuries are "More"/"Lots";
	--  2. Fish around the other islands, spread evenly by coast length ("Even") or
	--     rich/poor islands ("Varied");
	--  3. land bonus resources by the density option (outside the capitals);
	--  4. extra coastal luxuries (Whales, Pearls, Crab) and atolls on the open coasts.
	if mirror_landmass ~= 3 then return end
	local o = MirrorArchipelagoSettings();
	local iW, iH = Map.GetGridSize();
	local fish = GameInfo.Resources["RESOURCE_FISH"];
	if fish == nil then return end
	local fishID = fish.ID;
	local seaLux = {};
	for loop, t in ipairs({"RESOURCE_WHALE", "RESOURCE_PEARLS", "RESOURCE_CRAB"}) do
		if GameInfo.Resources[t] ~= nil then table.insert(seaLux, GameInfo.Resources[t].ID) end
	end
	local isSeaLux = {};
	for loop, id in ipairs(seaLux) do isSeaLux[id] = true end
	local atoll = GameInfo.Features["FEATURE_ATOLL"];

	local capitals = {};
	for r = 1, asp.mirror_k do
		local data = asp.startingPlots[r];
		if data ~= nil then table.insert(capitals, data) end
	end
	local function CapitalDist(i)
		local x, y = i % iW, math.floor(i / iW);
		local d = 99;
		for loop, data in ipairs(capitals) do d = math.min(d, Map.PlotDistance(x, y, data[1], data[2])) end
		return d;
	end
	local function FreeCoast(i)
		local plot = Map.GetPlotByIndex(i);
		return mirror_kind[i] == MIRROR_WEST and not MirrorIsNoResourceIndex(i) and plot:IsWater() and not plot:IsLake()
			and plot:GetTerrainType() == TerrainTypes.TERRAIN_COAST and plot:GetResourceType(-1) == -1
			and plot:GetFeatureType() == FeatureTypes.NO_FEATURE and plot:GetImprovementType() == -1 and plot:IsAdjacentToLand();
	end
	local function IsBonus(res)
		return res ~= -1 and GameInfo.Resources[res] ~= nil and GameInfo.Resources[res].ResourceUsage == 0;
	end
	local function TakeRandom(list)
		return table.remove(list, 1 + Map.Rand(table.maxn(list), "Mirror Archipelago - resource spot"));
	end
	local stats = {fishAdded = 0, fishRemoved = 0, bonusAdded = 0, lux = 0, atolls = 0};

	-- 1. Capitals.
	for loop, data in ipairs(capitals) do
		local x, y = data[1], data[2];
		local fishPlots, freeSea, bonusLand, freeLand, haveLux = {}, {}, 0, {}, false;
		local nearSea = {};		-- free coast within 2 tiles: Fish there is worked from turn 1
		for dy = -3, 3 do
			for dx = -4, 4 do
				local plot = Map.GetPlot(x + dx, y + dy);
				if plot ~= nil then
					local i = plot:GetY() * iW + plot:GetX();
					local d = Map.PlotDistance(x, y, plot:GetX(), plot:GetY());
					if d >= 1 and d <= 3 and mirror_kind[i] == MIRROR_WEST then
						local res = plot:GetResourceType(-1);
						if plot:IsWater() then
							if res == fishID then table.insert(fishPlots, i)
							elseif isSeaLux[res] then haveLux = true
							elseif FreeCoast(i) then
								table.insert(freeSea, i);
								if d <= 2 then table.insert(nearSea, i) end
							end
						elseif not plot:IsMountain() then
							if IsBonus(res) then bonusLand = bonusLand + 1
							elseif res == -1 and plot:GetImprovementType() == -1 then table.insert(freeLand, plot) end
						end
					end
				end
			end
		end
		while table.maxn(fishPlots) > o.capitalFish do
			local i = TakeRandom(fishPlots);
			Map.GetPlotByIndex(i):SetResourceType(-1, 0);
			table.insert(freeSea, i);
			stats.fishRemoved = stats.fishRemoved + 1;
		end
		local nFish = table.maxn(fishPlots);
		while nFish < o.capitalFish and table.maxn(freeSea) > 0 do
			local i;
			if table.maxn(nearSea) > 0 then
				i = TakeRandom(nearSea);
				for n = table.maxn(freeSea), 1, -1 do
					if freeSea[n] == i then table.remove(freeSea, n) end
				end
			else
				i = TakeRandom(freeSea);
			end
			Map.GetPlotByIndex(i):SetResourceType(fishID, 1);
			nFish = nFish + 1;
			stats.fishAdded = stats.fishAdded + 1;
		end
		if o.coastLux >= 2 and not haveLux and table.maxn(seaLux) > 0 and table.maxn(freeSea) > 0 then
			Map.GetPlotByIndex(TakeRandom(freeSea)):SetResourceType(seaLux[1 + Map.Rand(table.maxn(seaLux), "Mirror Archipelago - sea luxury")], 1);
			stats.lux = stats.lux + 1;
		end
		while bonusLand < o.capitalBonus and table.maxn(freeLand) > 0 do
			local plot = table.remove(freeLand, 1 + Map.Rand(table.maxn(freeLand), "Mirror Archipelago - capital bonus"));
			if asp:AttemptToPlaceBonusResourceAtPlot(plot:GetX(), plot:GetY(), false) then
				bonusLand = bonusLand + 1;
				stats.bonusAdded = stats.bonusAdded + 1;
			end
		end
	end

	-- 2. + 3. The other islands (and start-island land beyond the capital's 3 tiles).
	local luxSpots = {};
	for id, island in ipairs(mirror_islands) do
		local water, seen, have = {}, {}, 0;
		for loop, t in ipairs(island.plots) do
			for loop2, nb in ipairs(MirrorNeighbours(t)) do
				if not seen[nb] and CapitalDist(nb) > 3 then
					seen[nb] = true;
					local plot = Map.GetPlotByIndex(nb);
					if plot:IsWater() and mirror_kind[nb] == MIRROR_WEST then
						if plot:GetResourceType(-1) == fishID then
							have = have + 1;
						elseif FreeCoast(nb) then
							table.insert(water, nb);
						end
					end
				end
			end
			-- land bonus by density
			if o.landBonus > 0 and CapitalDist(t) > 3 and mirror_kind[t] == MIRROR_WEST then
				local plot = Map.GetPlotByIndex(t);
				if not plot:IsMountain() and plot:GetResourceType(-1) == -1 and plot:GetImprovementType() == -1
					and Map.Rand(1000, "Mirror Archipelago - land bonus") < o.landBonus * 1000 then
					if asp:AttemptToPlaceBonusResourceAtPlot(plot:GetX(), plot:GetY(), false) then
						stats.bonusAdded = stats.bonusAdded + 1;
					end
				end
			end
		end
		local nCoast = table.maxn(water) + have;
		local want = math.floor(nCoast / o.coastPerFish * (0.8 + 0.6 * (island.thin or 0.5)) + 0.5);
		if island.kind == "small" then want = math.max(want, 1) end
		-- small islands (MIRROR_SMALL_ISLAND_TILES or less, not start islands): at least
		-- one Fish per MIRROR_SMALL_COAST_PER_FISH coast tiles, at least one
		if island.kind ~= "start" and table.maxn(island.plots) <= MIRROR_SMALL_ISLAND_TILES then
			want = math.max(want, math.floor(nCoast / MIRROR_SMALL_COAST_PER_FISH + 0.5), 1);
		end
		if o.seaMode == 2 and island.kind ~= "start" and island.kind ~= "own" then
			local roll = Map.Rand(100, "Mirror Archipelago - island richness");
			if roll < 30 then want = 0 elseif roll >= 75 then want = want + 1 + Map.Rand(2, "Mirror Archipelago - fish") end
		end
		-- spread out: a new Fish never next to another one
		local function NextToFish(i)
			for loop, nb in ipairs(MirrorNeighbours(i)) do
				if Map.GetPlotByIndex(nb):GetResourceType(-1) == fishID then return true end
			end
			return false
		end
		while have < want and table.maxn(water) > 0 do
			local i = TakeRandom(water);
			if not NextToFish(i) then
				Map.GetPlotByIndex(i):SetResourceType(fishID, 1);
				have = have + 1;
				stats.fishAdded = stats.fishAdded + 1;
			else
				table.insert(luxSpots, i);
			end
		end
		for loop, i in ipairs(water) do table.insert(luxSpots, i) end
	end

	-- 4. Extra coastal luxuries and atolls on the open coasts (away from capitals).
	local nLux = ({0, asp.mirror_k, 2 * asp.mirror_k})[o.coastLux] or 0;
	local nAtolls = ({0, 2 * asp.mirror_k, 4 * asp.mirror_k})[o.atolls] or 0;
	local placed = {};
	local function Spaced(i, gap)
		local x, y = i % iW, math.floor(i / iW);
		for loop, j in ipairs(placed) do
			if Map.PlotDistance(x, y, j % iW, math.floor(j / iW)) < gap then return false end
		end
		return true
	end
	local tries = 0;
	while (nLux > 0 or nAtolls > 0) and table.maxn(luxSpots) > 0 and tries < 2000 do
		tries = tries + 1;
		local i = TakeRandom(luxSpots);
		if FreeCoast(i) and CapitalDist(i) >= 3 and MirrorTwinDistance(i % iW, math.floor(i / iW)) > 2 then
			local plot = Map.GetPlotByIndex(i);
			if nLux > 0 and table.maxn(seaLux) > 0 and Spaced(i, 4) then
				plot:SetResourceType(seaLux[1 + Map.Rand(table.maxn(seaLux), "Mirror Archipelago - sea luxury")], 1);
				table.insert(placed, i);
				nLux = nLux - 1;
				stats.lux = stats.lux + 1;
			elseif nAtolls > 0 and atoll ~= nil and Spaced(i, 2) then
				plot:SetFeatureType(atoll.ID, -1);
				table.insert(placed, i);
				nAtolls = nAtolls - 1;
				stats.atolls = stats.atolls + 1;
			end
		end
	end
	print("Mirror Archipelago (west side): fish +", stats.fishAdded, "-", stats.fishRemoved, "land bonus +", stats.bonusAdded,
		"sea luxuries +", stats.lux, "atolls +", stats.atolls);
end
------------------------------------------------------------------------------
------------------------------------------------------------------------------

function GeneratePlotTypes()
	print("Setting Plot Types (Lua Mirror Skirmish) ...");

	local iW, iH = Map.GetGridSize();
	if mirror_landmass == 2 then
		-- The game's own Pangaea, mirrored (see MirrorGeneratePangaeaPlotTypes).
		MirrorGeneratePangaeaPlotTypes();
	elseif mirror_landmass >= 3 then
		-- Archipelago, East vs West or Ring (drawn on the west half, then mirrored).
		MirrorGenerateNewLandmassPlotTypes();
	else
		local layered_world = MultilayeredFractal.Create();
		local plotsSkirmish = layered_world:GeneratePlotsByRegion();

		SetPlotTypes(plotsSkirmish);

		if mirror_stripType == 0 then
			-- Skirmish (unchanged): examine all plots in buffer zone.
			local firstRingYIsEven = {{0, 1}, {1, 0}, {0, -1}, {-1, -1}, {-1, 0}, {-1, 1}};
			local firstRingYIsOdd = {{1, 1}, {1, 0}, {1, -1}, {0, -1}, {-1, 0}, {0, 1}};
			for x = iW / 2 - 2, iW / 2 + 1 do
				for y = 1, iH - 2 do
					local plot = Map.GetPlot(x, y)
					if plot:IsFlatlands() then -- Check for adjacent Mountain plot; if found, change this plot to Hills.
						local isEvenY, search_table = true, {};
						if y / 2 > math.floor(y / 2) then
							isEvenY = false;
						end
						if isEvenY then
							search_table = firstRingYIsEven;
						else
							search_table = firstRingYIsOdd;
						end

						for loop, plot_adjustments in ipairs(search_table) do
							local searchX, searchY;
							searchX = x + plot_adjustments[1];
							searchY = y + plot_adjustments[2];
							local searchPlot = Map.GetPlot(searchX, searchY)
							local plotType = searchPlot:GetPlotType()
							if plotType == PlotTypes.PLOT_MOUNTAIN then
								plot:SetPlotType(PlotTypes.PLOT_HILLS, false, false)
								break
							end
						end
					end
				end
			end
		end

		-- Mirror the land shape now and lay down the strip, so coasts and terrain see the final shape.
		MirrorWestToEast(true, false, false, false, false);
	end
	for i = 0, iW * iH - 1 do
		if mirror_kind[i] == MIRROR_STRIP or mirror_kind[i] == MIRROR_LONE then
			local plot = Map.GetPlotByIndex(i);
			local plotType = PlotTypes.PLOT_LAND;
			if mirror_kind[i] == MIRROR_STRIP then
				plotType = MirrorStripLooksAt(plot:GetX(), plot:GetY());
			elseif mirror_landmass >= 2 and mirror_landmass ~= 4 then
				plotType = PlotTypes.PLOT_OCEAN;
			end
			plot:SetPlotType(plotType, false, false);
		end
	end

	-- Like Skirmish's buffer zone: flat land touching the mountain strip becomes hills (foothills).
	if mirror_stripType == 3 then
		local firstRingYIsEven = {{0, 1}, {1, 0}, {0, -1}, {-1, -1}, {-1, 0}, {-1, 1}};
		local firstRingYIsOdd = {{1, 1}, {1, 0}, {1, -1}, {0, -1}, {-1, 0}, {0, 1}};
		for y = 0, iH - 1 do
			for x = 0, iW - 1 do
				local i = y * iW + x;
				local kind = mirror_kind[i];
				if (kind == MIRROR_WEST or kind == MIRROR_EAST) and mirror_axisDist[i] <= mirror_stripHalf + 1.01 then
					local plot = Map.GetPlot(x, y);
					if plot:IsFlatlands() then
						local search_table = firstRingYIsEven;
						if y % 2 == 1 then
							search_table = firstRingYIsOdd;
						end
						for loop, plot_adjustments in ipairs(search_table) do
							local searchPlot = Map.GetPlot(x + plot_adjustments[1], y + plot_adjustments[2]);
							if searchPlot ~= nil and searchPlot:GetPlotType() == PlotTypes.PLOT_MOUNTAIN then
								plot:SetPlotType(PlotTypes.PLOT_HILLS, false, false)
								break
							end
						end
					end
				end
			end
		end
	end

	if mirror_landmass == 3 then
		GenerateCoasts({bExpandCoasts = false});
		MirrorArchipelagoCoasts();
	else
		GenerateCoasts(mirror_coastArgs);
	end
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
function TerrainGenerator:GenerateTerrainAtPlot(iX,iY)
	if mirror_landmass == 5 then -- Ring.lua's own terrain.
		return MirrorRingTerrainAtPlot(self, iX, iY);
	end
	if mirror_landmass >= 2 then -- Pangaea uses the game's own terrain bands.
		return MirrorBase_GenerateTerrainAtPlot(self, iX, iY);
	end
	local lat = self:GetLatitudeAtPlot(iX,iY);
	local terrainVal = self.terrainGrass;

	local plot = Map.GetPlot(iX, iY);
	if (plot:IsWater()) then
		local val = plot:GetTerrainType();
		if val == TerrainTypes.NO_TERRAIN then -- Error handling.
			val = self.terrainGrass;
			plot:SetPlotType(PlotTypes.PLOT_LAND, false, false);
		end
		return val;
	end

	-- Begin implementation of User Input for dominant terrain type (Skirmish.lua)
	if dominant_terrain == 2 then -- Plains
		-- Mostly Plains, but a smattering of grass or desert.
		local desertVal = self.deserts:GetHeight(iX, iY);
		local plainsVal = self.plains:GetHeight(iX, iY);
		if desertVal >= self.deserts:GetHeight(95) then
			terrainVal = self.terrainDesert;
		elseif plainsVal <= self.plains:GetHeight(90) then
			terrainVal = self.terrainPlains;
		end
	elseif dominant_terrain == 4 then -- Jungle
		-- All grass all the time!
	elseif dominant_terrain == 5 then -- Desert
		local desertVal = self.deserts:GetHeight(iX, iY);
		local plainsVal = self.plains:GetHeight(iX, iY);
		if desertVal <= self.deserts:GetHeight(85) then
			terrainVal = self.terrainDesert;
		else
			terrainVal = self.terrainPlains;
		end
	elseif dominant_terrain == 6 then -- Tundra
		local desertVal = self.deserts:GetHeight(iX, iY);
		local plainsVal = self.plains:GetHeight(iX, iY);
		if plainsVal >= self.plains:GetHeight(85) then
			terrainVal = self.terrainPlains;
		elseif desertVal >= self.deserts:GetHeight(94) then
			terrainVal = self.terrainSnow;
		else
			terrainVal = self.terrainTundra;
		end
	elseif dominant_terrain == 8 then -- Global (aka normal climate bands)
		if(lat >= self.fSnowLatitude) then
			terrainVal = self.terrainSnow;
		elseif(lat >= self.fTundraLatitude) then
			terrainVal = self.terrainTundra;
		elseif (lat < self.fGrassLatitude) then
			terrainVal = self.terrainGrass;
		else
			local desertVal = self.deserts:GetHeight(iX, iY);
			local plainsVal = self.plains:GetHeight(iX, iY);
			if ((desertVal >= self.iDesertBottom) and (desertVal <= self.iDesertTop) and (lat >= self.fDesertBottomLatitude) and (lat < self.fDesertTopLatitude)) then
				terrainVal = self.terrainDesert;
			elseif ((plainsVal >= self.iPlainsBottom) and (plainsVal <= self.iPlainsTop)) then
				terrainVal = self.terrainPlains;
			end
		end
	else -- Grassland / Forest / Hills
		local plainsVal = self.plains:GetHeight(iX, iY);
		if plainsVal >= self.plains:GetHeight(90) then
			terrainVal = self.terrainPlains;
		end
	end

	return terrainVal;
end
------------------------------------------------------------------------------
function GenerateTerrain()
	print("Generating Terrain (Lua Mirror Skirmish) ...");

	local args = {};
	if mirror_landmass >= 2 then
		-- Pangaea.lua: Temperature setting input by user.
		local temp = MirrorOpt("temp", 2);
		if temp == 4 then
			temp = 1 + Map.Rand(3, "Random Temperature - Lua");
		end
		args = {temperature = temp};
	end
	local terraingen = TerrainGenerator.Create(args);

	local terrainTypes = terraingen:GenerateTerrain();

	SetTerrainTypes(terrainTypes);

	-- Mirror the terrain (and the random coast shapes) and clean the strip.
	MirrorWestToEast(true, true, false, false, false);
	MirrorApplyStrip();
	MirrorFixLonePlots();
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
function GetRiverValueAtPlot(plot)
	if mirror_landmass >= 2 then -- Pangaea uses the game's own river logic.
		return MirrorBase_GetRiverValueAtPlot(plot);
	end
	-- Custom method to force rivers to flow away from the map center.
	local iW, iH = Map.GetGridSize()
	local x = plot:GetX()
	local y = plot:GetY()
	local random_factor = Map.Rand(3, "River direction random factor - Skirmish LUA");
	local direction_influence_value = (math.abs(iW - (x - (iW / 2))) + ((math.abs(y - (iH / 2))) / 3)) * random_factor;

	local numPlots = PlotTypes.NUM_PLOT_TYPES;
	local sum = ((numPlots - plot:GetPlotType()) * 20) + direction_influence_value;

	local numDirections = DirectionTypes.NUM_DIRECTION_TYPES;
	for direction = 0, numDirections - 1 do
		local adjacentPlot = Map.PlotDirection(plot:GetX(), plot:GetY(), direction);
		if (adjacentPlot ~= nil) then
			sum = sum + (numPlots - adjacentPlot:GetPlotType());
		else
			sum = sum + (numPlots * 10);
		end
	end
	sum = sum + Map.Rand(10, "River Rand");

	return sum;
end
------------------------------------------------------------------------------
function DoRiver(startPlot, thisFlowDirection, originalFlowDirection, riverID)
	if mirror_landmass >= 2 then -- Pangaea uses the game's own river logic.
		return MirrorBase_DoRiver(startPlot, thisFlowDirection, originalFlowDirection, riverID);
	end
	-- Customizing to handle problems in top row of the map. Only this aspect has been altered.

	local iW, iH = Map.GetGridSize()
	thisFlowDirection = thisFlowDirection or FlowDirectionTypes.NO_FLOWDIRECTION;
	originalFlowDirection = originalFlowDirection or FlowDirectionTypes.NO_FLOWDIRECTION;

	-- pStartPlot = the plot at whose SE corner the river is starting
	if (riverID == nil) then
		riverID = nextRiverID;
		nextRiverID = nextRiverID + 1;
	end

	local otherRiverID = _rivers[startPlot]
	if (otherRiverID ~= nil and otherRiverID ~= riverID and originalFlowDirection == FlowDirectionTypes.NO_FLOWDIRECTION) then
		return; -- Another river already exists here; can't branch off of an existing river!
	end

	local riverPlot;

	local bestFlowDirection = FlowDirectionTypes.NO_FLOWDIRECTION;
	if (thisFlowDirection == FlowDirectionTypes.FLOWDIRECTION_NORTH) then

		riverPlot = startPlot;
		local adjacentPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_EAST);
		if ( adjacentPlot == nil or riverPlot:IsWOfRiver() or riverPlot:IsWater() or adjacentPlot:IsWater() ) then
			return;
		end

		_rivers[riverPlot] = riverID;
		riverPlot:SetWOfRiver(true, thisFlowDirection);
		riverPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST);

	elseif (thisFlowDirection == FlowDirectionTypes.FLOWDIRECTION_NORTHEAST) then

		riverPlot = startPlot;
		local adjacentPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);
		if ( adjacentPlot == nil or riverPlot:IsNWOfRiver() or riverPlot:IsWater() or adjacentPlot:IsWater() ) then
			return;
		end

		_rivers[riverPlot] = riverID;
		riverPlot:SetNWOfRiver(true, thisFlowDirection);
		-- riverPlot does not change

	elseif (thisFlowDirection == FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST) then

		riverPlot = Map.PlotDirection(startPlot:GetX(), startPlot:GetY(), DirectionTypes.DIRECTION_EAST);
		if (riverPlot == nil) then
			return;
		end

		local adjacentPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
		if (adjacentPlot == nil or riverPlot:IsNEOfRiver() or riverPlot:IsWater() or adjacentPlot:IsWater()) then
			return;
		end

		_rivers[riverPlot] = riverID;
		riverPlot:SetNEOfRiver(true, thisFlowDirection);
		-- riverPlot does not change

	elseif (thisFlowDirection == FlowDirectionTypes.FLOWDIRECTION_SOUTH) then

		riverPlot = Map.PlotDirection(startPlot:GetX(), startPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
		if (riverPlot == nil) then
			return;
		end

		local adjacentPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_EAST);
		if (adjacentPlot == nil or riverPlot:IsWOfRiver() or riverPlot:IsWater() or adjacentPlot:IsWater()) then
			return;
		end

		_rivers[riverPlot] = riverID;
		riverPlot:SetWOfRiver(true, thisFlowDirection);
		-- riverPlot does not change

	elseif (thisFlowDirection == FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST) then

		riverPlot = startPlot;
		local adjacentPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);
		if (adjacentPlot == nil or riverPlot:IsNWOfRiver() or riverPlot:IsWater() or adjacentPlot:IsWater()) then
			return;
		end

		_rivers[riverPlot] = riverID;
		riverPlot:SetNWOfRiver(true, thisFlowDirection);
		-- riverPlot does not change

	elseif (thisFlowDirection == FlowDirectionTypes.FLOWDIRECTION_NORTHWEST) then

		riverPlot = startPlot;
		local adjacentPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);

		if ( adjacentPlot == nil or riverPlot:IsNEOfRiver() or riverPlot:IsWater() or adjacentPlot:IsWater()) then
			return;
		end

		_rivers[riverPlot] = riverID;
		riverPlot:SetNEOfRiver(true, thisFlowDirection);
		riverPlot = Map.PlotDirection(riverPlot:GetX(), riverPlot:GetY(), DirectionTypes.DIRECTION_WEST);

	else
		-- River is starting here, set the direction in the next step
		riverPlot = startPlot;
	end

	if (riverPlot == nil or riverPlot:IsWater()) then
		-- The river has flowed off the edge of the map or into the ocean. All is well.
		return;
	end

	-- Storing X,Y positions as locals to prevent redundant function calls.
	local riverPlotX = riverPlot:GetX();
	local riverPlotY = riverPlot:GetY();

	-- Table of methods used to determine the adjacent plot.
	local adjacentPlotFunctions = {
		[FlowDirectionTypes.FLOWDIRECTION_NORTH] = function()
			return Map.PlotDirection(riverPlotX, riverPlotY, DirectionTypes.DIRECTION_NORTHWEST);
		end,

		[FlowDirectionTypes.FLOWDIRECTION_NORTHEAST] = function()
			return Map.PlotDirection(riverPlotX, riverPlotY, DirectionTypes.DIRECTION_NORTHEAST);
		end,

		[FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST] = function()
			return Map.PlotDirection(riverPlotX, riverPlotY, DirectionTypes.DIRECTION_EAST);
		end,

		[FlowDirectionTypes.FLOWDIRECTION_SOUTH] = function()
			return Map.PlotDirection(riverPlotX, riverPlotY, DirectionTypes.DIRECTION_SOUTHWEST);
		end,

		[FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST] = function()
			return Map.PlotDirection(riverPlotX, riverPlotY, DirectionTypes.DIRECTION_WEST);
		end,

		[FlowDirectionTypes.FLOWDIRECTION_NORTHWEST] = function()
			return Map.PlotDirection(riverPlotX, riverPlotY, DirectionTypes.DIRECTION_NORTHWEST);
		end
	}

	if(bestFlowDirection == FlowDirectionTypes.NO_FLOWDIRECTION) then

		-- Attempt to calculate the best flow direction.
		-- Mirror Skirmish: the six directions are walked in a fixed order (0..5)
		-- instead of pairs(), so every multiplayer client walks them the same way.
		local bestValue = math.huge;
		for flowDirection = 0, 5 do
			local getAdjacentPlot = adjacentPlotFunctions[flowDirection];

			if (GetOppositeFlowDirection(flowDirection) ~= originalFlowDirection) then

				if (thisFlowDirection == FlowDirectionTypes.NO_FLOWDIRECTION or
					flowDirection == TurnRightFlowDirections[thisFlowDirection] or
					flowDirection == TurnLeftFlowDirections[thisFlowDirection]) then

					local adjacentPlot = getAdjacentPlot();

					if (adjacentPlot ~= nil) then

						local value = GetRiverValueAtPlot(adjacentPlot);
						if (flowDirection == originalFlowDirection) then
							value = (value * 3) / 4;
						end

						if (value < bestValue) then
							bestValue = value;
							bestFlowDirection = flowDirection;
						end

					-- Custom addition for Highlands, to fix river problems in top row of the map. Any other all-land map may need similar special casing.
					elseif adjacentPlot == nil and riverPlotY == iH - 1 then -- Top row of map, needs special handling
						if flowDirection == FlowDirectionTypes.FLOWDIRECTION_NORTH or
						   flowDirection == FlowDirectionTypes.FLOWDIRECTION_NORTHWEST or
						   flowDirection == FlowDirectionTypes.FLOWDIRECTION_NORTHEAST then

							local value = Map.Rand(5, "River Rand");
							if (flowDirection == originalFlowDirection) then
								value = (value * 3) / 4;
							end
							if (value < bestValue) then
								bestValue = value;
								bestFlowDirection = flowDirection;
							end
						end

					-- Custom addition for Highlands, to fix river problems in left column of the map. Any other all-land map may need similar special casing.
					elseif adjacentPlot == nil and riverPlotX == 0 then -- Left column of map, needs special handling
						if flowDirection == FlowDirectionTypes.FLOWDIRECTION_NORTH or
						   flowDirection == FlowDirectionTypes.FLOWDIRECTION_SOUTH or
						   flowDirection == FlowDirectionTypes.FLOWDIRECTION_NORTHWEST or
						   flowDirection == FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST then

							local value = Map.Rand(5, "River Rand");
							if (flowDirection == originalFlowDirection) then
								value = (value * 3) / 4;
							end
							if (value < bestValue) then
								bestValue = value;
								bestFlowDirection = flowDirection;
							end
						end
					end
				end
			end
		end

		-- Try a second pass allowing the river to "flow backwards".
		if(bestFlowDirection == FlowDirectionTypes.NO_FLOWDIRECTION) then

			local bestValue = math.huge;
			for flowDirection = 0, 5 do
				local getAdjacentPlot = adjacentPlotFunctions[flowDirection];

				if (thisFlowDirection == FlowDirectionTypes.NO_FLOWDIRECTION or
					flowDirection == TurnRightFlowDirections[thisFlowDirection] or
					flowDirection == TurnLeftFlowDirections[thisFlowDirection]) then

					local adjacentPlot = getAdjacentPlot();

					if (adjacentPlot ~= nil) then

						local value = GetRiverValueAtPlot(adjacentPlot);
						if (value < bestValue) then
							bestValue = value;
							bestFlowDirection = flowDirection;
						end
					end
				end
			end
		end
	end

	--Recursively generate river.
	if (bestFlowDirection ~= FlowDirectionTypes.NO_FLOWDIRECTION) then
		if  (originalFlowDirection == FlowDirectionTypes.NO_FLOWDIRECTION) then
			originalFlowDirection = bestFlowDirection;
		end

		DoRiver(riverPlot, bestFlowDirection, originalFlowDirection, riverID);
	end
end
------------------------------------------------------------------------------
function AddRivers()
	if mirror_landmass >= 2 then
		-- Pangaea: the game's own rivers, then the west ones are mirrored.
		MirrorBase_AddRivers();
		if mirror_landmass == 2 then MirrorPickCrossRiver() end
		MirrorRivers();
		MirrorApplyStrip();
		MirrorFixLonePlots();
		return
	end
	-- Only add rivers if Water Setting is value of 1 or 4. Otherwise no rivers.
	if userInputWaterSetting == 2 or userInputWaterSetting == 3 or userInputWaterSetting == 5 then -- No Rivers!
		return
	end

	-- Customization for Skirmish, to keep river starts away from buffer zone in middle columns of map, and set river "original flow direction".
	local iW, iH = Map.GetGridSize()
	print("Mirror Skirmish - Adding Rivers");
	local passConditions = {
		function(plot)
			return plot:IsHills() or plot:IsMountain();
		end,

		function(plot)
			return (not plot:IsCoastalLand()) and (Map.Rand(8, "MapGenerator AddRivers") == 0);
		end,

		function(plot)
			local area = plot:Area();
			local plotsPerRiverEdge = GameDefines["PLOTS_PER_RIVER_EDGE"];
			return (plot:IsHills() or plot:IsMountain()) and (area:GetNumRiverEdges() <	((area:GetNumTiles() / plotsPerRiverEdge) + 1));
		end,

		function(plot)
			local area = plot:Area();
			local plotsPerRiverEdge = GameDefines["PLOTS_PER_RIVER_EDGE"];
			return (area:GetNumRiverEdges() < (area:GetNumTiles() / plotsPerRiverEdge) + 1);
		end
	}
	for iPass, passCondition in ipairs(passConditions) do
		local riverSourceRange;
		local seaWaterRange;
		if (iPass <= 2) then
			riverSourceRange = GameDefines["RIVER_SOURCE_MIN_RIVER_RANGE"];
			seaWaterRange = GameDefines["RIVER_SOURCE_MIN_SEAWATER_RANGE"];
		else
			riverSourceRange = (GameDefines["RIVER_SOURCE_MIN_RIVER_RANGE"] / 2);
			seaWaterRange = (GameDefines["RIVER_SOURCE_MIN_SEAWATER_RANGE"] / 2);
		end
		for i, plot in Plots() do
			local current_x = plot:GetX()
			local current_y = plot:GetY()
			if current_x < 1 or current_x >= iW - 2 or current_y < 2 or current_y >= iH - 1 then
				-- Plot too close to edge, ignore it.
			elseif mirror_kind[i] == MIRROR_STRIP or mirror_kind[i] == MIRROR_LONE or mirror_axisDist[i] <= mirror_stripHalf + 1.01 then
				-- Plot in or next to the dead strip, ignore it. (Was Skirmish's buffer zone check.)
			elseif mirror_stripType == 0 and current_x >= (iW / 2) - 2 and current_x <= (iW / 2) + 1 then
				-- No strip: Skirmish's own buffer zone, ignore it.
			elseif (not plot:IsWater()) then
				if(passCondition(plot)) then
					if (not Map.FindWater(plot, riverSourceRange, true)) then
						if (not Map.FindWater(plot, seaWaterRange, false)) then
							local inlandCorner = plot:GetInlandCorner();
							if(inlandCorner) then
								local start_x = inlandCorner:GetX()
								local start_y = inlandCorner:GetY()
								local orig_direction;
								if start_y < iH / 2 then -- South half of map
									if start_x < iW / 2 then -- West half of map
										orig_direction = FlowDirectionTypes.FLOWDIRECTION_NORTHWEST;
									else -- East half
										orig_direction = FlowDirectionTypes.FLOWDIRECTION_NORTHEAST;
									end
								else -- North half of map
									if start_x < iW / 2 then -- West half of map
										orig_direction = FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST;
									else -- NE corner
										orig_direction = FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST;
									end
								end
								DoRiver(inlandCorner, nil, orig_direction, nil);
							end
						end
					end
				end
			end
		end
	end
	-- Keep the west rivers, give the east their mirror images.
	MirrorRivers();
	MirrorApplyStrip();
	MirrorFixLonePlots();
end
------------------------------------------------------------------------------
function AddLakes()
	-- Skirmish: no lakes added in this manner.
	if mirror_landmass >= 2 then
		-- Pangaea: the game's own small lakes, then the west ones are mirrored.
		MirrorBase_AddLakes();
		MirrorWestToEast(true, true, false, false, false);
		MirrorApplyStrip();
		MirrorFixLonePlots();
		Map.RecalculateAreas();
	end
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
function FeatureGenerator:__initFractals()
	if mirror_landmass == 5 then -- Ring.lua's own feature settings.
		return MirrorRingInitFractals(self);
	end
	if mirror_landmass >= 2 then -- Pangaea uses the game's own feature settings.
		return MirrorBase_FeatureInitFractals(self);
	end
	local width = self.iGridW;
	local height = self.iGridH;

	-- Create fractals
	self.jungles		= Fractal.Create(width, height, self.jungle_grain, self.fractalFlags, self.fracXExp, self.fracYExp);
	self.forests		= Fractal.Create(width, height, self.forest_grain, self.fractalFlags, self.fracXExp, self.fracYExp);
	self.forestclumps	= Fractal.Create(width, height, self.clump_grain, self.fractalFlags, self.fracXExp, self.fracYExp);
	self.marsh			= Fractal.Create(width, height, 4, self.fractalFlags, self.fracXExp, self.fracYExp);

	-- Get heights
	self.iJungleBottom	= self.jungles:GetHeight((100 - self.iJunglePercent)/2)
	self.iJungleTop		= self.jungles:GetHeight((100 + self.iJunglePercent)/2)
	self.iJungleRange	= (self.iJungleTop - self.iJungleBottom) * self.iJungleFactor;
	self.iForestLevel	= self.forests:GetHeight(80) -- 20% forest coverage
	self.iClumpLevel	= self.forestclumps:GetHeight(94) -- 6% forest clumps
	self.iMarshLevel	= self.marsh:GetHeight(100 - self.fMarshPercent)

	if dominant_terrain == 3 then -- Forest
		self.iClumpLevel	= self.forestclumps:GetHeight(65) -- 35% forest clumps
		self.iForestLevel	= self.forests:GetHeight(55) -- 45% forest coverage of what isn't covered by clumps.
	elseif dominant_terrain == 5 then -- Desert
		self.iOasisPercent = 8;
		if userInputWaterSetting == 4 then
			self.iOasisPercent = 6;
		elseif userInputWaterSetting == 5 then
			self.iOasisPercent = 15;
		end
	elseif dominant_terrain == 6 then -- Tundra
		self.iClumpLevel	= self.forestclumps:GetHeight(80) -- 20% forest clumps
		self.iForestLevel	= self.forests:GetHeight(60) -- 40% forest coverage of what isn't covered by clumps.
	elseif dominant_terrain == 8 then -- Global
		self.iClumpLevel	= self.forestclumps:GetHeight(90) -- 10% forest clumps
		self.iForestLevel	= self.forests:GetHeight(69) -- 31% forest coverage of what isn't covered by clumps.
	end
end
------------------------------------------------------------------------------
function FeatureGenerator:AddIceAtPlot(plot, iX, iY, lat)
	if mirror_landmass == 4 or mirror_landmass == 5 then return end -- West vs East and Ring: no ice
	if mirror_landmass >= 2 then
		return MirrorBase_AddIceAtPlot(self, plot, iX, iY, lat);
	end
	if dominant_terrain == 8 then -- Global
		if (plot:CanHaveFeature(self.featureIce)) then
			if Map.IsWrapX() and (iY == 0 or iY == self.iGridH - 1) then
				plot:SetFeatureType(self.featureIce, -1)
			else
				local rand = Map.Rand(100, "Add Ice Lua")/100.0;
				if(rand < 8 * (lat - 0.875)) then
					plot:SetFeatureType(self.featureIce, -1);
				elseif(rand < 4 * (lat - 0.75)) then
					plot:SetFeatureType(self.featureIce, -1);
				end
			end
		end
	end
end
------------------------------------------------------------------------------
function FeatureGenerator:AddJunglesAtPlot(plot, iX, iY, lat)
	if mirror_landmass == 5 then
		return MirrorRingAddJunglesAtPlot(self, plot, iX, iY, lat);
	end
	if mirror_landmass >= 2 then
		return MirrorBase_AddJunglesAtPlot(self, plot, iX, iY, lat);
	end
	if dominant_terrain == 4 then -- Jungle
		local jungle_height = self.jungles:GetHeight(iX, iY);
		if jungle_height <= self.jungles:GetHeight(90) and jungle_height >= self.jungles:GetHeight(15) then
			if plot:IsFlatlands() or plot:IsHills() then
				plot:SetFeatureType(self.featureJungle, -1);
			end
		end
	elseif dominant_terrain == 8 then -- Global, use default jungle placement.
		local jungle_height = self.jungles:GetHeight(iX, iY);
		if jungle_height <= self.iJungleTop and jungle_height >= self.iJungleBottom + (self.iJungleRange * lat) then
			if plot:IsFlatlands() or plot:IsHills() then
				plot:SetFeatureType(self.featureJungle, -1);
			end
		end
	-- else -- No jungles
	end
end
------------------------------------------------------------------------------
function FeatureGenerator:AdjustTerrainTypes()
	if mirror_landmass >= 2 and mirror_landmass ~= 5 then -- (Ring.lua: jungle on plains, as Skirmish)
		return MirrorBase_AdjustTerrainTypes(self);
	end
	local width = self.iGridW - 1;
	local height = self.iGridH - 1;
	for y = 0, height do
		for x = 0, width do
			local plot = Map.GetPlot(x, y);
			if (plot:GetFeatureType() == self.featureJungle) then
				plot:SetTerrainType(self.terrainPlains, false, true)  -- These flags are for recalc of areas and rebuild of graphics. No need to recalc from any of these changes.
			end
		end
	end
end
------------------------------------------------------------------------------
function AddFeatures()
	print("Adding Features (Lua Mirror Skirmish) ...");

	if mirror_landmass >= 2 then
		-- Pangaea.lua: Rainfall setting input by user; mountains are taken off coastlines.
		local rain = MirrorOpt("rain", 2);
		if rain == 4 then
			rain = 1 + Map.Rand(3, "Random Rainfall - Lua");
		end
		local featuregen = FeatureGenerator.Create({rainfall = rain});
		featuregen:AddFeatures(false);
		if MIRROR_VARIANT == "pangaea" then
			MirrorThinForests(({25, 50, 75, 100})[MirrorOpt("forest", 4)] or 100);
		end
	else
		local featuregen = FeatureGenerator.Create();
		featuregen:AddFeatures();
	end

	-- Features and the terrain under jungles: copy the west onto the east.
	MirrorWestToEast(true, true, true, false, false);
	MirrorApplyStrip();
	MirrorFixLonePlots();
end
------------------------------------------------------------------------------

function MirrorThinForests(keepPercent)
	-- "Forest and jungle" option: keeps only this share of the game's forests and
	-- jungles on the west half (the east is copied from it right after).
	if keepPercent >= 100 then return end
	local iW, iH = Map.GetGridSize();
	local removed = 0;
	for i = 0, iW * iH - 1 do
		if mirror_kind[i] == MIRROR_WEST or mirror_kind[i] == MIRROR_AXIS then
			local plot = Map.GetPlotByIndex(i);
			local f = plot:GetFeatureType();
			if (f == FeatureTypes.FEATURE_FOREST or f == FeatureTypes.FEATURE_JUNGLE)
				and Map.Rand(100, "Mirror Pangaea - thin forests") >= keepPercent then
				plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
				removed = removed + 1;
			end
		end
	end
	print("Mirror Skirmish: forests and jungles removed:", removed, "keeping", keepPercent, "%");
end
------------------------------------------------------------------------------
-- TEAMS AND SIDES
------------------------------------------------------------------------------
function MirrorPlanSides(asp)
	-- Decides which players start in the west and which in the east, and how
	-- many start spots each side gets (mirror_k). Every west spot has an east twin.
	--
	-- Two teams (team vs team): one team per side, side chosen at random as in
	-- Skirmish. Like Weevee, the k-th player of one team gets the mirror image of
	-- the k-th player of the other team (players counted in slot order), and each
	-- team's half is divided into one region per player, so teammates share a side.
	-- Uneven teams: the bigger team sets the number of spots; the smaller team
	-- leaves a spot empty.
	--
	-- Any other setup (free for all, 3+ teams): teams are split over the two sides
	-- as evenly as possible, never splitting a team. An odd player count leaves one
	-- east spot empty.
	local teams = {};
	local teamIndex = {};
	for loop, player_ID in ipairs(asp.player_ID_list) do
		local team_ID = Players[player_ID]:GetTeam();
		if teamIndex[team_ID] == nil then
			table.insert(teams, {id = team_ID, players = {}});
			teamIndex[team_ID] = table.maxn(teams);
		end
		table.insert(teams[teamIndex[team_ID]].players, player_ID);
	end
	local westTeams, eastTeams = {}, {};
	asp.mirror_twoTeams = false;
	if table.maxn(teams) == 2 then
		asp.mirror_twoTeams = true;
		local order = GetShuffledCopyOfTable({1, 2});
		table.insert(westTeams, teams[order[1]]);
		table.insert(eastTeams, teams[order[2]]);
	else
		local shuffled = GetShuffledCopyOfTable(teams);
		local total = 0;
		for loop, team in ipairs(shuffled) do
			total = total + table.maxn(team.players);
		end
		-- Subset sum: which side totals are reachable without splitting a team.
		local reachedBy, previous = {}, {};
		reachedBy[0] = 0;
		for t, team in ipairs(shuffled) do
			local size = table.maxn(team.players);
			for s = total - size, 0, -1 do
				if reachedBy[s] ~= nil and reachedBy[s + size] == nil then
					reachedBy[s + size] = t;
					previous[s + size] = s;
				end
			end
		end
		local best = 0;
		for s = math.floor(total / 2), 0, -1 do
			if reachedBy[s] ~= nil then
				best = s;
				break
			end
		end
		local inFirst = {};
		local s = best;
		while s > 0 do
			inFirst[reachedBy[s]] = true;
			s = previous[s];
		end
		local first, second = {}, {};
		for t, team in ipairs(shuffled) do
			if inFirst[t] then
				table.insert(first, team);
			else
				table.insert(second, team);
			end
		end
		if Map.Rand(2, "Mirror Skirmish - which group starts west") == 0 then
			westTeams, eastTeams = first, second;
		else
			westTeams, eastTeams = second, first;
		end
	end
	asp.mirror_westPlayers, asp.mirror_eastPlayers = {}, {};
	for loop, team in ipairs(westTeams) do
		for n, player_ID in ipairs(team.players) do
			table.insert(asp.mirror_westPlayers, player_ID);
		end
	end
	for loop, team in ipairs(eastTeams) do
		for n, player_ID in ipairs(team.players) do
			table.insert(asp.mirror_eastPlayers, player_ID);
		end
	end
	local nWest = table.maxn(asp.mirror_westPlayers);
	local nEast = table.maxn(asp.mirror_eastPlayers);
	asp.mirror_k = math.max(nWest, nEast, 1);
	print("Mirror Skirmish: west players", nWest, "east players", nEast, "spots per side", asp.mirror_k);
	if nWest ~= nEast then
		print("Mirror Skirmish WARNING: uneven sides, one or more starts will have an empty mirror twin.");
	end
end
------------------------------------------------------------------------------
function MirrorWestRectWidth()
	-- West start rectangle: from the west edge up to the last column that is
	-- west of the strip on every row.
	local iW, iH = Map.GetGridSize();
	local width = iW;
	for y = 0, 1 do
		for x = 0, iW - 1 do
			if mirror_kind[y * iW + x] ~= MIRROR_WEST then
				width = math.min(width, x);
				break
			end
		end
	end
	return width;
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- START PLOT SYSTEM
------------------------------------------------------------------------------
function AssignStartingPlots:GenerateRegions(args)
	print("Map Generation - Dividing the map in to Regions (Mirror Skirmish)");
	local args = args or {};
	local iW, iH = Map.GetGridSize();
	self.method = 3; -- Flag the map as using a Rectangular division method.

	-- Automatically set strategic resources to place a source of iron, horse and oil at every start location.
	self.resource_setting = 5;

	-- Determine number of civilizations and city states present in this game.
	self.iNumCivs, self.iNumCityStates, self.player_ID_list, self.bTeamGame, self.teams_with_major_civs, self.number_civs_per_team = GetPlayerAndTeamInfo()
	self.iNumCityStatesUnassigned = self.iNumCityStates;
	self.iNumRealCivs = self.iNumCivs;
	print("-"); print("Civs:", self.iNumCivs); print("City States:", self.iNumCityStates);
	iNumTeams = table.maxn(self.teams_with_major_civs);				-- GLOBAL, as in Skirmish

	MirrorPlanSides(self);
	local k = self.mirror_k;

	if mirror_landmass == 3 then
		-- Archipelago: one region per start island (and its mirror image).
		self.mirror_mainArea, self.mirror_mainAreaEast = -1, -1;
		MirrorArchipelagoRegions(self);
		self.iNumCivs = 2 * k;
		MirrorBlockStripInASP(self);
		return
	end

	-- The west half (up to the strip) is divided into one region per west spot.
	self.inhabited_WestX = 0;
	self.inhabited_SouthY = 0;
	self.inhabited_Width = MirrorWestRectWidth();
	self.inhabited_Height = iH;
	if mirror_landmass == 2 then
		-- Pangaea: regions keep off the middle (and off the wrap seam), see MirrorPreferredTwinDistance.
		local margin = math.floor(MirrorPreferredTwinDistance() / 2);
		if mirror_wrap then self.inhabited_WestX = margin end
		self.inhabited_Width = math.max(4, self.inhabited_Width - margin - self.inhabited_WestX);
	end
	local fert_table, fertCount, plotCount, areaID;
	self.mirror_mainArea, self.mirror_mainAreaEast = -1, -1;
	if mirror_landmass >= 2 then
		-- Pangaea, East vs West, Ring: like the game's Pangaea (biggest landmass method), only the
		-- continent counts; islands get no regions.
		self.mirror_mainArea, self.mirror_mainAreaEast = MirrorMainWestArea();
		areaID = self.mirror_mainArea;
		fert_table, fertCount, plotCount = {}, 0, self.inhabited_Width * self.inhabited_Height;
		for y = self.inhabited_SouthY, self.inhabited_SouthY + self.inhabited_Height - 1 do
			for x = self.inhabited_WestX, self.inhabited_WestX + self.inhabited_Width - 1 do
				local plotFertility = 0;
				if Map.GetPlot(x, y):GetArea() == areaID then
					plotFertility = self:MeasureStartPlacementFertilityOfPlot(x, y, true);
				end
				table.insert(fert_table, plotFertility);
				fertCount = fertCount + plotFertility;
			end
		end
	else
		areaID = -1; -- AreaID -1 means ignore area IDs.
		fert_table, fertCount, plotCount = self:MeasureStartPlacementFertilityInRectangle(self.inhabited_WestX,
		                                   self.inhabited_SouthY, self.inhabited_Width, self.inhabited_Height)
	end
	local rect_table = {self.inhabited_WestX, self.inhabited_SouthY, self.inhabited_Width,
	                    self.inhabited_Height, areaID, fertCount, plotCount};
	self:DivideIntoRegions(k, fert_table, rect_table)

	-- East regions are the mirror images of the west ones: region k + r is the twin of region r.
	for r = 1, k do
		local data = self.regionData[r];
		local westX, southY, width, height = data[1], data[2], data[3], data[4];
		local eastX = iW - 1 - (westX + width - 1);
		local eastArea = data[5];
		if eastArea ~= -1 then
			eastArea = self.mirror_mainAreaEast;
		end
		table.insert(self.regionData, {eastX, southY, width, height, eastArea, data[6], data[7], data[8]});
	end
	-- From here on the start plot system works with 2k regions ("civs").
	self.iNumCivs = 2 * k;

	MirrorBlockStripInASP(self);
end
------------------------------------------------------------------------------
function MirrorBlockStripInASP(asp)
	-- Nothing may be placed on the strip or the lone edge plots. With no strip,
	-- the plots touching the centre line get no start, city state or wonder, and
	-- resources only where the plot is its own mirror image.
	local iW, iH = Map.GetGridSize();
	for i = 0, iW * iH - 1 do
		local n = i + 1;
		if MirrorIsNoSiteIndex(i) then
			asp.playerCollisionData[n] = true;
			asp.cityStateData[n] = 99;
			asp.naturalWondersData[n] = 99;
		end
		if MirrorIsNoResourceIndex(i) then
			asp.strategicData[n] = 99;
			asp.luxuryData[n] = 99;
			asp.bonusData[n] = 99;
			asp.fishData[n] = 99;
			asp.marbleData[n] = 99;
			asp.sheepData[n] = 99;
		end
	end
end
------------------------------------------------------------------------------
function MirrorPreferredTwinDistance()
	-- Pangaea: nobody should start next to the middle, face to face with the
	-- other team. A start keeps a fifth of the map width from its own mirror
	-- twin (with wrap that also keeps it off the seam, the second mirror line).
	if mirror_landmass == 2 then
		local iW, iH = Map.GetGridSize();
		return math.max(9, math.floor(iW * 0.2));
	end
	return 9;
end
------------------------------------------------------------------------------
function MirrorBiasStartCandidates(asp)
	-- A start near the strip would sit close to its own mirror twin. Treat each
	-- west plot as if a start already stood on its mirror image, using Firaxis's
	-- own ripple values, so starts settle at least 9 tiles from their twin when
	-- possible. (Weevee does the same kind of "mirror-aware" spacing.)
	-- (No extra map-edge rule: Skirmish has none, and its start finder already
	-- rates edge plots low because part of their city radius is off the map.)
	local iW, iH = Map.GetGridSize();
	local ripple_values = {97, 95, 92, 89, 69, 57, 24, 15};
	for i = 0, iW * iH - 1 do
		if mirror_kind[i] == MIRROR_WEST then
			local x, y = i % iW, math.floor(i / iW);
			local d = MirrorTwinDistance(x, y);
			local n = i + 1;
			if d >= 1 and d <= 8 then
				asp.distanceData[n] = math.max(asp.distanceData[n], ripple_values[d]);
			elseif d > 8 and d < MirrorPreferredTwinDistance() then
				asp.distanceData[n] = math.max(asp.distanceData[n], 90);	-- Pangaea: too close to the middle
			end
			if asp.mirror_mainArea ~= nil and asp.mirror_mainArea ~= -1 and Map.GetPlot(x, y):GetArea() ~= asp.mirror_mainArea then
				asp.distanceData[n] = math.max(asp.distanceData[n], 97);	-- Pangaea: islands only as a last resort
			end
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:ChooseLocations(args)
	print("Map Generation - Choosing Start Locations for Civilizations (Mirror Skirmish)");
	local args = args or {};
	local iW, iH = Map.GetGridSize();
	local mustBeCoast = args.mustBeCoast or false; -- if true, will force all starts on salt water coast if possible

	-- Defaults for evaluating potential start plots are assigned in .Create but args
	-- passed in here can override. If args value for a field is nil (no arg) then
	-- these assignments will keep the default values in place.
	self.centerBias = args.centerBias or self.centerBias; -- % of radius from region center to examine first
	self.middleBias = args.middleBias or self.middleBias; -- % of radius from region center to check second
	self.minFoodInner = args.minFoodInner or self.minFoodInner;
	self.minProdInner = args.minProdInner or self.minProdInner;
	self.minGoodInner = args.minGoodInner or self.minGoodInner;
	self.minFoodMiddle = args.minFoodMiddle or self.minFoodMiddle;
	self.minProdMiddle = args.minProdMiddle or self.minProdMiddle;
	self.minGoodMiddle = args.minGoodMiddle or self.minGoodMiddle;
	self.minFoodOuter = args.minFoodOuter or self.minFoodOuter;
	self.minProdOuter = args.minProdOuter or self.minProdOuter;
	self.minGoodOuter = args.minGoodOuter or self.minGoodOuter;
	self.maxJunk = args.maxJunk or self.maxJunk;

	-- Measure terrain/plot/feature in regions.
	self:MeasureTerrainInRegions()

	-- Determine region type.
	self:DetermineRegionTypes()

	-- East regions are copies of their west twins.
	local k = self.mirror_k;
	for r = 1, k do
		self.regionTypes[k + r] = self.regionTypes[r];
		self.regionTerrainCounts[k + r] = self.regionTerrainCounts[r];
	end

	MirrorBiasStartCandidates(self);

	-- Process the west regions, poorest first (as the core game does).
	local regionAssignList = {};
	local averageFertilityListUnsorted = {};
	local averageFertilityListSorted = {}; -- Have to make this a separate table, not merely a pointer to the first table.
	for i = 1, k do
		local thisRegionAvgFert = self.regionData[i][8];
		table.insert(averageFertilityListUnsorted, {i, thisRegionAvgFert});
		table.insert(averageFertilityListSorted, thisRegionAvgFert);
	end
	table.sort(averageFertilityListSorted);
	for region_order = 1, k do
		for loop, data_pair in ipairs(averageFertilityListUnsorted) do
			if averageFertilityListSorted[region_order] == data_pair[2] then
				table.insert(regionAssignList, data_pair[1]);
				table.remove(averageFertilityListUnsorted, loop);
				break
			end
		end
	end

	mirror_seaAreaOK = nil;
	local coastal = MirrorCoastalRegions(self);
	for assignIndex = 1, k do
		local currentRegionNumber = regionAssignList[assignIndex];
		if mirror_landmass == 3 then
			self:FindStart(currentRegionNumber)	-- archipelago: on its own start island
		else
			self:FindStartWithoutRegardToAreaID(currentRegionNumber, mustBeCoast or coastal[currentRegionNumber] == true)
		end
		MirrorRespaceStart(self, currentRegionNumber, regionAssignList, assignIndex, coastal[currentRegionNumber] == true);
		if mirror_landmass == 2 then
			MirrorInlandStart(self, currentRegionNumber, regionAssignList, assignIndex);
		end
		-- The east twin of this start, right away, so later west starts keep their distance from it.
		local data = self.startingPlots[currentRegionNumber];
		local twinX = MirrorTwinX(data[1], data[2]);
		self.startingPlots[k + currentRegionNumber] = {twinX, data[2], data[3]};
		self:PlaceImpactAndRipples(twinX, data[2])
	end
end
------------------------------------------------------------------------------
function MirrorInlandStart(asp, region_number, regionAssignList, assignIndex)
	-- Pangaea: the game's start finder rates the coast so high that nearly every
	-- start ends up on it (user: "can't get an inland start"). Half the starts
	-- (rolled per start) move to the best inland plot within 3 tiles, keeping
	-- the same spacing rules (6 from other starts, the twin distance).
	local data = asp.startingPlots[region_number];
	local plot = Map.GetPlot(data[1], data[2]);
	if plot == nil or not plot:IsCoastalLand() then return end
	if Map.Rand(2, "Mirror Pangaea - inland start roll") == 0 then return end
	local iW, iH = Map.GetGridSize();
	local k = asp.mirror_k;
	local others = {};
	for n = 1, assignIndex - 1 do
		local r = regionAssignList[n];
		table.insert(others, asp.startingPlots[r]);
		table.insert(others, asp.startingPlots[k + r]);
	end
	local minTwin = math.min(MirrorPreferredTwinDistance(), MirrorTwinDistance(data[1], data[2]));
	local region_type = asp.regionTypes[region_number];
	local bestIndex, bestScore = -1, -99999;
	for dy = -3, 3 do
		for dx = -4, 4 do
			local p = Map.GetPlot(data[1] + dx, data[2] + dy);
			if p ~= nil and Map.PlotDistance(data[1], data[2], p:GetX(), p:GetY()) <= 3 then
				local x, y = p:GetX(), p:GetY();
				local i = y * iW + x;
				local pt = p:GetPlotType();
				if mirror_kind[i] == MIRROR_WEST and not MirrorIsNoSiteIndex(i) and not p:IsCoastalLand()
					and (pt == PlotTypes.PLOT_LAND or pt == PlotTypes.PLOT_HILLS) and not p:IsLake()
					and p:GetTerrainType() ~= TerrainTypes.TERRAIN_SNOW
					and (asp.mirror_mainArea == nil or asp.mirror_mainArea == -1 or p:GetArea() == asp.mirror_mainArea)
					and MirrorTwinDistance(x, y) >= minTwin then
					local spaced = true;
					for loop, o in ipairs(others) do
						if Map.PlotDistance(x, y, o[1], o[2]) < 6 then spaced = false end
					end
					if spaced then
						local score = asp:EvaluateCandidatePlot(i + 1, region_type);
						if score > bestScore then bestIndex, bestScore = i, score end
					end
				end
			end
		end
	end
	if bestIndex >= 0 then
		local x, y = bestIndex % iW, math.floor(bestIndex / iW);
		asp.startingPlots[region_number] = {x, y, bestScore};
		asp:PlaceImpactAndRipples(x, y);
		print("Mirror Pangaea: start of region", region_number, "moved inland to", x, y);
	end
end
------------------------------------------------------------------------------
function MirrorRespaceStart(asp, region_number, regionAssignList, assignIndex, bCoastal)
	-- Crowded maps (many players on little land) can leave a start right next to
	-- another one, where the second capital could not even be founded. Like
	-- Weevee's minimum start distance, move such a start to the best plot that
	-- keeps 6 tiles from every other start (4 at the very least) and 9 from its
	-- own mirror twin, first inside its region, then anywhere in the west.
	local iW, iH = Map.GetGridSize();
	local k = asp.mirror_k;
	local others = {};
	for n = 1, assignIndex - 1 do
		local r = regionAssignList[n];
		table.insert(others, asp.startingPlots[r]);
		table.insert(others, asp.startingPlots[k + r]);
	end
	local function Spacing(x, y)
		local d = 99;
		for loop, data in ipairs(others) do
			d = math.min(d, Map.PlotDistance(x, y, data[1], data[2]));
		end
		return d;
	end
	local data = asp.startingPlots[region_number];
	local function CoastOK(plot)
		return not bCoastal or MirrorIsSeaCoast(plot)
	end
	local preferredTwin = MirrorPreferredTwinDistance();
	if Spacing(data[1], data[2]) >= 6 and MirrorTwinDistance(data[1], data[2]) >= preferredTwin and CoastOK(Map.GetPlot(data[1], data[2])) then
		return
	end
	local islandArea = nil;	-- archipelago: the start stays on its own island
	if asp.mirror_regionArea ~= nil then islandArea = asp.mirror_regionArea[region_number] end
	local region = asp.regionData[region_number];
	local region_type = asp.regionTypes[region_number];
	local passes = {{6, preferredTwin, true}, {6, preferredTwin, false}, {6, 9, true}, {6, 9, false}, {4, 5, true}, {4, 5, false}};
	for pass = 1, 6 do
		-- passes: region / whole west, first keeping the preferred distance from the twin (Pangaea: well
		-- away from the middle), then 9, then the bare minimum 4 from other starts and 5 from the twin
		local minOther, minTwin, bRegionOnly = passes[pass][1], passes[pass][2], passes[pass][3];
		local bestIndex, bestScore = -1, -99999;
		for i = 0, iW * iH - 1 do
			if mirror_kind[i] == MIRROR_WEST and not MirrorIsNoSiteIndex(i) then
				local x, y = i % iW, math.floor(i / iW);
				local inRegion = x >= region[1] and x < region[1] + region[3] and y >= region[2] and y < region[2] + region[4];
				local plot = Map.GetPlotByIndex(i);
				local plotType = plot:GetPlotType();
				local okArea = (asp.mirror_mainArea == nil or asp.mirror_mainArea == -1 or plot:GetArea() == asp.mirror_mainArea);
				if islandArea ~= nil then okArea = (plot:GetArea() == islandArea) end
				okArea = okArea and CoastOK(plot);
				if (inRegion or not bRegionOnly) and okArea and (plotType == PlotTypes.PLOT_LAND or plotType == PlotTypes.PLOT_HILLS)
					and plot:GetTerrainType() ~= TerrainTypes.TERRAIN_SNOW
					and Spacing(x, y) >= minOther and MirrorTwinDistance(x, y) >= minTwin then
					local score = asp:EvaluateCandidatePlot(i + 1, region_type);
					if score > bestScore then
						bestIndex, bestScore = i, score;
					end
				end
			end
		end
		if bestIndex >= 0 then
			local x, y = bestIndex % iW, math.floor(bestIndex / iW);
			print("Mirror Skirmish: start of region", region_number, "moved from", data[1], data[2], "to", x, y, "for spacing");
			asp.startingPlots[region_number] = {x, y, bestScore};
			asp:PlaceImpactAndRipples(x, y);
			return
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:BalanceAndAssign()
	-- Normalize the west starts. The east starts become exact copies.
	local k = self.mirror_k;
	for region_number = 1, k do
		self:NormalizeStartLocation(region_number)
	end
	for region_number = 1, k do
		self.startLocationConditions[k + region_number] = self.startLocationConditions[region_number];
	end
	MirrorWholeMap(false);
	MirrorAssignPlayers(self);
end
------------------------------------------------------------------------------
function MirrorAssignPlayers(asp)
	-- West players take west spots, east players take the twins of the same spots,
	-- so west player n and east player n are mirror images of each other.
	local k = asp.mirror_k;
	local slots = {};
	if asp.mirror_twoTeams then
		-- Team vs team: random spots, but always as mirror pairs.
		local list = {};
		for r = 1, k do table.insert(list, r) end
		slots = GetShuffledCopyOfTable(list);
	else
		-- FFA / several teams: spots in south-to-north order, and players come in
		-- team blocks, so teammates get neighbouring spots on their side.
		local sorted = {};
		for r = 1, k do table.insert(sorted, r) end
		table.sort(sorted, function(a, b)
			local pa, pb = asp.startingPlots[a], asp.startingPlots[b];
			if pa[2] ~= pb[2] then return pa[2] < pb[2] end
			if pa[1] ~= pb[1] then return pa[1] < pb[1] end
			return a < b
		end);
		slots = sorted;
	end
	mirror_assignment = {};		-- GLOBAL record, for logs and tests
	for n, player_ID in ipairs(asp.mirror_westPlayers) do
		local data = asp.startingPlots[slots[n]];
		Players[player_ID]:SetStartingPlot(Map.GetPlot(data[1], data[2]));
		table.insert(mirror_assignment, {player = player_ID, side = 1, slot = n, region = slots[n]});
		print("Mirror Skirmish: player", player_ID, "starts west at", data[1], data[2]);
	end
	for n, player_ID in ipairs(asp.mirror_eastPlayers) do
		local data = asp.startingPlots[k + slots[n]];
		Players[player_ID]:SetStartingPlot(Map.GetPlot(data[1], data[2]));
		table.insert(mirror_assignment, {player = player_ID, side = 2, slot = n, region = k + slots[n]});
		print("Mirror Skirmish: player", player_ID, "starts east at", data[1], data[2]);
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:CanPlaceCityStateAt(x, y, area_ID, force_it, ignore_collisions)
	-- Overriding default city state placement to prevent city states from being placed too close to map edges.
	local iW, iH = Map.GetGridSize();
	local plot = Map.GetPlot(x, y)
	local area = plot:GetArea()

	-- Adding this check for Skirmish.
	if x < 1 or x >= iW - 1 or y < 1 or y >= iH - 1 then
		return false
	end
	--

	if area ~= area_ID and area_ID ~= -1 then
		return false
	end
	if mirror_ringCentreOnly and not MirrorInRingCentre(x, y) then return false end
	-- Never close to a capital (user, 11-14): 6 tiles, 5 when forced.
	local minCapital = force_it and 5 or 6;
	if mirror_csAnyDistance then minCapital = 0 end	-- last resort on a crowded map
	for n, d in pairs(self.startingPlots) do
		if d ~= nil and d[1] ~= nil and Map.PlotDistance(x, y, d[1], d[2]) < minCapital then return false end
	end
	-- Archipelago: never on a start island, and only on islands of 4 tiles or more.
	if mirror_landmass == 3 then
		if self.mirror_startIslandArea ~= nil and self.mirror_startIslandArea[area] then return false end
		local a = Map.GetArea(area);
		if a == nil or a:GetNumTiles() < 4 then return false end
		if y < math.floor(iH * 0.15) or y > math.ceil(iH * 0.85) then return false end	-- not in the polar ice
	end
	local plotType = plot:GetPlotType()
	if plotType == PlotTypes.PLOT_OCEAN or plotType == PlotTypes.PLOT_MOUNTAIN then
		return false
	end
	local terrainType = plot:GetTerrainType()
	if terrainType == TerrainTypes.TERRAIN_SNOW then
		return false
	end
	local plotIndex = y * iW + x + 1;
	if self.cityStateData[plotIndex] > 0 and force_it == false then
		return false
	end
	local plotIndex = y * iW + x + 1;
	if self.playerCollisionData[plotIndex] == true and ignore_collisions == false then
		--print("-"); print("City State candidate plot rejected: collided with already-placed civ or City State at", x, y);
		return false
	end
	return true
end
------------------------------------------------------------------------------
function AssignStartingPlots:GetMajorStrategicResourceQuantityValues()
	local uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = 4, 4, 5, 6, 7, 8;
	-- Check the resource setting.
	if self.resource_setting == 1 then -- Sparse
		uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = 2, 4, 4, 4, 5, 5;
	elseif self.resource_setting == 3 then -- Abundant
		uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = 4, 6, 7, 9, 10, 10;
	end
	return uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt
end
------------------------------------------------------------------------------
function AssignStartingPlots:GetSmallStrategicResourceQuantityValues()
	local uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = 1, 2, 2, 2, 3, 3;
	-- Check the resource setting.
	if self.resource_setting == 1 then -- Sparse
		uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = 1, 1, 1, 1, 2, 2;
	elseif self.resource_setting == 3 then -- Abundant
		uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = 2, 3, 3, 3, 3, 3;
	end
	return uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt
end
------------------------------------------------------------------------------
function AssignStartingPlots:CustomOverride(resource_ID)
	-- CUSTOM OPERATION for Skirmish!
	--
	-- This function will identify up to four of the fifteen "Luxury Plot Lists"
	-- that match terrain best suitable for this type of strategic resource.
	print("-"); print("Obtaining indices for Strategic#", resource_ID);
	local primary, secondary, tertiary, quaternary = -1, -1, -1, -1;
	if resource_ID == self.iron_ID then
		primary, secondary, tertiary, quaternary = 4, 5, 10, 14;
	elseif resource_ID == self.horse_ID then
		primary, secondary, tertiary, quaternary = 12, 11, 4, 13;
	elseif resource_ID == self.coal_ID then
		primary, secondary, tertiary, quaternary = 4, 5, 2, 9;
	elseif resource_ID == self.oil_ID then
		primary, secondary, tertiary, quaternary = 10, 2, 14, 15;
	elseif resource_ID == self.aluminum_ID then
		primary, secondary, tertiary, quaternary = 4, 5, 14, 10;
	elseif resource_ID == self.uranium_ID then
		primary, secondary, tertiary, quaternary = 8, 2, 14, 10;
	end
	print("Found indices of", primary, secondary, tertiary, quaternary);
	return primary, secondary, tertiary, quaternary;
end
------------------------------------------------------------------------------
function AssignStartingPlots:PlaceStrategicAndBonusResources()
	-- KEY: {Resource ID, Quantity (0 = unquantified), weighting, minimum radius, maximum radius}
	-- KEY: (frequency (1 per n plots in the list), impact list number, plot list, resource data)
	--
	-- The radius creates a zone around the plot that other resources of that
	-- type will avoid if possible. See ProcessResourceList for impact numbers.
	--
	-- Order of placement matters, so changing the order may affect a later dependency.

	-- Adjust amounts, if applicable, based on Resource Setting.
	local uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = self:GetMajorStrategicResourceQuantityValues()
	local uran_sm, horse_sm, oil_sm, iron_sm, coal_sm, alum_sm = self:GetSmallStrategicResourceQuantityValues()
	local bonus_multiplier = 1;

	-- Distribute Strategic Resources to Regions -- CUSTOM for Skirmish.
	local dist_list = {
		{self.iron_ID, iron_amt, iron_sm},
		{self.horse_ID, horse_amt, horse_sm},
		{self.coal_ID, coal_amt, coal_sm},
		{self.oil_ID, oil_amt, oil_sm},
		{self.aluminum_ID, alum_amt, alum_sm},
		{self.uranium_ID, uran_amt, uran_sm},
	};
	for loop, reg_data in ipairs(self.regions_sorted_by_type) do
		local region_number = reg_data[1];
		for strategic_loop, res_data_table in ipairs(dist_list) do
			local res_ID = res_data_table[1];
			local res_amt = res_data_table[2];
			local res_sm = res_data_table[3];
			print("-"); print("- - -"); print("Attempting to place strategic resource #", res_ID, "in Region#", region_number);
			local iNumAlreadyPlaced = 0;
			local primary, secondary, tertiary, quaternary, luxury_plot_lists, shuf_list, iNumLeftToPlace;
			primary, secondary, tertiary, quaternary = self:CustomOverride(res_ID);
			luxury_plot_lists = self:GenerateLuxuryPlotListsInRegion(region_number)
			-- Place one large source of each resource type in each region.
			local iNumThisLuxToPlace = 1;
			shuf_list = GetShuffledCopyOfTable(luxury_plot_lists[primary])
			iNumLeftToPlace = self:PlaceSpecificNumberOfResources(res_ID, res_amt, iNumThisLuxToPlace, 0.3, 1, 1, 1, shuf_list);
			if iNumLeftToPlace > 0 and secondary > 0 then
				shuf_list = GetShuffledCopyOfTable(luxury_plot_lists[secondary])
				iNumLeftToPlace = self:PlaceSpecificNumberOfResources(res_ID, res_amt, iNumLeftToPlace, 0.3, 1, 1, 1, shuf_list);
			end
			if iNumLeftToPlace > 0 and tertiary > 0 then
				shuf_list = GetShuffledCopyOfTable(luxury_plot_lists[tertiary])
				iNumLeftToPlace = self:PlaceSpecificNumberOfResources(res_ID, res_amt, iNumLeftToPlace, 0.4, 1, 1, 1, shuf_list);
			end
			if iNumLeftToPlace > 0 and quaternary > 0 then
				shuf_list = GetShuffledCopyOfTable(luxury_plot_lists[quaternary])
				iNumLeftToPlace = self:PlaceSpecificNumberOfResources(res_ID, res_amt, iNumLeftToPlace, 0.5, 1, 1, 1, shuf_list);
			end
			-- Place one small source of each resource type in each region.
			local iNumThisLuxToPlace = 1;
			shuf_list = GetShuffledCopyOfTable(luxury_plot_lists[primary])
			iNumLeftToPlace = self:PlaceSpecificNumberOfResources(res_ID, res_sm, iNumThisLuxToPlace, 0.3, 1, 0, 0, shuf_list);
			if iNumLeftToPlace > 0 and secondary > 0 then
				shuf_list = GetShuffledCopyOfTable(luxury_plot_lists[secondary])
				iNumLeftToPlace = self:PlaceSpecificNumberOfResources(res_ID, res_sm, iNumLeftToPlace, 0.3, 1, 0, 0, shuf_list);
			end
			if iNumLeftToPlace > 0 and tertiary > 0 then
				shuf_list = GetShuffledCopyOfTable(luxury_plot_lists[tertiary])
				iNumLeftToPlace = self:PlaceSpecificNumberOfResources(res_ID, res_sm, iNumLeftToPlace, 0.4, 1, 0, 0, shuf_list);
			end
			if iNumLeftToPlace > 0 and quaternary > 0 then
				shuf_list = GetShuffledCopyOfTable(luxury_plot_lists[quaternary])
				iNumLeftToPlace = self:PlaceSpecificNumberOfResources(res_ID, res_sm, iNumLeftToPlace, 0.5, 1, 0, 0, shuf_list);
			end
		end
	end


	-- Place Bonus Resources
	print("Map Generation - Placing Bonuses");
	self:PlaceFish(10 * bonus_multiplier, self.coast_list);
	self:PlaceSexyBonusAtCivStarts()
	self:AddExtraBonusesToHillsRegions()

	local resources_to_place = {
	{self.deer_ID, 1, 100, 1, 2} };
	self:ProcessResourceList(8 * bonus_multiplier, 3, self.extra_deer_list, resources_to_place)

	local resources_to_place = {
	{self.wheat_ID, 1, 100, 0, 2} };
	self:ProcessResourceList(10 * bonus_multiplier, 3, self.desert_wheat_list, resources_to_place)

	local resources_to_place = {
	{self.deer_ID, 1, 100, 1, 2} };
	self:ProcessResourceList(12 * bonus_multiplier, 3, self.tundra_flat_no_feature, resources_to_place)

	local resources_to_place = {
	{self.banana_ID, 1, 100, 0, 3} };
	self:ProcessResourceList(14 * bonus_multiplier, 3, self.banana_list, resources_to_place)

	local resources_to_place = {
	{self.wheat_ID, 1, 100, 2, 3} };
	self:ProcessResourceList(27 * bonus_multiplier, 3, self.plains_flat_no_feature, resources_to_place)

	local resources_to_place = {
	{self.cow_ID, 1, 100, 1, 2} };
	self:ProcessResourceList(18 * bonus_multiplier, 3, self.grass_flat_no_feature, resources_to_place)

	local resources_to_place = {
	{self.stone_ID, 1, 100, 1, 1} };
	self:ProcessResourceList(20 * bonus_multiplier, 3, self.dry_grass_flat_no_feature, resources_to_place)

	local resources_to_place = {
	{self.sheep_ID, 1, 100, 1, 1} };
	self:ProcessResourceList(13 * bonus_multiplier, 3, self.hills_open_list, resources_to_place)

	local resources_to_place = {
	{self.stone_ID, 1, 100, 1, 2} };
	self:ProcessResourceList(15 * bonus_multiplier, 3, self.tundra_flat_no_feature, resources_to_place)

	local resources_to_place = {
	{self.stone_ID, 1, 100, 1, 2} };
	self:ProcessResourceList(19 * bonus_multiplier, 3, self.desert_flat_no_feature, resources_to_place)

	local resources_to_place = {
	{self.deer_ID, 1, 100, 3, 4} };
	self:ProcessResourceList(25 * bonus_multiplier, 3, self.forest_flat_that_are_not_tundra, resources_to_place)
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- STRATEGIC BALANCE: Horses + Iron in the capital, Coal + Aluminium nearby
------------------------------------------------------------------------------
mirror_resourceRules = nil;
MIRROR_CAPITAL_COAL = 7;			-- Coal at every capital
MIRROR_CAPITAL_ALUMINIUM = 3;		-- Aluminium at every capital
MIRROR_ARCHIPELAGO_CAPITAL_IRON = 9;	-- Mirror Archipelago only: Iron at every capital (others: the core amount) (user 11-15: 9; was 12, then 6)
ARCHIPELAGO_OIL_FACTOR = 1.5;	-- user 11-15: 60% of the 11-14 amount (2.5 was too much)
CAPITAL_EXTRA_MAX = 6;		-- user 11-15: at most 6 (4 was too weak) extra non-luxury resources within 3 of a capital
MIRROR_OWN_EXPANSION_SIZE = 16;		-- Mirror Archipelago: tiles of every own expansion island
MIRROR_SMALL_ISLAND_TILES = 20;		-- Mirror Archipelago: islands this small or smaller get more Fish
MIRROR_SMALL_COAST_PER_FISH = 4;	-- Mirror Archipelago: at least one Fish per this many coast tiles there
mirror_ownExpansionCount = 0;		-- GLOBAL own expansion islands each start island got
------------------------------------------------------------------------------
function MirrorLoadResourceRules()
	-- Which terrain / feature / plot type each resource may sit on, read from the
	-- game database at run time (so mods that change the rules are respected).
	if mirror_resourceRules ~= nil then return end
	mirror_resourceRules = {};
	for row in GameInfo.Resources() do
		mirror_resourceRules[row.ID] = {
			hills = (row.Hills == true or row.Hills == 1),
			flat = (row.Flatlands == true or row.Flatlands == 1),
			noRiver = (row.NoRiverSide == true or row.NoRiverSide == 1),
			terrain = {}, feature = {}, featureTerrain = {},
		};
	end
	for row in GameInfo.Resource_TerrainBooleans() do
		local res, terrain = GameInfo.Resources[row.ResourceType], GameInfo.Terrains[row.TerrainType];
		if res ~= nil and terrain ~= nil then
			mirror_resourceRules[res.ID].terrain[terrain.ID] = true;
		end
	end
	for row in GameInfo.Resource_FeatureBooleans() do
		local res, feature = GameInfo.Resources[row.ResourceType], GameInfo.Features[row.FeatureType];
		if res ~= nil and feature ~= nil then
			mirror_resourceRules[res.ID].feature[feature.ID] = true;
		end
	end
	for row in GameInfo.Resource_FeatureTerrainBooleans() do
		local res, terrain = GameInfo.Resources[row.ResourceType], GameInfo.Terrains[row.TerrainType];
		if res ~= nil and terrain ~= nil then
			mirror_resourceRules[res.ID].featureTerrain[terrain.ID] = true;
		end
	end
end
------------------------------------------------------------------------------
function MirrorResourceFits(plot, resID, bRespectRiver)
	-- Same rules the game uses for "can this resource be here".
	MirrorLoadResourceRules();
	local rules = mirror_resourceRules[resID];
	if rules == nil or plot:IsWater() or plot:IsMountain() then
		return false
	end
	local feature = plot:GetFeatureType();
	local terrain = plot:GetTerrainType();
	if feature ~= FeatureTypes.NO_FEATURE then
		if rules.feature[feature] ~= true or rules.featureTerrain[terrain] ~= true then
			return false
		end
	elseif rules.terrain[terrain] ~= true then
		return false
	end
	if plot:IsHills() and not rules.hills then
		return false
	end
	if plot:IsFlatlands() and not rules.flat then
		return false
	end
	if bRespectRiver and rules.noRiver and plot:IsRiverSide() then
		return false
	end
	return true
end
------------------------------------------------------------------------------
function MirrorPlanResourceFix(plot, resID)
	-- How to turn this plot into a valid spot for the resource, changing as little
	-- as possible. Returns cost (nil if not possible), new plot type, new terrain,
	-- and whether the feature has to go.
	MirrorLoadResourceRules();
	local rules = mirror_resourceRules[resID];
	local cost = 0;
	local plotType = plot:GetPlotType();
	local terrain = plot:GetTerrainType();
	local removeFeature = false;
	local feature = plot:GetFeatureType();
	if feature ~= FeatureTypes.NO_FEATURE then
		if not (rules.feature[feature] == true and rules.featureTerrain[terrain] == true) then
			if feature == FeatureTypes.FEATURE_FOREST or feature == FeatureTypes.FEATURE_JUNGLE or feature == FeatureTypes.FEATURE_MARSH then
				removeFeature = true;
				cost = cost + 1;
			else
				return nil
			end
		end
	end
	if plotType == PlotTypes.PLOT_HILLS and not rules.hills then
		if not rules.flat then return nil end
		plotType = PlotTypes.PLOT_LAND;
		cost = cost + 3;
	elseif plotType == PlotTypes.PLOT_LAND and not rules.flat then
		if not rules.hills then return nil end
		plotType = PlotTypes.PLOT_HILLS;
		cost = cost + 2;
	end
	local terrainTable = rules.terrain;
	if feature ~= FeatureTypes.NO_FEATURE and not removeFeature then
		terrainTable = rules.featureTerrain;
	end
	if terrainTable[terrain] ~= true then
		local choices = {TerrainTypes.TERRAIN_PLAINS, TerrainTypes.TERRAIN_GRASS, TerrainTypes.TERRAIN_TUNDRA, TerrainTypes.TERRAIN_DESERT};
		local newTerrain = nil;
		for loop, t in ipairs(choices) do
			if terrainTable[t] == true then
				newTerrain = t;
				break
			end
		end
		if newTerrain == nil then return nil end
		terrain = newTerrain;
		cost = cost + 2;
	end
	return cost, plotType, terrain, removeFeature;
end
------------------------------------------------------------------------------
function MirrorPlotsInRings(x, y, minRing, maxRing)
	-- West plots between minRing and maxRing tiles from (x, y), in a fixed order.
	local iW, iH = Map.GetGridSize();
	local list = {};
	for dy = -maxRing, maxRing do
		for dx = -maxRing - 1, maxRing + 1 do
			local px, py = x + dx, y + dy;
			if px >= 0 and px < iW and py >= 0 and py < iH then
				local d = Map.PlotDistance(x, y, px, py);
				local i = py * iW + px;
				if d >= minRing and d <= maxRing and mirror_kind[i] == MIRROR_WEST and not MirrorIsNoResourceIndex(i) then
					table.insert(list, Map.GetPlot(px, py));
				end
			end
		end
	end
	return list;
end
------------------------------------------------------------------------------
function MirrorEnsureResourceNear(asp, x, y, resID, amount, minRing, maxRing, preferMinRing)
	-- Makes sure a deposit of at least "amount" resID lies minRing..maxRing tiles from (x, y).
	-- Never stacks on another resource (luxuries stay), never on a start plot,
	-- natural wonder, oasis or flood plains.
	if resID == nil then return false end
	local plots = MirrorPlotsInRings(x, y, minRing, maxRing);
	-- A deposit already there counts if its tile is valid for it. (The core game's
	-- placement sometimes puts Iron in a forest; such a tile is fixed in place.)
	local best, bestInvalid = nil, nil;
	for loop, plot in ipairs(plots) do
		if plot:GetResourceType(-1) == resID then
			if MirrorResourceFits(plot, resID, false) then
				if best == nil or plot:GetNumResource() > best:GetNumResource() then
					best = plot;
				end
			elseif MirrorPlanResourceFix(plot, resID) ~= nil and not plot:IsStartingPlot() then
				if bestInvalid == nil or plot:GetNumResource() > bestInvalid:GetNumResource() then
					bestInvalid = plot;
				end
			end
		end
	end
	if best == nil and bestInvalid ~= nil then
		local cost, plotType, terrain, removeFeature = MirrorPlanResourceFix(bestInvalid, resID);
		local feature = bestInvalid:GetFeatureType();
		if removeFeature or feature == FeatureTypes.NO_FEATURE or feature == FeatureTypes.FEATURE_FOREST
			or feature == FeatureTypes.FEATURE_JUNGLE or feature == FeatureTypes.FEATURE_MARSH then
			if removeFeature then
				bestInvalid:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
			end
			if bestInvalid:GetPlotType() ~= plotType then
				bestInvalid:SetPlotType(plotType, false, false);
			end
			if bestInvalid:GetTerrainType() ~= terrain then
				bestInvalid:SetTerrainType(terrain, false, false);
			end
			best = bestInvalid;
		end
	end
	if best ~= nil then
		if best:GetNumResource() < amount then
			best:SetResourceType(resID, amount);
		end
		return true
	end
	local fits, fixable, fixCost, riverOnly, bestCost;
	local function SortCandidates(list, bAllowBonus, bAllowOil)
		fits, fixable, fixCost, riverOnly = {}, {}, {}, {};
		bestCost = 99;
		for loop, plot in ipairs(list) do
			local res = plot:GetResourceType(-1);
			local free = (res == -1);
			if bAllowBonus and res ~= -1 and GameInfo.Resources[res] ~= nil and GameInfo.Resources[res].ResourceUsage == 0 then
				free = true;	-- last resort: a bonus resource (never a luxury or strategic) makes room
			end
			if bAllowOil and res ~= -1 and GameInfo.Resources[res] ~= nil and GameInfo.Resources[res].Type == "RESOURCE_OIL" then
				free = true;	-- very last resort (tiny peninsula): Oil, which is not promised, makes room
			end
			local usable = free and not plot:IsWater() and not plot:IsMountain()
				and not plot:IsStartingPlot() and plot:GetImprovementType() == -1;
			local feature = plot:GetFeatureType();
			if usable and feature ~= FeatureTypes.NO_FEATURE then
				if feature ~= FeatureTypes.FEATURE_FOREST and feature ~= FeatureTypes.FEATURE_JUNGLE and feature ~= FeatureTypes.FEATURE_MARSH then
					usable = false;
				end
			end
			if usable then
				if MirrorResourceFits(plot, resID, true) then
					table.insert(fits, plot);
				else
					local cost = MirrorPlanResourceFix(plot, resID);
					if cost ~= nil then
						local riverBlocked = mirror_resourceRules[resID].noRiver and plot:IsRiverSide();
						if riverBlocked then
							table.insert(riverOnly, plot);
						else
							table.insert(fixable, plot);
							table.insert(fixCost, cost);
							if cost < bestCost then bestCost = cost end
						end
					elseif MirrorResourceFits(plot, resID, false) then
						table.insert(riverOnly, plot);
					end
				end
			end
		end
		return table.maxn(fits) + table.maxn(fixable) + table.maxn(riverOnly);
	end
	-- New deposits go preferably at least preferMinRing tiles out (e.g. rings 2-3).
	local found = 0;
	if preferMinRing ~= nil and preferMinRing > minRing then
		local preferred = {};
		for loop, plot in ipairs(plots) do
			if Map.PlotDistance(x, y, plot:GetX(), plot:GetY()) >= preferMinRing then
				table.insert(preferred, plot);
			end
		end
		found = SortCandidates(preferred);
	end
	if found == 0 then
		found = SortCandidates(plots);
	end
	if found == 0 then
		found = SortCandidates(plots, true);
	end
	if found == 0 then
		SortCandidates(plots, true, true);
	end
	local chosen = nil;
	if table.maxn(fits) > 0 then
		chosen = fits[1 + Map.Rand(table.maxn(fits), "Mirror Skirmish - strategic spot")];
	elseif table.maxn(fixable) > 0 then
		local cheapest = {};
		for n, plot in ipairs(fixable) do
			if fixCost[n] == bestCost then table.insert(cheapest, plot) end
		end
		chosen = cheapest[1 + Map.Rand(table.maxn(cheapest), "Mirror Skirmish - strategic spot")];
	elseif table.maxn(riverOnly) > 0 then
		chosen = riverOnly[1 + Map.Rand(table.maxn(riverOnly), "Mirror Skirmish - strategic spot")];
	end
	if chosen == nil then
		print("Mirror Skirmish WARNING: no room for resource", resID, "near start", x, y);
		return false
	end
	if chosen:GetResourceType(-1) ~= -1 then
		chosen:SetResourceType(-1, 0);
	end
	if not MirrorResourceFits(chosen, resID, false) then
		local cost, plotType, terrain, removeFeature = MirrorPlanResourceFix(chosen, resID);
		if cost ~= nil then
			if removeFeature then
				chosen:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
			end
			if chosen:GetPlotType() ~= plotType then
				chosen:SetPlotType(plotType, false, false);
			end
			if chosen:GetTerrainType() ~= terrain then
				chosen:SetTerrainType(terrain, false, false);
			end
		end
	end
	chosen:SetResourceType(resID, amount);
	if asp ~= nil then
		asp.amounts_of_resources_placed[resID + 1] = asp.amounts_of_resources_placed[resID + 1] + amount;
		asp:PlaceResourceImpact(chosen:GetX(), chosen:GetY(), 1, 0);
	end
	return true
end
------------------------------------------------------------------------------
function MirrorEnsureCapitalStrategics(asp, region_number)
	-- Horses, Iron, Coal and Aluminium all within 3 tiles of the capital.
	-- Horses and Iron are big deposits, as the core strategic balance uses;
	-- Coal 7 and Aluminium 3 (the community's numbers), placed in rings 2-3
	-- when a valid tile is there.
	local data = asp.startingPlots[region_number];
	if data == nil then return end
	local x, y = data[1], data[2];
	local uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = asp:GetMajorStrategicResourceQuantityValues();
	MirrorEnsureResourceNear(asp, x, y, asp.horse_ID, horse_amt, 1, 3);
	if MIRROR_VARIANT == "archipelago" then iron_amt = MIRROR_ARCHIPELAGO_CAPITAL_IRON end
	MirrorEnsureResourceNear(asp, x, y, asp.iron_ID, iron_amt, 1, 3);
	MirrorEnsureResourceNear(asp, x, y, asp.coal_ID, MIRROR_CAPITAL_COAL, 1, 3, 2);
	MirrorEnsureResourceNear(asp, x, y, asp.aluminum_ID, MIRROR_CAPITAL_ALUMINIUM, 1, 3, 2);
end
------------------------------------------------------------------------------
MirrorBase_AddStrategicBalanceResources = AssignStartingPlots.AddStrategicBalanceResources;
function AssignStartingPlots:AddStrategicBalanceResources(region_number)
	-- The core game adds Iron, Horses and Oil here. Mirror Skirmish then checks
	-- Horses and Iron really are inside the capital and adds Coal and Aluminium.
	MirrorBase_AddStrategicBalanceResources(self, region_number);
	MirrorEnsureCapitalStrategics(self, region_number);
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- NATURAL WONDERS (west half only, then mirrored)
------------------------------------------------------------------------------
function AssignStartingPlots:PlaceNaturalWonders()
	-- Wonders go on the west half only, at least two tiles from the strip; the
	-- mirror copy gives the east the same wonder. Half the usual number is
	-- placed, so the map ends up with about the usual total.
	-- The Great Barrier Reef is two tiles in a fixed direction, so a mirrored copy
	-- would be malformed: it is left out.
	local iW, iH = Map.GetGridSize();
	for i = 0, iW * iH - 1 do
		if mirror_kind[i] ~= MIRROR_WEST or mirror_axisDist[i] <= mirror_stripHalf + 1.01 then
			self.naturalWondersData[i + 1] = 99;
		end
	end

	local NW_eligibility_order_all = self:GenerateNaturalWondersCandidatePlotLists()
	local NW_eligibility_order = {};
	for loop, nw_number in ipairs(NW_eligibility_order_all) do
		-- no El Dorado on mirror maps (user, 11-14)
		if self.wonder_list[nw_number] ~= "FEATURE_REEF" and self.wonder_list[nw_number] ~= "FEATURE_EL_DORADO" then
			table.insert(NW_eligibility_order, nw_number);
		end
	end
	local iNumNWCandidates = table.maxn(NW_eligibility_order);
	if iNumNWCandidates == 0 then
		print("No Natural Wonders placed, no eligible sites found for any of them.");
		return
	end

	-- Determine how many NWs to attempt to place. Target is regulated per map size.
	-- The final number cannot exceed the number the map has locations to support.
	local worldsizes = {
		[GameInfo.Worlds.WORLDSIZE_DUEL.ID] = 2,
		[GameInfo.Worlds.WORLDSIZE_TINY.ID] = 3,
		[GameInfo.Worlds.WORLDSIZE_SMALL.ID] = 4,
		[GameInfo.Worlds.WORLDSIZE_STANDARD.ID] = 5,
		[GameInfo.Worlds.WORLDSIZE_LARGE.ID] = 6,
		[GameInfo.Worlds.WORLDSIZE_HUGE.ID] = 7
		}
	local target_number = math.ceil((worldsizes[Map.GetWorldSize()] or 2) / 2);
	local iNumNWtoPlace = math.min(target_number, iNumNWCandidates);
	local selected_NWs, fallback_NWs = {}, {};
	for loop, NW in ipairs(NW_eligibility_order) do
		if loop <= iNumNWtoPlace then
			table.insert(selected_NWs, NW);
		else
			table.insert(fallback_NWs, NW);
		end
	end

	-- Place the NWs
	local iNumPlaced = 0;
	for loop, nw_number in ipairs(selected_NWs) do
		local nw_type = self.wonder_list[nw_number];
		-- Obtain the correct Row number from the xml Placement table.
		local row_number;
		for row in GameInfo.Natural_Wonder_Placement() do
			if row.NaturalWonderType == nw_type then
				row_number = row.ID;
			end
		end
		-- Place the wonder, using the correct row data from XML.
		local bSuccess = self:AttemptToPlaceNaturalWonder(nw_number, row_number)
		if bSuccess then
			iNumPlaced = iNumPlaced + 1;
		end
	end
	if iNumPlaced < iNumNWtoPlace then
		for loop, nw_number in ipairs(fallback_NWs) do
			if iNumPlaced >= iNumNWtoPlace then
				break
			end
			local nw_type = self.wonder_list[nw_number];
			-- Obtain the correct Row number from the xml Placement table.
			local row_number;
			for row in GameInfo.Natural_Wonder_Placement() do
				if row.NaturalWonderType == nw_type then
					row_number = row.ID;
				end
			end
			-- Place the wonder, using the correct row data from XML.
			local bSuccess = self:AttemptToPlaceNaturalWonder(nw_number, row_number)
			if bSuccess then
				iNumPlaced = iNumPlaced + 1;
			end
		end
	end
	print("Mirror Skirmish: natural wonders placed in the west:", iNumPlaced);

	-- Give the east the same wonders (and the tile changes they made).
	MirrorWholeMap(false);
	-- The east copies must keep resources and city states away, like the originals.
	for i = 0, iW * iH - 1 do
		if mirror_kind[i] == MIRROR_WEST then
			local plot = Map.GetPlotByIndex(i);
			local feature = plot:GetFeatureType();
			if feature ~= FeatureTypes.NO_FEATURE and GameInfo.Features[feature] ~= nil and GameInfo.Features[feature].NaturalWonder then
				local twin = Map.GetPlotByIndex(mirror_twin[i]);
				local tx, ty = twin:GetX(), twin:GetY();
				self:PlaceResourceImpact(tx, ty, 1, 1)
				self:PlaceResourceImpact(tx, ty, 2, 1)
				self:PlaceResourceImpact(tx, ty, 3, 1)
				self:PlaceResourceImpact(tx, ty, 5, 1)
				self:PlaceResourceImpact(tx, ty, 7, 1)
				self.playerCollisionData[ty * iW + tx + 1] = true;
			end
		end
	end
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- CITY STATES (west half, then mirrored; an odd one sits on the centre line)
------------------------------------------------------------------------------
function MirrorRecordCityState(asp, cs_number, x, y, region_number)
	-- Same bookkeeping the core game does for a placed city state.
	local iW, iH = Map.GetGridSize();
	asp.cityStatePlots[cs_number] = {x, y, region_number};
	asp.city_state_validity_table[cs_number] = true;
	asp.city_state_region_assignments[cs_number] = region_number;
	local city_state_ID = cs_number + GameDefines.MAX_MAJOR_CIVS - 1;
	local cityState = Players[city_state_ID];
	cityState:SetStartingPlot(Map.GetPlot(x, y))
	asp:GenerateLuxuryPlotListsAtCitySite(x, y, 1, true) -- Removes Feature Ice from coasts adjacent to the city state's new location
	asp:PlaceResourceImpact(x, y, 5, 4) -- City State layer
	asp:PlaceResourceImpact(x, y, 2, 3) -- Luxury layer
	asp:PlaceResourceImpact(x, y, 1, 0) -- Strategic layer, at start point only.
	asp:PlaceResourceImpact(x, y, 3, 3) -- Bonus layer
	asp:PlaceResourceImpact(x, y, 4, 3) -- Fish layer
	asp:PlaceResourceImpact(x, y, 7, 3) -- Marble layer
	asp.playerCollisionData[y * iW + x + 1] = true;
end
------------------------------------------------------------------------------
function MirrorPlaceAxisCityState(asp, cs_number)
	-- An odd number of city states: the extra one sits on the centre line, on a
	-- plot that is its own mirror image (odd rows only), near the middle row,
	-- as far from the capitals as possible.
	local iW, iH = Map.GetGridSize();
	local axisX = (iW - 2) / 2;
	local bestY, bestScore = -1, -999;
	local mid = (iH - 1) / 2;
	for y = 1, iH - 2, 2 do
		-- Only rows in the middle half of the map.
		if math.abs(y - mid) <= iH / 4 then
			local score = 99;
			for loop, data in ipairs(asp.startingPlots) do
				score = math.min(score, Map.PlotDistance(axisX, y, data[1], data[2]));
			end
			-- Up to 7 tiles from the nearest capital counts; past that, closer to the middle wins.
			local weighted = math.min(score, 7) * 100 - math.abs(y - mid);
			-- Prefer a spot on the continent, and (no strip) one that already is good flat land.
			local i = y * iW + axisX;
			if mirror_continent[i] == true then
				weighted = weighted + 2000;
			end
			local plot = Map.GetPlot(axisX, y);
			if mirror_stripType == 0 and not plot:IsWater() and not plot:IsMountain() and plot:GetTerrainType() ~= TerrainTypes.TERRAIN_SNOW then
				weighted = weighted + 1000;
			end
			if weighted > bestScore then
				bestScore, bestY = weighted, y;
			end
		end
	end
	mirror_axisCityIndex = bestY * iW + axisX;
	-- A mountain strip gets a pass through the city state's row, so it can be reached.
	if mirror_stripType == 3 then
		mirror_passRows[bestY] = true;
	end
	MirrorApplyStrip();
	MirrorRecordCityState(asp, cs_number, axisX, bestY, -1);
	print("Mirror Skirmish: city state", cs_number, "placed on the centre line at", axisX, bestY);
end
------------------------------------------------------------------------------
function MirrorTryPlaceWestCityState(asp, cs_number, region_number)
	-- Ring (as Ring.lua): city states go to the polar centre first; anywhere else only if it is full.
	if mirror_landmass == 5 then
		mirror_ringCentreOnly = true;
		local bPlaced = MirrorTryPlaceWestCityStateInner(asp, cs_number, region_number);
		mirror_ringCentreOnly = false;
		if bPlaced then return true end
	end
	return MirrorTryPlaceWestCityStateInner(asp, cs_number, region_number);
end
function MirrorTryPlaceWestCityStateInner(asp, cs_number, region_number)
	-- Tries the given west region first, then every west region, then any free west plot.
	local k = asp.mirror_k;
	asp:PlaceCityStateInRegion(cs_number, region_number);
	if asp.city_state_validity_table[cs_number] == true then return true end
	for r = 1, k do
		if r ~= region_number then
			asp:PlaceCityStateInRegion(cs_number, r);
			if asp.city_state_validity_table[cs_number] == true then return true end
		end
	end
	-- Last chance: any west plot, first respecting city state spacing, then not.
	local iW, iH = Map.GetGridSize();
	for pass = 1, 3 do
		local force_it = (pass >= 2);
		mirror_csAnyDistance = (pass == 3);	-- only when there is no room 5 tiles from every capital
		local candidates = {};
		for i = 0, iW * iH - 1 do
			if mirror_kind[i] == MIRROR_WEST then
				local x, y = i % iW, math.floor(i / iW);
				if MirrorTwinDistance(x, y) >= 6 and asp:CanPlaceCityStateAt(x, y, -1, force_it, false) then
					table.insert(candidates, i);
				end
			end
		end
		if table.maxn(candidates) > 0 then
			mirror_csAnyDistance = false;
			local i = candidates[1 + Map.Rand(table.maxn(candidates), "Mirror Skirmish - city state last chance")];
			MirrorRecordCityState(asp, cs_number, i % iW, math.floor(i / iW), region_number);
			return true
		end
	end
	mirror_csAnyDistance = false;
	return false
end
------------------------------------------------------------------------------
function MirrorCityStateTrait(cs_number)
	-- The city state's type (maritime, cultured, mercantile, militaristic,
	-- religious), as a MinorCivTraits ID, or -1 if it cannot be read.
	local player_ID = cs_number + GameDefines.MAX_MAJOR_CIVS - 1;
	local player = Players[player_ID];
	if player ~= nil and player.GetMinorCivTrait ~= nil then
		local ok, trait = pcall(function() return player:GetMinorCivTrait() end);
		if ok and trait ~= nil and trait >= 0 then
			return trait;
		end
	end
	if PreGame ~= nil and PreGame.GetMinorCivType ~= nil then
		local ok, minorType = pcall(function() return PreGame.GetMinorCivType(player_ID) end);
		if ok and minorType ~= nil and minorType >= 0 then
			local row = GameInfo.MinorCivilizations[minorType];
			if row ~= nil and row.MinorCivTrait ~= nil and GameInfo.MinorCivTraits[row.MinorCivTrait] ~= nil then
				return GameInfo.MinorCivTraits[row.MinorCivTrait].ID;
			end
		end
	end
	return -1;
end
------------------------------------------------------------------------------
function MirrorPairCityStates(iNumCityStates)
	-- Mirror pairs of the same type where possible. Returns a list of
	-- {west, east} city state numbers and the one for the centre line (or nil).
	-- Leftovers (odd counts of a type) go to the centre line first, then are
	-- paired with each other.
	local traitOrder, byTrait = {}, {};
	for cs_number = 1, iNumCityStates do
		local trait = MirrorCityStateTrait(cs_number);
		if byTrait[trait] == nil then
			byTrait[trait] = {};
			table.insert(traitOrder, trait);
		end
		table.insert(byTrait[trait], cs_number);
	end
	table.sort(traitOrder);
	local pairs_list, leftovers = {}, {};
	for loop, trait in ipairs(traitOrder) do
		local list = byTrait[trait];
		local n = table.maxn(list);
		for m = 1, n - 1, 2 do
			table.insert(pairs_list, {list[m], list[m + 1]});
		end
		if n % 2 == 1 then
			table.insert(leftovers, list[n]);
		end
	end
	local centre = nil;
	if iNumCityStates % 2 == 1 then
		centre = table.remove(leftovers, 1);
	end
	for m = 1, table.maxn(leftovers) - 1, 2 do
		print("Mirror Skirmish: city states", leftovers[m], leftovers[m + 1], "are a mirror pair of different types (no same-type partner left).");
		table.insert(pairs_list, {leftovers[m], leftovers[m + 1]});
	end
	return pairs_list, centre;
end
------------------------------------------------------------------------------
function AssignStartingPlots:PlaceCityStates()
	print("Map Generation - Choosing sites for City States (Mirror Skirmish)");
	-- City states come in mirror pairs of the same type: one in the west, its
	-- twin on the exact mirror plot in the east. An odd one sits on the centre line.
	local iW, iH = Map.GetGridSize();
	local k = self.mirror_k;
	local pairs_list, centre = MirrorPairCityStates(self.iNumCityStates);
	local iNumPairs = table.maxn(pairs_list);
	mirror_cityStatePairs = pairs_list;	-- GLOBAL, for logs and tests

	if centre ~= nil then
		MirrorPlaceAxisCityState(self, centre);
	end

	-- Keep west city states far enough from the centre line that the twin is not too close.
	for i = 0, iW * iH - 1 do
		if mirror_kind[i] == MIRROR_WEST then
			local x, y = i % iW, math.floor(i / iW);
			if MirrorTwinDistance(x, y) <= 5 then
				self.cityStateData[i + 1] = math.max(self.cityStateData[i + 1], 1);
			end
		end
	end

	-- Hand the pairs out to the west regions, poorest regions first.
	local order = {};
	for r = 1, k do table.insert(order, r) end
	table.sort(order, function(a, b)
		local fa, fb = self.regionData[a][8], self.regionData[b][8];
		if fa ~= fb then return fa < fb end
		return a < b
	end);
	for n = 1, iNumPairs do
		local west_cs, east_cs = pairs_list[n][1], pairs_list[n][2];
		local region_number = order[((n - 1) % k) + 1];
		local bPlaced = MirrorTryPlaceWestCityState(self, west_cs, region_number);
		if bPlaced then
			local data = self.cityStatePlots[west_cs];
			local twinX = MirrorTwinX(data[1], data[2]);
			local twinRegion = -1;
			if data[3] ~= nil and data[3] > 0 then twinRegion = data[3] + k end
			self.city_state_region_assignments[west_cs] = data[3];
			MirrorRecordCityState(self, east_cs, twinX, data[2], twinRegion);
		else
			print("Mirror Skirmish WARNING: no room for city state pair", west_cs, east_cs, "- both left out.");
			self.iNumCityStatesDiscarded = self.iNumCityStatesDiscarded + 2;
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:NormalizeCityStateLocations()
	-- Only the west and centre-line city states; the east twins are copied.
	local iW, iH = Map.GetGridSize();
	for city_state, data_table in ipairs(self.cityStatePlots) do
		if self.city_state_validity_table[city_state] == true then
			local x = data_table[1];
			local y = data_table[2];
			if mirror_kind[y * iW + x] ~= MIRROR_EAST then
				self:NormalizeCityState(x, y)
			end
		end
	end
end
------------------------------------------------------------------------------
function MirrorFilterPlotList(list, bWestOnly)
	-- Removes strip and lone plots (and, if asked, all non-west plots) from a
	-- list of plot indices (1-based), keeping the order. Works in place, because
	-- the same list tables are shared by several lookups.
	if list == nil then return end
	local kept = {};
	for loop, plotIndex in ipairs(list) do
		local kind = mirror_kind[plotIndex - 1];
		if not MirrorIsNoResourceIndex(plotIndex - 1) and (not bWestOnly or kind == MIRROR_WEST) then
			table.insert(kept, plotIndex);
		end
	end
	local n = table.maxn(list);
	for loop = 1, n do
		list[loop] = kept[loop];
	end
end
------------------------------------------------------------------------------
MirrorBase_GenerateGlobalResourcePlotLists = AssignStartingPlots.GenerateGlobalResourcePlotLists;
function AssignStartingPlots:GenerateGlobalResourcePlotLists()
	MirrorBase_GenerateGlobalResourcePlotLists(self);
	local names = {"coast_next_to_land_list", "marsh_list", "flood_plains_list", "hills_open_list",
		"hills_covered_list", "hills_jungle_list", "hills_forest_list", "jungle_flat_list", "forest_flat_list",
		"desert_flat_no_feature", "plains_flat_no_feature", "dry_grass_flat_no_feature",
		"fresh_water_grass_flat_no_feature", "tundra_flat_including_forests", "forest_flat_that_are_not_tundra",
		"grass_flat_no_feature", "tundra_flat_no_feature", "snow_flat_list", "hills_list", "land_list",
		"coast_list", "marble_list", "extra_deer_list", "desert_wheat_list", "banana_list"};
	for loop, name in ipairs(names) do
		MirrorFilterPlotList(self[name], false);
	end
end
------------------------------------------------------------------------------
MirrorBase_GenerateLuxuryPlotListsAtCitySite = AssignStartingPlots.GenerateLuxuryPlotListsAtCitySite;
function AssignStartingPlots:GenerateLuxuryPlotListsAtCitySite(x, y, radius, bRemoveFeatureIce)
	local lists = MirrorBase_GenerateLuxuryPlotListsAtCitySite(self, x, y, radius, bRemoveFeatureIce);
	-- Nothing on the strip. For the centre-line city state, only west plots: the
	-- final mirror then gives it the same thing on its east side.
	local iW, iH = Map.GetGridSize();
	local bWestOnly = (y * iW + x == mirror_axisCityIndex);
	if lists ~= nil then
		for loop, list in ipairs(lists) do
			MirrorFilterPlotList(list, bWestOnly);
		end
	end
	return lists;
end
------------------------------------------------------------------------------
function AssignStartingPlots:PlaceResourcesAndCityStates()
	-- The core game's order of operations, plus the mirror copy at the end.
	print("Map Generation - Assigning Luxury Resource Distribution");
	self:AssignLuxuryRoles()

	print("Map Generation - Placing City States");
	self:PlaceCityStates()

	-- Generate global plot lists for resource distribution.
	self:GenerateGlobalResourcePlotLists()

	print("Map Generation - Placing Luxuries");
	self:PlaceLuxuries()

	-- Place Strategic and Bonus resources.
	self:PlaceStrategicAndBonusResources()

	print("Map Generation - Normalize City State Locations");
	self:NormalizeCityStateLocations()

	-- Fix Sugar graphics
	self:FixSugarJungles()

	-- Pangaea: the middle as rich as the rest of the land (user: "fill the middle").
	if mirror_landmass == 2 then
		MirrorFillMiddle(self);
		MirrorCentreLine(self);
	end

	-- Archipelago: more Fish at small islands, some islands rich, some poor.
	MirrorIslandFish(self);
	if mirror_landmass == 3 then MirrorIslandScaling(self) end

	-- Archipelago: every capital gets its regional luxury, 2 at home and 3 on the islands around (user).
	if mirror_landmass == 3 then
		MirrorRegionLuxuryAtCapitals(self, self.mirror_k);
	end

	-- Archipelago: 3-5 bonus resources at every capital, not more (user).
	if mirror_landmass == 3 then
		MirrorCapitalBonusCap(self, self.mirror_k);
		MirrorCapitalLuxuries(self, self.mirror_k);
	end

	-- Archipelago: no city site with more than a handful of Fish (user).
	if mirror_landmass == 3 then
		MirrorFishCityCap(self, self.mirror_k, ({3, 4, 5, 5, 5, 6, 7})[MirrorOpt("seaamount", 3)] or 5);
	end

	-- Archipelago: more Oil, one on every home island and one at sea (user).
	if mirror_landmass == 3 then MirrorMoreOil(self, self.mirror_k, ARCHIPELAGO_OIL_FACTOR) end
	-- City states richer (west side; the mirror copies them east).
	MirrorCityStateBoost(self);

	-- Strategic balance once more, now that everything else is placed.
	for region_number = 1, self.mirror_k do
		MirrorEnsureCapitalStrategics(self, region_number);
	end

	-- Copy the west onto the east: resources, city state surroundings, everything.
	MirrorWholeMap(false);

	-- Necessary to implement placement of Natural Wonders, and possibly other plot-type changes.
	-- This operation must be saved for last, as it invalidates all regional data by resetting Area IDs.
	Map.RecalculateAreas();

	-- Activate for debug only
	self:PrintFinalResourceTotalsToLog()
end
------------------------------------------------------------------------------
function StartPlotSystem()
	-- Custom for Mirror Skirmish.
	print("Creating start plot database.");
	local start_plot_database = AssignStartingPlots.Create()
	mirror_startPlotDatabase = start_plot_database;	-- GLOBAL, used by the last mirror pass

	print("Dividing the map in to Regions.");
	start_plot_database:GenerateRegions()

	print("Choosing start locations for civilizations.");
	start_plot_database:ChooseLocations()

	print("Normalizing start locations and assigning them to Players.");
	start_plot_database:BalanceAndAssign()

	print("Placing Natural Wonders.");
	start_plot_database:PlaceNaturalWonders()

	print("Placing Resources and City States.");
	start_plot_database:PlaceResourcesAndCityStates()
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- RUINS (goody huts): none on the strip, the lone plots or the centre line; the west ones are mirrored.
------------------------------------------------------------------------------
MirrorBase_CanPlaceGoodyAt = CanPlaceGoodyAt;
function CanPlaceGoodyAt(improvement, plot)
	local iW, iH = Map.GetGridSize();
	if MirrorIsNoSiteIndex(plot:GetY() * iW + plot:GetX()) then
		return false
	end
	return MirrorBase_CanPlaceGoodyAt(improvement, plot);
end
------------------------------------------------------------------------------
function MirrorFinalPass()
	-- The very last copy: whatever happened on the east side is replaced by the
	-- mirror of the west, so no random difference survives anywhere.
	if mirror_startPlotDatabase ~= nil then
		for region_number = 1, mirror_startPlotDatabase.mirror_k do
			MirrorEnsureCapitalStrategics(mirror_startPlotDatabase, region_number);
		end
		if mirror_landmass == 3 then MirrorCapitalExtraCap(mirror_startPlotDatabase, mirror_startPlotDatabase.mirror_k, math.max(CAPITAL_EXTRA_MAX, (CAPITAL_FOOD_WANT or 0) + 1)) end
	end
	MirrorWholeMap(true);
	Map.RecalculateAreas();
end
------------------------------------------------------------------------------
function GenerateMap()
	print("Generating Map (Mirror Skirmish)");
	MirrorInit();

	-- Plot types (land, hills, mountains, lakes), mirrored, with the strip.
	GeneratePlotTypes();

	-- Terrain, mirrored.
	GenerateTerrain();

	Map.RecalculateAreas();

	-- Rivers, mirrored.
	AddRivers();

	AddLakes();

	-- Features, mirrored.
	AddFeatures();

	Map.RecalculateAreas();

	-- Starts, natural wonders, city states and resources, all mirrored.
	StartPlotSystem();

	-- Ruins: placed by the core game, west ones mirrored in the final pass.
	AddGoodies();

	KekJungleOnPlains();
	MirrorFinalPass();

	DetermineContinents();
	MirrorContinentArt();
end
------------------------------------------------------------------------------
------------------------------------------------------------------------------
function MirrorCityStateBoost(asp)
	-- City states worth taking (user, 11-14): within 2 tiles every city state
	-- gets at least 3 food bonus (land bonus or Fish) and within 3 tiles at
	-- least 2 luxuries (land, or Whales/Pearls/Crab on the coast).
	if asp.cityStatePlots == nil then return end
	MirrorLoadResourceRules();
	local iW, iH = Map.GetGridSize();
	local fish = GameInfo.Resources["RESOURCE_FISH"];
	local landLux, seaLux, onMap = {}, {}, {};
	for i = 0, iW * iH - 1 do
		local r = Map.GetPlotByIndex(i):GetResourceType(-1);
		if r ~= -1 then onMap[r] = true end
	end
	for row in GameInfo.Resources() do
		if row.ResourceClassType == "RESOURCECLASS_LUXURY" and onMap[row.ID] then
			local rules = mirror_resourceRules[row.ID];
			local water = false;
			if rules ~= nil then
				for t, ok in pairs(rules.terrain) do
					if ok and (t == TerrainTypes.TERRAIN_COAST or t == TerrainTypes.TERRAIN_OCEAN) then water = true end
				end
			end
			if water then table.insert(seaLux, row.ID) else table.insert(landLux, row.ID) end
		end
	end
	local function OK(plot)
		local i = plot:GetY() * iW + plot:GetX();
		return mirror_kind[i] == MIRROR_WEST and not MirrorIsNoResourceIndex(i);
	end
	local function Kind(res)
		if res == -1 or GameInfo.Resources[res] == nil then return nil end
		local u = GameInfo.Resources[res].ResourceUsage;
		if u == 0 then return "bonus" elseif u == 2 then return "lux" end
		return "strategic";
	end
	local log = {cs = 0, food = 0, lux = 0};
	for cs_number, data in pairs(asp.cityStatePlots) do
		local x, y = data[1], data[2];
		local csPlot = (x ~= nil and y ~= nil) and Map.GetPlot(x, y) or nil;
		if csPlot ~= nil and not csPlot:IsWater() and mirror_kind[y * iW + x] ~= MIRROR_EAST then
			log.cs = log.cs + 1;
			local food, lux, freeLand2, freeSea2, freeLand3, freeSea3 = 0, 0, {}, {}, {}, {};
			for loop, plot in ipairs(MirrorPlotsInRings(x, y, 1, 3)) do
				if OK(plot) then
					local d = Map.PlotDistance(x, y, plot:GetX(), plot:GetY());
					local k = Kind(plot:GetResourceType(-1));
					if k == "bonus" and d <= 2 then food = food + 1 end
					if k == "lux" then lux = lux + 1 end
					if k == nil and plot:GetImprovementType() == -1 and not plot:IsMountain() then
						if plot:IsWater() then
							if not plot:IsLake() and plot:GetFeatureType() == FeatureTypes.NO_FEATURE then
								table.insert(freeSea3, plot);
								if d <= 2 then table.insert(freeSea2, plot) end
							end
						else
							table.insert(freeLand3, plot);
							if d <= 2 then table.insert(freeLand2, plot) end
						end
					end
				end
			end
			local function Take(list, test)
				for tries = 1, table.maxn(list) do
					local n = 1 + Map.Rand(table.maxn(list), "City state boost - spot");
					local plot = list[n];
					if plot:GetResourceType(-1) == -1 and test(plot) then
						table.remove(list, n);
						return plot
					end
				end
				return nil
			end
			-- food: Fish on the coast first (city states are mostly coastal), then land bonus
			local tries = 0;
			while food < 3 and tries < 8 do
				tries = tries + 1;
				local placed = false;
				if fish ~= nil and table.maxn(freeSea2) > 0 then
					local p = Take(freeSea2, function(p) return mirror_resourceRules[fish.ID].terrain[p:GetTerrainType()] == true end);
					if p ~= nil then p:SetResourceType(fish.ID, 1); placed = true end
				end
				if not placed and table.maxn(freeLand2) > 0 then
					local p = freeLand2[1 + Map.Rand(table.maxn(freeLand2), "City state boost - land bonus")];
					if p:GetResourceType(-1) == -1 and asp:AttemptToPlaceBonusResourceAtPlot(p:GetX(), p:GetY(), false) then placed = true end
				end
				if placed then food = food + 1; log.food = log.food + 1 end
			end
			-- luxuries: a land luxury that fits, else a sea luxury
			tries = 0;
			while lux < 2 and tries < 10 do
				tries = tries + 1;
				local placed = false;
				if table.maxn(landLux) > 0 and table.maxn(freeLand3) > 0 then
					local id = landLux[1 + Map.Rand(table.maxn(landLux), "City state boost - luxury")];
					local p = Take(freeLand3, function(p) return MirrorResourceFits(p, id, false) end);
					if p ~= nil then p:SetResourceType(id, 1); placed = true end
				end
				if not placed and table.maxn(seaLux) > 0 and table.maxn(freeSea3) > 0 then
					local id = seaLux[1 + Map.Rand(table.maxn(seaLux), "City state boost - sea luxury")];
					local p = Take(freeSea3, function(p) return mirror_resourceRules[id].terrain[p:GetTerrainType()] == true end);
					if p ~= nil then p:SetResourceType(id, 1); placed = true end
				end
				if placed then lux = lux + 1; log.lux = log.lux + 1 end
			end
		end
	end
	print("City state boost: city states", log.cs, "food bonus +", log.food, "luxuries +", log.lux);
end
------------------------------------------------------------------------------
MIRROR_REGION_LUX_HOME = 2;		-- copies of its regional luxury on the start island, within 3 tiles (user)
MIRROR_REGION_LUX_AROUND = 3;		-- copies on the islands around it, 4-8 tiles away, nearer to it than to anyone else
function MirrorRegionLuxuryAtCapitals(asp, nRegions)
	-- Every capital's regional luxury, spread out (user): exactly HOME copies on
	-- its own start island within 3 tiles, and AROUND copies on other islands
	-- nearby (4-8 tiles, closer to this capital than to any other, never on
	-- another start island). If too few tiles fit, a tile gets the feature, the
	-- terrain or the hill the luxury needs.
	MirrorLoadResourceRules();
	local iW, iH = Map.GetGridSize();
	local log = {added = 0, removed = 0, short = 0};
	local capitals, capitalArea = {}, {};
	for r = 1, nRegions do
		local data = asp.startingPlots[r];
		if data ~= nil then
			table.insert(capitals, {data[1], data[2]});
			capitalArea[Map.GetPlot(data[1], data[2]):GetArea()] = true;
		end
	end
	if asp.mirror_k ~= nil then
		-- mirror maps: the east twins count as capitals too
		for r = 1, nRegions do
			local data = asp.startingPlots[asp.mirror_k + r];
			if data ~= nil and Map.GetPlot(data[1], data[2]) ~= nil then
				table.insert(capitals, {data[1], data[2]});
				capitalArea[Map.GetPlot(data[1], data[2]):GetArea()] = true;
			end
		end
	end
	for r = 1, nRegions do
		local data = asp.startingPlots[r];
		local lux = asp.region_luxury_assignment and asp.region_luxury_assignment[r];
		local rules = lux and mirror_resourceRules[lux];
		if data ~= nil and rules ~= nil then
			local x, y = data[1], data[2];
			local homeArea = Map.GetPlot(x, y):GetArea();
			local function Mine(plot)
				-- nearer to this capital than to any other
				local d = Map.PlotDistance(x, y, plot:GetX(), plot:GetY());
				for loop, c in ipairs(capitals) do
					if (c[1] ~= x or c[2] ~= y) and Map.PlotDistance(c[1], c[2], plot:GetX(), plot:GetY()) <= d then return false end
				end
				return true
			end
			local function Fits(plot)
				if plot:IsWater() then
					return rules.terrain[plot:GetTerrainType()] == true and plot:GetFeatureType() == FeatureTypes.NO_FEATURE
				end
				return MirrorResourceFits(plot, lux, false)
			end
			local function MakeFit(plot)
				-- a land tile that would fit with the right feature: give it that feature
				if plot:IsWater() or plot:GetFeatureType() ~= FeatureTypes.NO_FEATURE then return false end
				if plot:IsHills() and not rules.hills then return false end
				if plot:IsFlatlands() and not rules.flat then return false end
				for f, ok in pairs(rules.feature) do
					if ok and rules.featureTerrain[plot:GetTerrainType()] == true then
						plot:SetFeatureType(f, -1);
						if MirrorResourceFits(plot, lux, false) then return true end
						plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
					end
				end
				return false
			end
			local function MakeTerrainFit(plot)
				-- last resort: a land tile gets the terrain / hill the luxury needs
				if plot:IsWater() then return false end
				local oldType, oldT, oldF = plot:GetPlotType(), plot:GetTerrainType(), plot:GetFeatureType();
				if plot:IsFlatlands() and not rules.flat and rules.hills then
					plot:SetPlotType(PlotTypes.PLOT_HILLS, false, false);
				elseif plot:IsHills() and not rules.hills and rules.flat then
					plot:SetPlotType(PlotTypes.PLOT_LAND, false, false);
				end
				if MirrorResourceFits(plot, lux, false) then return true end
				for t, ok in pairs(rules.terrain) do
					if ok and t ~= TerrainTypes.TERRAIN_SNOW and t ~= TerrainTypes.TERRAIN_COAST and t ~= TerrainTypes.TERRAIN_OCEAN then
						plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
						plot:SetTerrainType(t, false, true);
						if MirrorResourceFits(plot, lux, false) then return true end
					end
				end
				for f, ok in pairs(rules.feature) do
					if ok then
						for t, ok2 in pairs(rules.featureTerrain) do
							if ok2 and t ~= TerrainTypes.TERRAIN_SNOW then
								plot:SetTerrainType(t, false, true);
								plot:SetFeatureType(f, -1);
								if MirrorResourceFits(plot, lux, false) then return true end
							end
						end
					end
				end
				plot:SetTerrainType(oldT, false, true);
				plot:SetFeatureType(oldF, -1);
				if plot:GetPlotType() ~= oldType then plot:SetPlotType(oldType, false, false) end
				return false
			end
			-- Bring the copies in "have" up (or down) to "want", from the free tiles.
			local function Fill(have, free, want, label)
				while table.maxn(have) > want do
					local plot = table.remove(have, 1 + Map.Rand(table.maxn(have), "Region luxury - trim"));
					plot:SetResourceType(-1, 0);
					log.removed = log.removed + 1;
				end
				local n = table.maxn(have);
				for pass = 1, 3 do
					local tries = 0;
					while n < want and table.maxn(free) > 0 and tries < 300 do
						tries = tries + 1;
						local k = 1 + Map.Rand(table.maxn(free), "Region luxury - spot");
						local plot = free[k];
						if plot:GetResourceType(-1) ~= -1 then
							table.remove(free, k);
						elseif (pass == 1 and Fits(plot)) or (pass == 2 and MakeFit(plot)) or (pass == 3 and MakeTerrainFit(plot)) then
							table.remove(free, k);
							plot:SetResourceType(lux, 1);
							n = n + 1;
							log.added = log.added + 1;
						end
					end
				end
				if n < want then
					if label == "around" then log.short = log.short + 1 end
					print("Region luxury short:", label, "region", r, GameInfo.Resources[lux].Type, "has", n, "of", want);
				end
				return n;
			end
			-- 1. home: own start island, within 3 tiles
			local have, free = {}, {};
			for loop, plot in ipairs(MirrorPlotsInRings(x, y, 1, 3)) do
				local i = plot:GetY() * iW + plot:GetX();
				if mirror_kind[i] == MIRROR_WEST and not MirrorIsNoResourceIndex(i) and (plot:IsWater() or plot:GetArea() == homeArea) then
					local res = plot:GetResourceType(-1);
					if res == lux then
						table.insert(have, plot);
					elseif res == -1 and plot:GetImprovementType() == -1 and not plot:IsMountain() and not plot:IsLake() then
						table.insert(free, plot);
					end
				end
			end
			local nHome = Fill(have, free, MIRROR_REGION_LUX_HOME, "home");
			-- 2. around: other islands (and their coast) 4-8 tiles away, nearer to this capital
			have, free = {}, {};
			for loop, plot in ipairs(MirrorPlotsInRings(x, y, 4, 8)) do
				local i = plot:GetY() * iW + plot:GetX();
				if mirror_kind[i] == MIRROR_WEST and not MirrorIsNoResourceIndex(i) and Mine(plot) and not plot:IsLake() then
					local onOther = not plot:IsWater() and not capitalArea[plot:GetArea()];
					local coastOfOther = false;
					if plot:IsWater() then
						for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
							local adj = Map.PlotDirection(plot:GetX(), plot:GetY(), direction);
							if adj ~= nil and not adj:IsWater() and not capitalArea[adj:GetArea()] then coastOfOther = true end
						end
					end
					if onOther or coastOfOther then
						local res = plot:GetResourceType(-1);
						if res == lux then
							table.insert(have, plot);
						elseif res == -1 and plot:GetImprovementType() == -1 and not plot:IsMountain() then
							table.insert(free, plot);
						end
					end
				end
			end
			-- a start island with no room for both home copies: the missing one goes around
			Fill(have, free, MIRROR_REGION_LUX_AROUND + math.max(0, MIRROR_REGION_LUX_HOME - nHome), "around");
		end
	end
	print("Region luxury at capitals: added", log.added, "removed", log.removed, "short", log.short);
end
------------------------------------------------------------------------------
function MirrorMoreOil(asp, nRegions, factor)
	-- More Oil on the archipelago (user, 11-14: "barely see any oil ... increase it by 150%";
	-- "rule of thumb: one oil nearby on the island, and one in the ocean somewhere"):
	-- 1. every capital: one Oil on its own island (4-7 tiles out) and one at sea within 8 tiles;
	-- 2. then more Oil, half land half sea, until there is factor x what the game placed.
	-- Never within 3 tiles of a capital, never within 2 of other Oil.
	MirrorLoadResourceRules();
	local oil = asp.oil_ID or (GameInfo.Resources["RESOURCE_OIL"] and GameInfo.Resources["RESOURCE_OIL"].ID);
	if oil == nil then return end
	local iW, iH = Map.GetGridSize();
	local had, landAmt, seaAmt = 0, {}, {};
	for i = 0, iW * iH - 1 do
		local plot = Map.GetPlotByIndex(i);
		if plot:GetResourceType(-1) == oil then
			had = had + 1;
			if plot:IsWater() then table.insert(seaAmt, plot:GetNumResource()) else table.insert(landAmt, plot:GetNumResource()) end
		end
	end
	local function Amount(list, default)
		if table.maxn(list) == 0 then return default end
		return list[1 + Map.Rand(table.maxn(list), "More oil - amount")];
	end
	local function NearCapital(plot)
		for r = 1, nRegions do
			local data = asp.startingPlots[r];
			if data ~= nil and Map.PlotDistance(plot:GetX(), plot:GetY(), data[1], data[2]) <= 3 then return true end
		end
		return false;
	end
	local function NearOil(plot)
		for dx = -2, 2 do
			for dy = -2, 2 do
				local p = Map.PlotXYWithRangeCheck(plot:GetX(), plot:GetY(), dx, dy, 2);
				if p ~= nil and p:GetResourceType(-1) == oil then return true end
			end
		end
		return false;
	end
	local function FreeSpot(plot)
		return plot:GetResourceType(-1) == -1 and plot:GetImprovementType() == -1 and not NearCapital(plot);
	end
	local function SeaFits(plot)
		return plot:IsWater() and not plot:IsLake() and plot:GetTerrainType() == TerrainTypes.TERRAIN_COAST
			and plot:GetFeatureType() == FeatureTypes.NO_FEATURE;
	end
	local function LandFits(plot)
		return not plot:IsWater() and MirrorResourceFits(plot, oil, false);
	end
	local added = 0;
	local function Place(list, sea, bNearCapitalOK)
		while table.maxn(list) > 0 do
			local plot = table.remove(list, 1 + Map.Rand(table.maxn(list), "More oil - spot"));
			if plot:GetResourceType(-1) == -1 and plot:GetImprovementType() == -1
				and (bNearCapitalOK or not NearCapital(plot)) and (bNearCapitalOK or not NearOil(plot)) then
				plot:SetResourceType(oil, sea and Amount(seaAmt, 4) or Amount(landAmt, 6));
				added = added + 1;
				return true;
			end
		end
		return false;
	end
	-- 1. one on the home island, one at sea, per capital
	for r = 1, nRegions do
		local data = asp.startingPlots[r];
		if data ~= nil then
			local cap = Map.GetPlot(data[1], data[2]);
			local area = cap:GetArea();
			local haveLand, haveSea, landSpots, seaSpots, closeSpots, anySpots = false, false, {}, {}, {}, {};
			for loop, plot in ipairs(MirrorPlotsInRings(data[1], data[2], 1, 8)) do
				local d = Map.PlotDistance(data[1], data[2], plot:GetX(), plot:GetY());
				if plot:GetResourceType(-1) == oil then
					if plot:IsWater() then haveSea = true elseif plot:GetArea() == area then haveLand = true end
				elseif SeaFits(plot) then table.insert(seaSpots, plot)
				elseif d >= 2 and d <= 7 and plot:GetArea() == area and not plot:IsWater() and not plot:IsMountain() then
					-- small islands: 2-3 tiles out if nothing farther, and any land if Oil fits nowhere
					if LandFits(plot) then
						if d >= 4 then table.insert(landSpots, plot) else table.insert(closeSpots, plot) end
					else
						table.insert(anySpots, plot);
					end
				end
			end
			if not haveLand then
				local _ = Place(landSpots, false) or Place(closeSpots, false, true) or Place(anySpots, false, true);
			end
			if not haveSea then Place(seaSpots, true) end
		end
	end
	-- 2. the rest, land and sea taking turns
	local want = math.floor(had * (factor - 1) + 0.5) - added;
	if want > 0 then
		local land, sea = {}, {};
		for i = 0, iW * iH - 1 do
			local plot = Map.GetPlotByIndex(i);
			if FreeSpot(plot) then
				if SeaFits(plot) then table.insert(sea, plot) elseif LandFits(plot) then table.insert(land, plot) end
			end
		end
		local n, stop = 0, false;
		while n < want and not stop do
			local ok = (n % 2 == 0) and (Place(sea, true) or Place(land, false)) or (Place(land, false) or Place(sea, true));
			if ok then n = n + 1 else stop = true end
		end
	end
	print("More oil: had", had, "added", added);
end
------------------------------------------------------------------------------
function MirrorCapitalExtraCap(asp, nRegions, maxExtra)
	-- Capitals good, not crazy (user, 11-14 late: "9 bonus resources on this capital"):
	-- within 3 tiles at most maxExtra extra resources that are not luxuries -
	-- every bonus (Fish, land food, Stone) plus any second Horses/Iron deposit.
	-- The guaranteed Horses and Iron (the biggest deposit of each) are the standard and
	-- not counted; Coal/Aluminium/Oil/Uranium are not counted. Runs last, so no
	-- later step can add more. A second deposit goes first, then the farthest bonus.
	if asp == nil or asp.startingPlots == nil then return end
	local removed = 0;
	for r = 1, nRegions do
		local data = asp.startingPlots[r];
		if data ~= nil then
			local x, y = data[1], data[2];
			local extra, nearest = {}, {};
			for loop, plot in ipairs(MirrorPlotsInRings(x, y, 1, 3)) do
				local res = plot:GetResourceType(-1);
				local row = res ~= -1 and GameInfo.Resources[res] or nil;
				if row ~= nil then
					local d = Map.PlotDistance(x, y, plot:GetX(), plot:GetY());
					if row.ResourceUsage == 0 then
						table.insert(extra, {plot, d, 0});
					elseif res == asp.horse_ID or res == asp.iron_ID then
						-- the standard deposit is the biggest one (the strategic balance's), nearest on a tie
						-- (a deposit on a tile it does not fit counts as smaller: it may not be workable)
						local amt = plot:GetNumResource() * 2 + (MirrorResourceFits(plot, res, false) and 1 or 0);
						local n = nearest[res];
						if n == nil then nearest[res] = {plot, d, 1, amt}
						elseif amt > n[4] or (amt == n[4] and d < n[2]) then table.insert(extra, n); nearest[res] = {plot, d, 1, amt}
						else table.insert(extra, {plot, d, 1, amt}) end
					end
				end
			end
			while table.maxn(extra) > maxExtra do
				local pick, best = 1, nil;
				for n, e in ipairs(extra) do
					local key = e[3] * 100 + e[2];
					if best == nil or key > best or (key == best and Map.Rand(2, "Capital extra cap - tie") == 0) then pick, best = n, key end
				end
				local e = table.remove(extra, pick);
				e[1]:SetResourceType(-1, 0);
				removed = removed + 1;
			end
		end
	end
	print("Capital extra cap: at most", maxExtra, "per capital, removed", removed);
end
------------------------------------------------------------------------------
function MirrorCapitalBonusCap(asp, nRegions)
	-- Good, not crazy (user, 11-14): within 3 tiles of every capital exactly
	-- 3-5 bonus resources, Fish and land bonus together (one number per game,
	-- the same for everybody). Strategic balance and luxuries are not counted.
	-- Too many: the more common kind (sea or land) loses one first. Too few:
	-- a land bonus or a Fish is added.
	MirrorLoadResourceRules();
	local iW, iH = Map.GetGridSize();
	-- 2-4 food bonus within 3 tiles (one number per game, the same for everybody);
	-- a roll each game splits them into Fish (never more than 3) and land food,
	-- so a capital has either plenty of Fish or plenty of land food, not both.
	-- user 11-15: two kinds of capital (one roll per game, the same for everybody):
	-- 2 games in 3 a Fish capital (3-4 Fish + 2-3 land food), else a land capital (0-1 Fish + 6-7 land food).
	local fishWant, landWant;
	if Map.Rand(3, "Capital bonus cap - kind") < 2 then
		fishWant = 3 + Map.Rand(2, "Capital bonus cap - fish"); landWant = 2 + Map.Rand(2, "Capital bonus cap - land");
	else
		fishWant = Map.Rand(2, "Capital bonus cap - fish"); landWant = 6 + Map.Rand(2, "Capital bonus cap - land");
	end
	local want = fishWant + landWant;
	CAPITAL_FOOD_WANT = want;
	local fish = GameInfo.Resources["RESOURCE_FISH"];
	local log = {removed = 0, added = 0};
	local function IsBonus(res)
		return res ~= -1 and GameInfo.Resources[res] ~= nil and GameInfo.Resources[res].ResourceUsage == 0
			and GameInfo.Resources[res].Type ~= "RESOURCE_STONE";	-- food bonus only
	end
	for r = 1, nRegions do
		local data = asp.startingPlots[r];
		if data ~= nil then
			local x, y = data[1], data[2];
			local sea, land, freeSea, freeLand = {}, {}, {}, {};
			for loop, plot in ipairs(MirrorPlotsInRings(x, y, 1, 3)) do
				local i = plot:GetY() * iW + plot:GetX();
				if mirror_kind[i] == MIRROR_WEST and not MirrorIsNoResourceIndex(i) then
					local res = plot:GetResourceType(-1);
					if IsBonus(res) then
						if plot:IsWater() then table.insert(sea, plot) else table.insert(land, plot) end
					elseif res == -1 and plot:GetImprovementType() == -1 and not plot:IsMountain() and not plot:IsLake() then
						if plot:IsWater() then
							if plot:GetFeatureType() == FeatureTypes.NO_FEATURE then table.insert(freeSea, plot) end
						else
							table.insert(freeLand, plot);
						end
					end
				end
			end
			local function DropFarthest(list)
				-- the farthest goes first (keeps the food within 2 tiles of the capital)
				local far, farD = {}, -1;
				for n, p in ipairs(list) do
					local d = Map.PlotDistance(x, y, p:GetX(), p:GetY());
					if d > farD then far, farD = {n}, d elseif d == farD then table.insert(far, n) end
				end
				local plot = table.remove(list, far[1 + Map.Rand(table.maxn(far), "Capital bonus cap - remove")]);
				plot:SetResourceType(-1, 0);
				log.removed = log.removed + 1;
			end
			while table.maxn(sea) > fishWant do DropFarthest(sea) end
			while table.maxn(land) > landWant do DropFarthest(land) end
			local function NearFirst(list, tag)
				-- a random tile within 2 of the capital if there is one, else any
				local near = {};
				for n, p in ipairs(list) do
					if Map.PlotDistance(x, y, p:GetX(), p:GetY()) <= 2 then table.insert(near, n) end
				end
				if table.maxn(near) > 0 then return near[1 + Map.Rand(table.maxn(near), tag)] end
				return 1 + Map.Rand(table.maxn(list), tag);
			end
			local function AddFish()
				while fish ~= nil and table.maxn(freeSea) > 0 do
					local plot = table.remove(freeSea, NearFirst(freeSea, "Capital bonus cap - fish"));
					if mirror_resourceRules[fish.ID].terrain[plot:GetTerrainType()] == true then
						plot:SetResourceType(fish.ID, 1);
						table.insert(sea, plot);
						log.added = log.added + 1;
						return true;
					end
				end
				return false;
			end
			local function AddLand()
				while table.maxn(freeLand) > 0 do
					local plot = table.remove(freeLand, NearFirst(freeLand, "Capital bonus cap - land"));
					if asp:AttemptToPlaceBonusResourceAtPlot(plot:GetX(), plot:GetY(), false) then
						table.insert(land, plot);
						log.added = log.added + 1;
						return true;
					end
				end
				return false;
			end
			while table.maxn(sea) < fishWant do if not AddFish() then break end end
			while table.maxn(land) < landWant do if not AddLand() then break end end
			-- one side had no room: the other side makes up the count (Fish never above 3)
			while table.maxn(sea) + table.maxn(land) < want do
				if not ((table.maxn(sea) < 4 and AddFish()) or AddLand()) then break end
			end
			-- at least one food resource within 2 tiles: a far one moves in
			local function NearCount(list)
				local c = 0;
				for loop, p in ipairs(list) do if Map.PlotDistance(x, y, p:GetX(), p:GetY()) <= 2 then c = c + 1 end end
				return c;
			end
			if NearCount(sea) + NearCount(land) == 0 and table.maxn(sea) + table.maxn(land) > 0 then
				if table.maxn(land) > 0 then
					DropFarthest(land);
					if not AddLand() then AddFish() end
				else
					DropFarthest(sea);
					if not AddFish() then AddLand() end
				end
			end
		end
	end
	print("Capital bonus cap:", want, "per capital (Fish", fishWant, ") removed", log.removed, "added", log.added);
end
------------------------------------------------------------------------------
function MirrorFishCityCap(asp, nRegions, maxFish)
	-- Not overdone (user, 11-14: "9+ Fish is too much"): no land tile (a city
	-- site) has more than maxFish Fish within 3 tiles. Extra Fish are removed,
	-- never the ones within 3 tiles of a capital (those are already capped).
	local fish = GameInfo.Resources["RESOURCE_FISH"];
	if fish == nil then return end
	local iW, iH = Map.GetGridSize();
	local capitals = {};
	for r = 1, nRegions do
		local data = asp.startingPlots[r];
		if data ~= nil then table.insert(capitals, {data[1], data[2]}) end
	end
	local function NearCapital(plot)
		for loop, c in ipairs(capitals) do
			if Map.PlotDistance(c[1], c[2], plot:GetX(), plot:GetY()) <= 3 then return true end
		end
		return false
	end
	local land = {};
	for i = 0, iW * iH - 1 do
		local plot = Map.GetPlotByIndex(i);
		if not plot:IsWater() and not plot:IsMountain() and mirror_kind[i] == MIRROR_WEST and not MirrorIsNoResourceIndex(i) then table.insert(land, plot) end
	end
	local removed = 0;
	-- random order, so no corner of the map is favoured
	for n = table.maxn(land), 2, -1 do
		local k = 1 + Map.Rand(n, "Fish city cap - order");
		land[n], land[k] = land[k], land[n];
	end
	for loop, site in ipairs(land) do
		local here, removable = 0, {};
		for loop2, plot in ipairs(MirrorPlotsInRings(site:GetX(), site:GetY(), 1, 3)) do
			local i = plot:GetY() * iW + plot:GetX();
			if plot:IsWater() and plot:GetResourceType(-1) == fish.ID and mirror_kind[i] == MIRROR_WEST and not MirrorIsNoResourceIndex(i) then
				here = here + 1;
				if not NearCapital(plot) then table.insert(removable, plot) end
			end
		end
		while here > maxFish and table.maxn(removable) > 0 do
			local plot = table.remove(removable, 1 + Map.Rand(table.maxn(removable), "Fish city cap - remove"));
			plot:SetResourceType(-1, 0);
			here = here - 1;
			removed = removed + 1;
		end
	end
	print("Fish city cap:", maxFish, "Fish per city site at most, removed", removed);
end
------------------------------------------------------------------------------
function MirrorFillMiddle(asp)
	-- Mirror Pangaea: resources evenly over the map (user: "the middle is
	-- devoid", "clusters toward the edges"). The game puts most resources
	-- around the starts, so the open land (more than 4 tiles from every capital)
	-- is filled up: the middle band (a fifth of the map width each side of the
	-- centre line) to 1.6x the average resource density of all the land, with
	-- 40% food / bonus, 40% luxuries already on the map, 20% Horses or Iron
	-- (worth fighting for); the rest of the open land to the average, 60 / 25 / 15. Never next to another resource; west side only,
	-- the mirror copies it east.
	MirrorLoadResourceRules();
	local iW, iH = Map.GetGridSize();
	local band = math.max(4, math.floor(iW * 0.2));
	local capitals = {};
	for n, data in pairs(asp.startingPlots) do
		if data ~= nil and data[1] ~= nil then table.insert(capitals, {data[1], data[2]}) end
	end
	local function Open(plot)
		for loop, c in ipairs(capitals) do
			if Map.PlotDistance(c[1], c[2], plot:GetX(), plot:GetY()) <= 4 then return false end
		end
		return true
	end
	local function Usable(i, plot)
		return mirror_kind[i] == MIRROR_WEST and not MirrorIsNoResourceIndex(i) and not plot:IsWater()
			and not plot:IsMountain() and plot:GetImprovementType() == -1 and not plot:IsStartingPlot()
			and plot:GetTerrainType() ~= TerrainTypes.TERRAIN_SNOW;
	end
	local land, withRes = 0, 0;
	local zones = {{free = {}, n = 0, res = 0}, {free = {}, n = 0, res = 0}};	-- 1 = open middle, 2 = open rest
	for i = 0, iW * iH - 1 do
		local plot = Map.GetPlotByIndex(i);
		if Usable(i, plot) then
			land = land + 1;
			local has = plot:GetResourceType(-1) ~= -1;
			if has then withRes = withRes + 1 end
			if Open(plot) then
				local z = (mirror_axisDist[i] <= band) and zones[1] or zones[2];
				z.n = z.n + 1;
				if has then z.res = z.res + 1 else table.insert(z.free, plot) end
			end
		end
	end
	if land == 0 then return end
	local density = withRes / land;
	local onMap = {};
	for i = 0, iW * iH - 1 do
		local r = Map.GetPlotByIndex(i):GetResourceType(-1);
		if r ~= -1 then onMap[r] = true end
	end
	local lux = {};
	for row in GameInfo.Resources() do
		if row.ResourceClassType == "RESOURCECLASS_LUXURY" and onMap[row.ID] then table.insert(lux, row.ID) end
	end
	local strat = {};
	for loop, t in ipairs({"RESOURCE_HORSE", "RESOURCE_IRON"}) do
		if GameInfo.Resources[t] ~= nil then table.insert(strat, GameInfo.Resources[t].ID) end
	end
	local function Lonely(plot)
		for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
			local adj = Map.PlotDirection(plot:GetX(), plot:GetY(), direction);
			if adj ~= nil and adj:GetResourceType(-1) ~= -1 then return false end
		end
		return true
	end
	local added = {bonus = 0, lux = 0, strat = 0};
	for zn, z in ipairs(zones) do
	local mid = z.free;
	-- the middle is worth fighting for: 1.6x the average there, and more luxuries / strategics
	local factor = (zn == 1) and 1.6 or 1;
	local luxFrom, stratFrom = 60, 85;
	if zn == 1 then luxFrom, stratFrom = 40, 80 end
	local want = math.floor(z.n * density * factor + 0.5) - z.res;
	local tries = 0;
	while want > 0 and table.maxn(mid) > 0 and tries < 2000 do
		tries = tries + 1;
		local plot = table.remove(mid, 1 + Map.Rand(table.maxn(mid), "Mirror Pangaea - middle spot"));
		if plot:GetResourceType(-1) == -1 and Lonely(plot) then
			local roll = Map.Rand(100, "Mirror Pangaea - middle kind");
			local placed = false;
			if roll >= stratFrom and table.maxn(strat) > 0 then
				local id = strat[1 + Map.Rand(table.maxn(strat), "Mirror Pangaea - middle strategic")];
				if MirrorResourceFits(plot, id, false) then
					plot:SetResourceType(id, 2);
					placed = true;
					added.strat = added.strat + 1;
				end
			elseif roll >= luxFrom and table.maxn(lux) > 0 then
				for attempt = 1, 4 do
					local id = lux[1 + Map.Rand(table.maxn(lux), "Mirror Pangaea - middle luxury")];
					local fits = MirrorResourceFits(plot, id, false);
					if not placed and not fits and plot:GetFeatureType() == FeatureTypes.NO_FEATURE then
						-- give the tile the forest / jungle / marsh the luxury needs
						local rules = mirror_resourceRules[id];
						for f, ok in pairs(rules.feature) do
							if not fits and ok and rules.featureTerrain[plot:GetTerrainType()] == true then
								plot:SetFeatureType(f, -1);
								fits = MirrorResourceFits(plot, id, false);
								if not fits then plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1) end
							end
						end
					end
					if not placed and fits then
						plot:SetResourceType(id, 1);
						placed = true;
						added.lux = added.lux + 1;
					end
				end
			end
			if not placed and asp:AttemptToPlaceBonusResourceAtPlot(plot:GetX(), plot:GetY(), false) then
				placed = true;
				added.bonus = added.bonus + 1;
			end
			if placed then want = want - 1 end
		end
	end
	end
	print("Mirror Pangaea: middle filled, band", band, "bonus +", added.bonus, "luxuries +", added.lux, "strategic +", added.strat);
end
------------------------------------------------------------------------------
-- MIRROR PANGAEA: a river across the centre line, luxuries on it (user, 11-14)
------------------------------------------------------------------------------
mirror_crossRiver = nil;	-- GLOBAL list of {plot index, "SE"|"SW", flow} edges, both sides, laid after every mirror pass
function MirrorPickCrossRiver()
	-- 2 games in 3: one river along the edges between two middle rows, crossing
	-- the centre line and running 3-7 tiles out on each side (until water). The
	-- edges come in mirror pairs, so the mirror keeps it whole; it flows outward
	-- from the middle on both sides.
	mirror_crossRiver = nil;
	if Map.Rand(3, "Mirror Pangaea - cross river or not") == 0 then return end
	local iW, iH = Map.GetGridSize();
	local function LandAt(plot)
		return plot ~= nil and not plot:IsWater()
	end
	local function EdgesOk(plot)
		local x, y = plot:GetX(), plot:GetY();
		return LandAt(plot) and LandAt(Map.PlotDirection(x, y, DirectionTypes.DIRECTION_SOUTHEAST))
			and LandAt(Map.PlotDirection(x, y, DirectionTypes.DIRECTION_SOUTHWEST));
	end
	local rows = {};
	for y = math.floor(iH * 0.3), math.ceil(iH * 0.7) do table.insert(rows, y) end
	local nRows = table.maxn(rows);
	for tries = 1, nRows do
		local y = table.remove(rows, 1 + Map.Rand(table.maxn(rows), "Mirror Pangaea - cross river row"));
		-- the west-most plot of the middle (on odd rows the centre plot is its own mirror)
		local xMid = (y % 2 == 0) and (math.floor(iW / 2) - 1) or math.floor((iW - 2) / 2);
		local first = Map.GetPlot(xMid, y);
		if first ~= nil and EdgesOk(first) then
			local length = 3 + Map.Rand(5, "Mirror Pangaea - cross river length");
			local list = {};
			for n = 0, length - 1 do
				local p = Map.GetPlot(xMid - n, y);
				if p == nil or not EdgesOk(p) then break end
				local i = p:GetY() * iW + p:GetX();
				local twin = mirror_twin[i];
				if n == 0 and y % 2 == 1 then
					-- the centre plot (its own mirror): south-west edge flows west, south-east edge east
					table.insert(list, {i, "SW", FlowDirectionTypes.FLOWDIRECTION_NORTHWEST});
					table.insert(list, {i, "SE", FlowDirectionTypes.FLOWDIRECTION_NORTHEAST});
				else
					table.insert(list, {i, "SE", FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST});
					table.insert(list, {i, "SW", FlowDirectionTypes.FLOWDIRECTION_NORTHWEST});
					if twin ~= nil and twin >= 0 and twin ~= i then
						table.insert(list, {twin, "SW", MirrorFlow(FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST)});
						table.insert(list, {twin, "SE", MirrorFlow(FlowDirectionTypes.FLOWDIRECTION_NORTHWEST)});
					end
				end
			end
			if table.maxn(list) >= 6 then
				mirror_crossRiver = list;
				print("Mirror Pangaea: river across the middle on row", y, "edges", table.maxn(list));
				return
			end
		end
	end
	print("Mirror Pangaea: no row for a river across the middle");
end
function MirrorLayCrossRiver()
	if mirror_crossRiver == nil then return end
	for loop, e in ipairs(mirror_crossRiver) do
		local plot = Map.GetPlotByIndex(e[1]);
		local x, y = plot:GetX(), plot:GetY();
		local dir = DirectionTypes.DIRECTION_SOUTHWEST;
		if e[2] == "SE" then dir = DirectionTypes.DIRECTION_SOUTHEAST end
		local other = Map.PlotDirection(x, y, dir);
		if not plot:IsWater() and other ~= nil and not other:IsWater() then
			if e[2] == "SE" then plot:SetNWOfRiver(true, e[3]) else plot:SetNEOfRiver(true, e[3]) end
		end
	end
end
------------------------------------------------------------------------------
function MirrorCentreLine(asp)
	-- Pangaea, so the halves flow into each other instead of meeting at a seam:
	-- no resource pairs within 2 tiles of their own mirror image (away from the
	-- capitals), and 2 games in 3 one or two luxuries ON the centre line (plots
	-- that are their own mirror image), the same distance from both sides.
	MirrorLoadResourceRules();
	local iW, iH = Map.GetGridSize();
	local capitals = {};
	for n, data in pairs(asp.startingPlots) do
		if data ~= nil and data[1] ~= nil then table.insert(capitals, {data[1], data[2]}) end
	end
	local function NearCapital(x, y)
		for loop, c in ipairs(capitals) do
			if Map.PlotDistance(c[1], c[2], x, y) <= 4 then return true end
		end
		return false
	end
	local removed = 0;
	for i = 0, iW * iH - 1 do
		if mirror_kind[i] == MIRROR_WEST then
			local plot = Map.GetPlotByIndex(i);
			local x, y = plot:GetX(), plot:GetY();
			if plot:GetResourceType(-1) ~= -1 and not plot:IsWater() and MirrorTwinDistance(x, y) <= 2 and not NearCapital(x, y) then
				plot:SetResourceType(-1, 0);
				removed = removed + 1;
			end
		end
	end
	local placed = 0;
	if Map.Rand(3, "Mirror Pangaea - centre luxuries or not") ~= 0 then
		local onMap, lux = {}, {};
		for i = 0, iW * iH - 1 do
			local r = Map.GetPlotByIndex(i):GetResourceType(-1);
			if r ~= -1 then onMap[r] = true end
		end
		for row in GameInfo.Resources() do
			if row.ResourceClassType == "RESOURCECLASS_LUXURY" and onMap[row.ID] then table.insert(lux, row.ID) end
		end
		local spots = {};
		for i = 0, iW * iH - 1 do
			local plot = Map.GetPlotByIndex(i);
			local y = plot:GetY();
			if mirror_kind[i] == MIRROR_AXIS and not plot:IsWater() and not plot:IsMountain() and plot:GetResourceType(-1) == -1
				and y >= math.floor(iH * 0.25) and y <= math.ceil(iH * 0.75) and not NearCapital(plot:GetX(), y) then
				table.insert(spots, plot);
			end
		end
		local want = 1 + Map.Rand(2, "Mirror Pangaea - centre luxury count");
		local tries = 0;
		while placed < want and table.maxn(spots) > 0 and table.maxn(lux) > 0 and tries < 60 do
			tries = tries + 1;
			local k = 1 + Map.Rand(table.maxn(spots), "Mirror Pangaea - centre luxury spot");
			local plot = spots[k];
			local id = lux[1 + Map.Rand(table.maxn(lux), "Mirror Pangaea - centre luxury")];
			local fits = MirrorResourceFits(plot, id, false);
			if not fits and plot:GetFeatureType() == FeatureTypes.NO_FEATURE then
				local rules = mirror_resourceRules[id];
				for f, ok in pairs(rules.feature) do
					if not fits and ok and rules.featureTerrain[plot:GetTerrainType()] == true then
						plot:SetFeatureType(f, -1);
						fits = MirrorResourceFits(plot, id, false);
						if not fits then plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1) end
					end
				end
			end
			if fits then
				plot:SetResourceType(id, 1);
				placed = placed + 1;
				-- the next one at least 4 rows away
				for n = table.maxn(spots), 1, -1 do
					if math.abs(spots[n]:GetY() - plot:GetY()) < 4 then table.remove(spots, n) end
				end
			end
		end
	end
	print("Mirror Pangaea: centre line - pairs near the seam removed", removed, "luxuries on the line", placed);
end

------------------------------------------------------------------------------
function KekJungleOnPlains()
	-- The game turns the ground under jungle into plains (FeatureGenerator), but
	-- jungle added later for a luxury (Cocoa, Spices, Bananas...) would sit on
	-- grassland: 3 food + the resource instead of 2. Last pass: jungle on
	-- grassland -> plains (same on both halves of a mirror map).
	local jungle = FeatureTypes.FEATURE_JUNGLE;
	for i = 0, Map.GetNumPlots() - 1 do
		local plot = Map.GetPlotByIndex(i);
		if plot:GetFeatureType() == jungle and plot:GetTerrainType() == TerrainTypes.TERRAIN_GRASS then
			plot:SetTerrainType(TerrainTypes.TERRAIN_PLAINS, false, true);
		end
	end
end

------------------------------------------------------------------------------
function MirrorCapitalLuxuries(asp, nRegions)
	-- Capitals as the user wants them (11-14): within 3 tiles exactly 2 copies
	-- of the capital's regional luxury and exactly 1 other luxury (land or sea).
	-- Missing ones are added on fitting free tiles, extras go (farthest first).
	MirrorLoadResourceRules();
	local iW, iH = Map.GetGridSize();
	local isLux = {};
	for row in GameInfo.Resources() do
		if row.ResourceUsage == 2 and row.Type ~= "RESOURCE_JEWELRY" and row.Type ~= "RESOURCE_PORCELAIN" then isLux[row.ID] = true end
	end
	local regional = {};
	for r = 1, nRegions do
		local lux = asp.region_luxury_assignment and asp.region_luxury_assignment[r];
		if lux ~= nil then regional[lux] = true end
	end
	-- the extra luxury comes from the game's "random" luxuries, else any non-regional one
	local extras = {};
	for loop, id in ipairs(asp.resourceIDs_assigned_to_random or {}) do if isLux[id] and not regional[id] then table.insert(extras, id) end end
	if table.maxn(extras) == 0 then
		for id in pairs(isLux) do if not regional[id] then table.insert(extras, id) end end
		table.sort(extras);
	end
	local log = {added = 0, removed = 0};
	for r = 1, nRegions do
		local data = asp.startingPlots[r];
		local reg = asp.region_luxury_assignment and asp.region_luxury_assignment[r];
		if data ~= nil then
			local x, y = data[1], data[2];
			local mine, other, free = {}, {}, {};
			for loop, plot in ipairs(MirrorPlotsInRings(x, y, 1, 3)) do
				local i = plot:GetY() * iW + plot:GetX();
				if mirror_kind[i] == MIRROR_WEST and not MirrorIsNoResourceIndex(i) then
					local res = plot:GetResourceType(-1);
					if res ~= -1 and isLux[res] then
						if res == reg then table.insert(mine, plot) else table.insert(other, plot) end
					elseif res == -1 and plot:GetImprovementType() == -1 and not plot:IsMountain() and not plot:IsLake() then
						table.insert(free, plot);
					end
				end
			end
			local function Farthest(list)
				local best, bestD = 1, -1;
				for n, p in ipairs(list) do
					local d = Map.PlotDistance(x, y, p:GetX(), p:GetY());
					if d > bestD then best, bestD = n, d end
				end
				return table.remove(list, best);
			end
			local function Place(resID)
				for n = table.maxn(free), 1, -1 do
					local k = 1 + Map.Rand(n, "Capital luxuries - spot");
					free[k], free[n] = free[n], free[k];
					local plot = free[n];
					if MirrorResourceFits(plot, resID, false) then
						table.remove(free, n);
						plot:SetResourceType(resID, 1);
						log.added = log.added + 1;
						return plot;
					end
				end
				return nil;
			end
			if reg ~= nil then
				while table.maxn(mine) > 2 do Farthest(mine):SetResourceType(-1, 0); log.removed = log.removed + 1 end
				while table.maxn(mine) < 2 do
					local p = Place(reg);
					if p == nil then break end
					table.insert(mine, p);
				end
			end
			while table.maxn(other) > 1 do Farthest(other):SetResourceType(-1, 0); log.removed = log.removed + 1 end
			if table.maxn(other) == 0 and table.maxn(extras) > 0 then
				local start = Map.Rand(table.maxn(extras), "Capital luxuries - extra type");
				for n = 0, table.maxn(extras) - 1 do
					if Place(extras[(start + n) % table.maxn(extras) + 1]) ~= nil then break end
				end
			end
		end
	end
	print("Capital luxuries: added", log.added, "removed", log.removed);
end

------------------------------------------------------------------------------
function MirrorIslandScaling(asp)
	-- Speed vs scaling (user, 11-14): small islands (8 tiles or less) one more
	-- Fish (quick food), bigger free islands (15+) one more land food per 10
	-- tiles (they also have a lake). Start islands are not touched.
	local iW, iH = Map.GetGridSize();
	local fish = GameInfo.Resources["RESOURCE_FISH"];
	local log = {fish = 0, land = 0};
	for id, island in ipairs(mirror_islands) do
		local n = table.maxn(island.plots);
		if island.kind ~= "start" and island.kind ~= "own" then
			if n <= 8 and fish ~= nil then
				local spots, seen = {}, {};
				for loop, t in ipairs(island.plots) do
					for loop2, j in ipairs(MirrorNeighbours(t)) do
						local plot = Map.GetPlotByIndex(j);
						if not seen[j] and (function(i) return mirror_kind[i] == MIRROR_WEST and not MirrorIsNoResourceIndex(i) end)(j) and plot:IsWater() and not plot:IsLake() and plot:GetResourceType(-1) == -1
							and plot:GetFeatureType() == FeatureTypes.NO_FEATURE and plot:GetTerrainType() == TerrainTypes.TERRAIN_COAST then
							seen[j] = true;
							table.insert(spots, plot);
						end
					end
				end
				if table.maxn(spots) > 0 then
					spots[1 + Map.Rand(table.maxn(spots), "Island scaling - fish")]:SetResourceType(fish.ID, 1);
					log.fish = log.fish + 1;
				end
			elseif n >= 15 then
				local want = math.floor(n / 10);
				local free = {};
				for loop, t in ipairs(island.plots) do
					local plot = Map.GetPlotByIndex(t);
					if (function(i) return mirror_kind[i] == MIRROR_WEST and not MirrorIsNoResourceIndex(i) end)(t) and not plot:IsWater() and not plot:IsMountain() and plot:GetResourceType(-1) == -1 and plot:GetImprovementType() == -1 then
						table.insert(free, plot);
					end
				end
				while want > 0 and table.maxn(free) > 0 do
					local plot = table.remove(free, 1 + Map.Rand(table.maxn(free), "Island scaling - land"));
					if asp:AttemptToPlaceBonusResourceAtPlot(plot:GetX(), plot:GetY(), false) then
						want = want - 1;
						log.land = log.land + 1;
					end
				end
			end
		end
	end
	print("Island scaling: Fish on small islands", log.fish, "land food on big islands", log.land);
end
