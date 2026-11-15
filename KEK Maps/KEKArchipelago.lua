------------------------------------------------------------------------------
--	FILE:	 KEKArchipelago.lua
--	AUTHOR:  KEK multiplayer community (2026), built on Firaxis' Archipelago.lua
--	         and on the island generator of Mirror Archipelago (MirrorSkirmish.lua)
--	PURPOSE: An archipelago for free-for-all games (NOT mirrored).
--	         Every player starts on an own island (8-11 / 10-15 / 14-18 land
--	         tiles, map option). Around them many islands of 1-3 tiles and of
--	         5-10 tiles, mostly shallow coast with some ocean. Small islands get
--	         extra Fish, some islands are rich and some are poor.
--	         Strategic balance: every capital gets Horses, Iron (12), Coal (7) and
--	         Aluminium (3) within 3 tiles.
--	         City states sit on islands of 4 tiles or more, never on a start
--	         island and never in the polar rows.
--	         The map wraps east-west like the game's Archipelago. Islands stay
--	         off the two seam columns (x = 0 and x = W - 1), so no island crosses
--	         the seam; all distances go through Map.PlotDistance / Map.PlotDirection,
--	         which handle the wrap.
--	         Deterministic: only Map.Rand is used (multiplayer safe).
------------------------------------------------------------------------------
--	Copyright (c) 2010 Firaxis Games, Inc. All rights reserved.
--	KEK additions (2026) are free to use and change.
------------------------------------------------------------------------------

include("MapGenerator");
include("FractalWorld");
include("FeatureGenerator");
include("TerrainGenerator");
include("MapmakerUtilities");

------------------------------------------------------------------------------
-- Sea maps: half the game's ruins (user, 11-14). Sea ruins are their own option.
------------------------------------------------------------------------------
KekRuinHalf_AddGoodies = AddGoodies;
function AddGoodies()
	KekRuinHalf_AddGoodies();
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

------------------------------------------------------------------------------
-- MAP OPTIONS (read by position with Map.GetCustomOption(n))
------------------------------------------------------------------------------
KEK_OPT_STARTISLAND, KEK_OPT_ISLANDS, KEK_OPT_OCEAN = "startisland", "islands", "ocean";
KEK_OPT_TEMP, KEK_OPT_RAIN = "temp", "rain";

function KekOptionDefs()
	-- Same options as Mirror Map: Archipelago (this map always wraps).
	return {
			{key = "mapsize", Name = "Map size",
				Values = {
					{"Normal", "The game's size for the world size picked in the lobby."},
					{"Compact", "About three quarters of the tiles: the same islands and distances, the players start closer together."},
				}, DefaultValue = 1},
			{key = "capstrength", Name = "Capital strength",
				Values = {
					{"1", "How rich the land around every capital is: 2 food resources within 3 tiles, up to 3 extra resources. Strategic Balance (Horses, Iron, Coal, Aluminium) is always the same."},
					{"2", "How rich the land around every capital is: 2 food resources within 3 tiles, up to 3 extra resources. Strategic Balance (Horses, Iron, Coal, Aluminium) is always the same."},
					{"3", "How rich the land around every capital is: 2 food resources within 3 tiles, up to 3 extra resources. Strategic Balance (Horses, Iron, Coal, Aluminium) is always the same."},
					{"4", "How rich the land around every capital is: 3 food resources within 3 tiles, up to 3 extra resources. Strategic Balance (Horses, Iron, Coal, Aluminium) is always the same."},
					{"5", "How rich the land around every capital is: 4 food resources within 3 tiles, up to 3 extra resources. Strategic Balance (Horses, Iron, Coal, Aluminium) is always the same."},
					{"6", "How rich the land around every capital is: 5 food resources within 3 tiles, up to 4 extra resources. Strategic Balance (Horses, Iron, Coal, Aluminium) is always the same."},
					{"7", "How rich the land around every capital is: 5 food resources within 3 tiles, up to 5 extra resources. Strategic Balance (Horses, Iron, Coal, Aluminium) is always the same."},
					{"8", "How rich the land around every capital is: 6 food resources within 3 tiles, up to 6 extra resources. Strategic Balance (Horses, Iron, Coal, Aluminium) is always the same."},
					{"9", "How rich the land around every capital is: 7 food resources within 3 tiles, up to 7 extra resources. Strategic Balance (Horses, Iron, Coal, Aluminium) is always the same."},
					{"10", "How rich the land around every capital is: 8 food resources within 3 tiles, up to 8 extra resources. Strategic Balance (Horses, Iron, Coal, Aluminium) is always the same."},
				}, DefaultValue = 5},
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
			{key = "landamount", Name = "Land amount",
				Values = {
					{"Less (about 23% land)", "Fewer small islands outside the start and expansion islands."},
					{"Normal (about 25% land)", "A bit more land than Less."},
					{"More (about 28% land)", "More islands, water gaps of at most about 3 tiles."},
					{"Lots (about 30% land)", "Much more land, water gaps of at most about 2 tiles. The same on Compact: only the starts are closer."},
				}, DefaultValue = 4},
			{key = "islands", Name = "Small islands (1-10 tiles)",
				Values = {
					{"Few", "Some islands of 5-10 tiles and a few of 1-3."},
					{"Normal", "Many islands of 5-10 tiles, some of 1-3."},
					{"Lots", "Lots of islands of 5-10 and 1-3 tiles."},
				}, DefaultValue = 1},
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
		{key = "temp", Name = "TXT_KEY_MAP_OPTION_TEMPERATURE",
			Values = {"TXT_KEY_MAP_OPTION_COOL", "TXT_KEY_MAP_OPTION_TEMPERATE", "TXT_KEY_MAP_OPTION_HOT", "TXT_KEY_MAP_OPTION_RANDOM"},
			DefaultValue = 2},
		{key = "rain", Name = "TXT_KEY_MAP_OPTION_RAINFALL",
			Values = {"TXT_KEY_MAP_OPTION_ARID", "TXT_KEY_MAP_OPTION_NORMAL", "TXT_KEY_MAP_OPTION_WET", "TXT_KEY_MAP_OPTION_RANDOM"},
			DefaultValue = 3},
		{key = "resources", Name = "TXT_KEY_MAP_OPTION_RESOURCES",
			Values = {"TXT_KEY_MAP_OPTION_BALANCED_RESOURCES"},	-- only one value: tells everybody resources are balanced
			DefaultValue = 1},
	};
end
kek_optionIndex = {};	-- GLOBAL option key -> lobby position (shown options only)
kek_hiddenValue = {};	-- GLOBAL hidden option key -> its fixed value (user 11-14: not shown in the lobby)
function KekVisibleOptionDefs()
	local out = {};
	for _, def in ipairs(KekOptionDefs()) do
		if def.hidden then kek_hiddenValue[def.key] = def.DefaultValue else table.insert(out, def) end
	end
	return out;
end
for n, def in ipairs(KekVisibleOptionDefs()) do kek_optionIndex[def.key] = n end
------------------------------------------------------------------------------
function GetMapScriptInfo()
	local options = {};
	for n, def in ipairs(KekVisibleOptionDefs()) do
		table.insert(options, {Name = def.Name, Values = def.Values, DefaultValue = def.DefaultValue, SortPriority = n});
	end
	return {
		Name = "KEK Archipelago 1.1",
		Description = "Islands for free-for-all games. Every player starts on an own island of 20-40 tiles (option, up to 30-50), with islands of every size (1-30 tiles) all over the map and clusters of smaller islands; extra hills, Fish spread evenly, more coastal luxuries and atolls. Options for sizes, gaps, shapes, ocean and resources. Strategic balance: Horses, Iron (12), Coal (7) and Aluminium (3) within 3 tiles of every capital.",
		IconIndex = 2,
		SupportsSinglePlayer = true,
		SupportsMultiplayer = true,
		CustomOptions = options,
	};
end
------------------------------------------------------------------------------
function KekOpt(key, default)
	-- The lobby value of an option (by key), or the default if it is missing or out of range.
	if kek_hiddenValue[key] ~= nil then return kek_hiddenValue[key] end
	local n = kek_optionIndex[key];
	if n == nil then return default end
	local value = Map.GetCustomOption(n);
	local def = KekVisibleOptionDefs()[n];
	if value == nil or value < 1 or (def ~= nil and value > table.maxn(def.Values)) then
		return default;
	end
	return value;
end
------------------------------------------------------------------------------
function GetMapInitData(worldSize)
	-- The game's normal map sizes, wrapping east-west like the game's Archipelago.
	local world = GameInfo.Worlds[worldSize];
	if world ~= nil then
		-- Map size option: Normal / Compact (about 3/4 of the tiles) / Brawl (about 0.55)
		local f = ({1.0, 0.87, 0.74})[KekOpt("mapsize", 1)] or 1.0;
		return {
			Width = math.floor(world.GridWidth * f + 0.5),
			Height = math.floor(world.GridHeight * f + 0.5),
			WrapX = true,
		};
	end
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- HELPERS (wrap safe)
------------------------------------------------------------------------------
kek_islandOf = {};		-- GLOBAL plot index -> island number
kek_islands = {};		-- GLOBAL islands: {kind = "start"/"medium"/"small", plots = {...}}
kek_startIslands = {};	-- GLOBAL island numbers of the start islands
kek_coastArgs = nil;	-- GLOBAL args for GenerateCoasts (how far the shallow coast reaches)
kek_neighbours = {};	-- cache: plot index -> neighbour indices
kek_startPlotDatabase = nil;	-- GLOBAL the AssignStartingPlots instance
------------------------------------------------------------------------------
function KekWrapX()
	return Map.IsWrapX() == true;
end
------------------------------------------------------------------------------
function KekNeighbours(i)
	local list = kek_neighbours[i];
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
	kek_neighbours[i] = list;
	return list;
end
------------------------------------------------------------------------------
function KekWindowIndex(x, y)
	-- Plot index of (x, y), with x wrapped round on a wrapping map; nil when off the map.
	local iW, iH = Map.GetGridSize();
	if y < 0 or y >= iH then return nil end
	if KekWrapX() then
		x = x % iW;
	elseif x < 0 or x >= iW then
		return nil
	end
	return y * iW + x;
end
------------------------------------------------------------------------------
function KekPlotsInRange(x, y, minRing, maxRing)
	-- Plot indices between minRing and maxRing tiles from (x, y), in a fixed order.
	local iW, iH = Map.GetGridSize();
	local list, seen = {}, {};
	for dy = -maxRing, maxRing do
		for dx = -maxRing - 1, maxRing + 1 do
			local j = KekWindowIndex(x + dx, y + dy);
			if j ~= nil and not seen[j] then
				seen[j] = true;
				local d = Map.PlotDistance(x, y, j % iW, math.floor(j / iW));
				if d >= minRing and d <= maxRing then
					table.insert(list, j);
				end
			end
		end
	end
	return list;
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- ISLANDS
------------------------------------------------------------------------------
function KekIslandAllowed(i)
	-- Plots that may become island land: off the seam / map edge columns and
	-- off the two rows at each pole.
	local iW, iH = Map.GetGridSize();
	local x, y = i % iW, math.floor(i / iW);
	return x >= 1 and x <= iW - 2 and y >= 2 and y <= iH - 3;
end
------------------------------------------------------------------------------
function KekGrowIsland(id, seed, size, isLand, yMin, yMax, shape)
	-- Grows an island from a seed plot, one tile at a time. No tile may touch
	-- another island, so every island stays its own landmass. Shapes:
	--   "round"   prefers tiles with many island neighbours (compact blobs)
	--   "uniform" mild preference (irregular but solid)
	--   "stringy" prefers tiles touching the island on one side only (long, thin, branching)
	shape = shape or "round";
	local iW, iH = Map.GetGridSize();
	local function CanUse(j)
		if isLand[j] or not KekIslandAllowed(j) then return false end
		if yMin ~= nil then
			local y = math.floor(j / iW);
			if y < yMin or y > yMax then return false end
		end
		for loop, nb in ipairs(KekNeighbours(j)) do
			if isLand[nb] and kek_islandOf[nb] ~= id then return false end
		end
		return true
	end
	if not CanUse(seed) then return nil end
	local tiles, inIsland = {}, {};
	local function Add(j)
		table.insert(tiles, j);
		inIsland[j] = true;
		isLand[j] = true;
		kek_islandOf[j] = id;
	end
	Add(seed);
	while table.maxn(tiles) < size do
		local cands, weights, total = {}, {}, 0;
		local seen = {};
		for loop, t in ipairs(tiles) do
			for loop2, nb in ipairs(KekNeighbours(t)) do
				if not seen[nb] and not inIsland[nb] and CanUse(nb) then
					seen[nb] = true;
					local touching = 0;
					for loop3, nb2 in ipairs(KekNeighbours(nb)) do
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
		local roll = Map.Rand(total, "KEK Archipelago - island shape");
		for n, w in ipairs(weights) do
			if roll < w then Add(cands[n]); break end
			roll = roll - w;
		end
	end
	return tiles;
end
------------------------------------------------------------------------------
function KekUndoIsland(tiles, isLand)
	for loop, j in ipairs(tiles) do
		isLand[j] = nil;
		kek_islandOf[j] = nil;
	end
end
------------------------------------------------------------------------------
function KekUpdateDistToLand(dist, tiles, range)
	-- Distance to the nearest land, kept up to date as islands are added (capped at range).
	local iW, iH = Map.GetGridSize();
	for loop, t in ipairs(tiles) do
		local tx, ty = t % iW, math.floor(t / iW);
		for loop2, j in ipairs(KekPlotsInRange(tx, ty, 0, range)) do
			local d = Map.PlotDistance(tx, ty, j % iW, math.floor(j / iW));
			if d < dist[j] then dist[j] = d end
		end
	end
end
------------------------------------------------------------------------------
function KekArchipelagoSettings()
	-- All archipelago knobs in one place (lobby options -> numbers).
	local o = {};
	local startOpt = KekOpt("startisland", 3);
	o.startMin, o.startMax = 20, 40;
	if startOpt == 1 then o.startMin, o.startMax = 10, 15 elseif startOpt == 2 then o.startMin, o.startMax = 15, 25 elseif startOpt == 4 then o.startMin, o.startMax = 30, 50 end
	local expOpt = KekOpt("expansion", 1);
	o.expansionPerPlayer = ({0.5, 1, 2, 0})[expOpt] or 1;
	local islandsOpt = KekOpt("islands", 1);
	o.otherShare = ({0.06, 0.10, 0.15})[islandsOpt] or 0.10;
	local gapOpt = KekOpt("gaps", 2);
	o.gapTarget = ({2, 3, 5})[gapOpt] or 3;		-- preferred water distance to the nearest island
	o.fillDist = ({4, 4, 6})[gapOpt] or 4;		-- stepping stones wherever water is this far from any land
	local landOpt = KekOpt("landamount", 4);
	o.otherShare = o.otherShare * (({1.25, 1.5, 2.1, 2.6})[landOpt] or 1.25);
	-- Map size Normal (user 11-15): the extra room is open ocean, not more islands - the same
	-- island land as Compact (Compact is 0.87 x 0.87 of the tiles).
	-- user 11-15: Compact keeps the same feel (island density, distances); only the starts are closer
	o.otherShare = o.otherShare * 0.757
	o.fillDist = math.max(3, o.fillDist + (({0, 0, 0, -1})[landOpt] or 0));
	if landOpt == 3 then o.fillDist = math.min(o.fillDist, 4) end
	local shapeOpt = KekOpt("shapes", 1);
	o.shapes = ({{"round", "uniform", "stringy"}, {"round", "uniform"}, {"stringy", "uniform"}})[shapeOpt] or {"round", "uniform", "stringy"};
	local hillOpt = KekOpt("hills", 5);
	o.hillChance = ({20, 30, 42, 56, 76, 90})[hillOpt] or 30;
	local oceanOpt = KekOpt("ocean", 5);
	o.oceanShare = ({0.05, 0.15, 0.25, 0.35, 0.45})[oceanOpt] or 0.25;
	local resOpt = KekOpt("density", 3);						-- land resources 1-6 (2 = the old default)
	o.landBonus = ({0.04, 0.08, 0.12, 0.16, 0.20, 0.25})[resOpt] or 0.16;	-- chance per free land tile outside capitals
	o.capitalBonus = ({2, 3, 3, 4, 4, 5})[resOpt] or 4;				-- land bonus within 3 tiles of every capital
	local seaOpt = KekOpt("seaamount", 4);						-- sea resources 1-6 (2 = the old default)
	o.coastPerFish = ({8, 6, 5, 4, 3.75, 3.5, 3})[seaOpt] or 5;			-- island coast tiles per Fish
	o.capitalFish = ({1, 2, 2, 3, 3, 3, 3})[seaOpt] or 2;	-- the capital food cap decides the final split (Fish at most 3)				-- Fish within 3 tiles of every capital
	o.seaMode = KekOpt("searesources", 1);					-- 1 even, 2 varied
	o.coastLux = KekOpt("coastlux", 2);						-- 1 game's, 2 more, 3 lots
	o.atolls = KekOpt("atolls", 2);							-- 1 game's, 2 more, 3 lots
	return o;
end
------------------------------------------------------------------------------
function KekStartIslandRange()
	local o = KekArchipelagoSettings();
	return o.startMin, o.startMax;
end
------------------------------------------------------------------------------
function KekCityStateRowOK(y)
	-- City states stay out of the polar 15% of rows at each end.
	local iW, iH = Map.GetGridSize();
	return y >= math.floor(iH * 0.15) and y <= math.ceil(iH * 0.85) - 1;
end
------------------------------------------------------------------------------
function KekGenerateArchipelagoPlotTypes()
	local iW, iH = Map.GetGridSize();
	for i = 0, iW * iH - 1 do
		Map.GetPlotByIndex(i):SetPlotType(PlotTypes.PLOT_OCEAN, false, false);
	end
	kek_islandOf, kek_islands, kek_startIslands = {}, {}, {};
	local isLand, dist = {}, {};
	local allowed = {};
	for i = 0, iW * iH - 1 do
		dist[i] = 99;
		if KekIslandAllowed(i) then table.insert(allowed, i) end
	end
	local nAllowed = table.maxn(allowed);
	local bWrap = KekWrapX();

	-- Start islands: one per major civ, spread out (far from each other and,
	-- on a map without wrap, from the east and west edges), in the middle rows.
	local iNumCivs = GetPlayerAndTeamInfo();
	local k = math.max(iNumCivs, 1);
	local minSize, maxSize = KekStartIslandRange();
	-- One size for this game (in the chosen range); every start island is that size +-2 tiles.
	local startBase = minSize + Map.Rand(maxSize - minSize + 1, "KEK Archipelago - start island base size");
	local yLo, yHi = math.floor(iH * 0.25), math.ceil(iH * 0.75) - 1;
	local seeds = {};
	local rejected = {};
	local tries = 0;
	while table.maxn(kek_startIslands) < k and tries < 4 * k + 8 do
		tries = tries + 1;
		local best, bestScore = -1, -1;
		for attempt = 1, 400 do
			local i = allowed[1 + Map.Rand(nAllowed, "KEK Archipelago - start island spot")];
			local x, y = i % iW, math.floor(i / iW);
			if y >= yLo + 2 and y <= yHi - 2 and dist[i] >= 3 and not rejected[i] then
				local score = 999;
				if not bWrap then score = 3 * math.min(x, iW - 1 - x) end
				for loop, s in ipairs(seeds) do
					score = math.min(score, Map.PlotDistance(x, y, s % iW, math.floor(s / iW)));
				end
				if score > bestScore then best, bestScore = i, score end
			end
		end
		if best < 0 then break end
		local id = table.maxn(kek_islands) + 1;
		local size = math.max(minSize, math.min(maxSize, startBase - 2 + Map.Rand(5, "KEK Archipelago - start island size")));
		local startKind = KekPickStartKind();
		local tiles = KekGrowStartIsland(id, best, size, isLand, yLo, yHi, startKind);
		if tiles ~= nil and (table.maxn(tiles) >= minSize or startKind == "islet") then
			kek_islands[id] = {kind = "start", plots = tiles, startKind = startKind, fortress = (startKind == "fortress")};
			table.insert(kek_startIslands, id);
			table.insert(seeds, best);
			KekUpdateDistToLand(dist, tiles, 6);
			if startKind == "peninsula" or startKind == "cluster" or startKind == "islet" then
				-- cluster (user 11-15): a full start island and 1-2 islands of 4-7 tiles right in front of it
				local nIslets, minS, maxS = nil, nil, nil;
				if startKind == "cluster" then nIslets, minS, maxS = 1 + Map.Rand(2, "KEK start - cluster islands"), 4, 7 end
				if startKind == "islet" then
					-- the rest of this player's land in 1-2 bigger islands just across the water
					local rest = math.max(8, size - table.maxn(tiles));
					nIslets = 1 + Map.Rand(2, "KEK start - islet neighbours");
					minS = math.max(6, math.floor(rest / nIslets) - 3); maxS = minS + 6;
				end
				for loop, islet in ipairs(KekStartIslets(tiles, isLand, yLo, yHi, nIslets, minS, maxS)) do
					KekUpdateDistToLand(dist, islet, 6);
				end
			end
		else
			if tiles ~= nil then KekUndoIsland(tiles, isLand) end
			rejected[best] = true;
		end
	end
	print("KEK Archipelago: start islands", table.maxn(kek_startIslands), "for", k, "civs, size", minSize, "-", maxSize);

	-- Expansion islands (20-30 tiles), then smaller islands until the land share is
	-- reached: 3 medium (5-10 tiles) to every small one (1-3). Seeds prefer the
	-- chosen water distance to the nearest island (clusters), and now and then an
	-- island starts a new group in the most open water.
	local o = KekArchipelagoSettings();
	local land = 0;
	for i, flag in pairs(isLand) do land = land + 1 end
	local function ExpansionSize()
		-- Big islands anywhere on the map (user): 40 in 100 of 20-30 tiles, 60 of 10-20.
		local roll = Map.Rand(100, "KEK Archipelago - expansion island kind");
		if roll < 40 then return 20 + Map.Rand(11, "KEK Archipelago - expansion island size") end
		return 10 + Map.Rand(11, "KEK Archipelago - expansion island size");
	end
	local function PickShape(list)
		local shape = list[1 + Map.Rand(table.maxn(list), "KEK Archipelago - island shape kind")];
		-- user 11-15: a few less thin islands (a stringy pick is re-rolled 1 time in 4)
		if shape == "stringy" and table.maxn(list) > 1 and Map.Rand(4, "KEK Archipelago - fewer thin") == 0 then
			shape = list[1 + Map.Rand(table.maxn(list), "KEK Archipelago - island shape kind")];
		end
		kek_lastShape = shape;
		return shape;
	end
	local function PickSeed(minDist, bCityStateRows, target)
		target = target or o.gapTarget;
		local bNewGroup = (o.gapTarget < 5 and Map.Rand(100, "KEK Archipelago - new island group") < 35);
		local best, bestScore = -1, -99999;
		for attempt = 1, 40 do
			local i = allowed[1 + Map.Rand(nAllowed, "KEK Archipelago - island spot")];
			if dist[i] >= minDist and (not bCityStateRows or KekCityStateRowOK(math.floor(i / iW))) then
				local score = -math.abs(math.min(dist[i], 8) - target) * 10 + Map.Rand(12, "KEK Archipelago - island spot jitter");
				if bNewGroup then score = math.min(dist[i], 8) * 10 + Map.Rand(12, "KEK Archipelago - island spot jitter") end
				if score > bestScore then best, bestScore = i, score end
			end
		end
		return best;
	end
	local function AddIsland(kind, size, bCityStateRows, minDist, target)
		local best = PickSeed(minDist or 2, bCityStateRows, target);
		if best < 0 then return nil end
		local id = table.maxn(kek_islands) + 1;
		local shape = "round";
		if kind ~= "small" then shape = PickShape(o.shapes) end
		local tiles = KekGrowIsland(id, best, size, isLand, nil, nil, shape);
		if tiles == nil then return nil end
		if kind == "medium" and table.maxn(tiles) < 5 then kind = "small" end
		kek_islands[id] = {kind = kind, plots = tiles, shape = shape};
		KekUpdateDistToLand(dist, tiles, 8);
		land = land + table.maxn(tiles);
		return kek_islands[id];
	end
	-- Expansion islands sit between two capitals (about as far from both), not
	-- next to one: shared, contested land instead of a private backyard.
	local capitalSeeds = {};
	for loop, id in ipairs(kek_startIslands) do
		local c = kek_islands[id].plots[1];
		table.insert(capitalSeeds, {c % iW, math.floor(c / iW)});
	end
	local function PickContestedSeed()
		local best, bestScore = -1, -99999;
		for attempt = 1, 60 do
			local i = allowed[1 + Map.Rand(nAllowed, "KEK Archipelago - expansion island spot")];
			local x, y = i % iW, math.floor(i / iW);
			local okRow = (y >= math.floor(iH * 0.18) and y <= math.ceil(iH * 0.82));
			if dist[i] >= 3 and okRow then
				local d1, d2 = 999, 999;
				for loop, c in ipairs(capitalSeeds) do
					local d = Map.PlotDistance(x, y, c[1], c[2]);
					if d < d1 then d1, d2 = d, d1 elseif d < d2 then d2 = d end
				end
				if d1 >= 6 then
					local score = -(d2 - d1) * 10 - math.abs(math.min(dist[i], 8) - 4) * 4 + Map.Rand(12, "KEK Archipelago - expansion spot jitter");
					if score > bestScore then best, bestScore = i, score end
				end
			end
		end
		return best;
	end
	for n = 1, math.floor(k * o.expansionPerPlayer + 0.5) do
		local seed = PickSeed(3, false);	-- anywhere, not between two capitals (user)
		if seed >= 0 then
			local id = table.maxn(kek_islands) + 1;
			local tiles = KekGrowIsland(id, seed, ExpansionSize(), isLand, nil, nil, PickShape(o.shapes));
			if tiles ~= nil then
				local kind = "expansion";
				if table.maxn(tiles) < 5 then kind = "small" elseif table.maxn(tiles) < 10 then kind = "medium" end
				kek_islands[id] = {kind = kind, plots = tiles, shape = kek_lastShape};
				KekUpdateDistToLand(dist, tiles, 8);
				land = land + table.maxn(tiles);
			end
		end
	end
	local target = land + math.floor(nAllowed * o.otherShare);
	local failures = 0;
	while land < target and failures < 60 do
		local kind, size = "small", 1 + Map.Rand(3, "KEK Archipelago - small island size");
		if Map.Rand(4, "KEK Archipelago - island kind") < 3 then
			kind, size = "medium", 5 + Map.Rand(6, "KEK Archipelago - medium island size");
			-- varied sizes over the map (user): some of 10-15 and 15-20 as well
			local roll = Map.Rand(100, "KEK Archipelago - bigger island roll");
			if roll < 25 then size = 10 + Map.Rand(6, "KEK Archipelago - island size 10-15")
			elseif roll < 40 then size = 15 + Map.Rand(6, "KEK Archipelago - island size 15-20") end
		end
		if AddIsland(kind, size, false) == nil then failures = failures + 1 else failures = 0 end
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
		local seed = open[1 + Map.Rand(table.maxn(open), "KEK Archipelago - stepping stone spot")];
		local id = table.maxn(kek_islands) + 1;
		local stoneSizes = {1, 1, 2, 2, 3, 3, 4, 5, 6, 7, 8, 10, 12};	-- varied, more small than big
		local size = stoneSizes[1 + Map.Rand(table.maxn(stoneSizes), "KEK Archipelago - stepping stone size")];
		local tiles = KekGrowIsland(id, seed, size, isLand, nil, nil, PickShape(o.shapes));
		if tiles == nil then
			stoneFails = stoneFails + 1;
		else
			local kind = "medium";
			if table.maxn(tiles) < 5 then kind = "small" end
			kek_islands[id] = {kind = kind, plots = tiles};
			KekUpdateDistToLand(dist, tiles, 8);
			land = land + table.maxn(tiles);
		end
	end

	-- City states need islands of 4+ tiles outside the polar rows: make sure
	-- there is one for each of them (and a few spare).
	local iNumCivsAgain, iNumCityStates = GetPlayerAndTeamInfo();
	local function CityStateIslands()
		local n = 0;
		for id, island in ipairs(kek_islands) do
			if island.kind ~= "start" and table.maxn(island.plots) >= 4 then
				local okRows = 0;
				for loop, i in ipairs(island.plots) do
					if KekCityStateRowOK(math.floor(i / iW)) then okRows = okRows + 1 end
				end
				if okRows > 0 then n = n + 1 end
			end
		end
		return n;
	end
	local need = iNumCityStates + 2;
	local have = CityStateIslands();
	failures = 0;
	while have < need and failures < 60 do
		local island = AddIsland("medium", 5 + Map.Rand(4, "KEK Archipelago - city state island size"), true);
		if island ~= nil and table.maxn(island.plots) >= 4 then
			have = have + 1;
			failures = 0;
		else
			failures = failures + 1;
		end
	end

	-- Hills (option) and a few mountains on the bigger islands, none on start islands.
	-- The thinner the island (share of its tiles with 3+ water neighbours), the
	-- more hills (and later Fish): round about 0.75x the option, stringy up to 1.3x.
	KekWidenStringy(isLand);
	local anyLand = {};
	for id, island in ipairs(kek_islands) do
		for loop, i in ipairs(island.plots) do anyLand[i] = true end
	end
	for id, island in ipairs(kek_islands) do
		local thinTiles = 0;
		for loop, i in ipairs(island.plots) do
			local water = 0;
			for loop2, nb in ipairs(KekNeighbours(i)) do
				if not anyLand[nb] then water = water + 1 end
			end
			if water >= 3 then thinTiles = thinTiles + 1 end
		end
		island.thin = thinTiles / math.max(1, table.maxn(island.plots));
	end
	local startMountain = (Map.Rand(2, "KEK Archipelago - start island mountain") == 0);
	for id, island in ipairs(kek_islands) do
		local n = table.maxn(island.plots);
		for loop, i in ipairs(island.plots) do
			local plotType = PlotTypes.PLOT_LAND;
			local hillChance = math.min(97, math.floor(o.hillChance * (0.5 + 0.8 * island.thin) + 0.5));
			-- user 11-15: thin land is about 30% flat (at most 70% hills)
			if island.shape == "stringy" or island.thin > 0.6 then hillChance = math.min(hillChance, 70) end
			-- towards the top and bottom of the map: flatter (half the hills in the outer quarter of rows)
			do
				local yy = math.floor(i / iW);
				if math.min(yy, iH - 1 - yy) < math.floor(iH * 0.25) then hillChance = math.floor(hillChance * 0.5) end
			end
			if island.fortress then
				-- fortress start (user 11-15): a hilly shore, easy to defend
				local coast = false;
				for loop2, nb in ipairs(KekNeighbours(i)) do if not anyLand[nb] then coast = true end end
				if coast then hillChance = math.min(97, hillChance + 30) end
			end
			if Map.Rand(100, "KEK Archipelago - hills") < hillChance then plotType = PlotTypes.PLOT_HILLS end
			Map.GetPlotByIndex(i):SetPlotType(plotType, false, false);
		end
		if island.kind ~= "start" and island.kind ~= "small" and n >= 7 then
			local mountains = 0;
			if Map.Rand(100, "KEK Archipelago - mountain") < 55 then mountains = 1 end	-- user 11-15: more (was 35)
			if island.kind == "expansion" then mountains = 1 + Map.Rand(2, "KEK Archipelago - mountains") end
			for m = 1, mountains do
				local i = island.plots[1 + Map.Rand(n, "KEK Archipelago - mountain spot")];
				Map.GetPlotByIndex(i):SetPlotType(PlotTypes.PLOT_MOUNTAIN, false, false);
			end
		end
		-- Now and then (1 game in 2) every start island gets one mountain, inland
		-- when possible (user: Machu Picchu needs one). The same for everybody.
		-- user 11-15: about 1 start island in 3 has a mountain (each its own roll), not all or none
		if island.kind == "start" and n >= 10 and Map.Rand(3, "KEK Archipelago - start mountain roll") == 0 then
			local own, inland = {}, {};
			for loop, t in ipairs(island.plots) do own[t] = true end
			for loop, t in ipairs(island.plots) do
				local all = true;
				for loop2, j2 in ipairs(KekNeighbours(t)) do
					if not own[j2] then all = false end
				end
				if all then table.insert(inland, t) end
			end
			local list = island.plots;
			if table.maxn(inland) > 0 then list = inland end
			local t = list[1 + Map.Rand(table.maxn(list), "KEK Archipelago - start island mountain spot")];
			Map.GetPlotByIndex(t):SetPlotType(PlotTypes.PLOT_MOUNTAIN, false, false);
		end
	end
	-- Speed vs scaling (user, 11-14): bigger free islands get fresh water, a
	-- lake tile inside (1 from 15 tiles, 2 from 28); start islands never.
	for id, island in ipairs(kek_islands) do
		local n = table.maxn(island.plots);
		if island.kind ~= "start" and island.kind ~= "own" and n >= 15 then
			local own = {};
			for loop, t in ipairs(island.plots) do own[t] = true end
			local inland = {};
			for loop, t in ipairs(island.plots) do
				local all = true;
				for loop2, j2 in ipairs(KekNeighbours(t)) do if not own[j2] then all = false end end
				if all and not Map.GetPlotByIndex(t):IsMountain() then table.insert(inland, t) end
			end
			local want = 1;
			if n >= 28 then want = 2 end
			local made = {};
			while table.maxn(made) < want and table.maxn(inland) > 0 do
				local t = table.remove(inland, 1 + Map.Rand(table.maxn(inland), "KEK Archipelago - island lake"));
				local far = true;
				for loop, m in ipairs(made) do
					if Map.PlotDistance(t % iW, math.floor(t / iW), m % iW, math.floor(m / iW)) < 3 then far = false end
				end
				if far then
					Map.GetPlotByIndex(t):SetPlotType(PlotTypes.PLOT_OCEAN, false, false);
					own[t] = nil;
					kek_islandOf[t] = nil;
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
	print("KEK Archipelago: islands", table.maxn(kek_islands), "land", land, "target", target, "of", nAllowed, "city state islands", have);

end
------------------------------------------------------------------------------
function KekArchipelagoCoasts()
	-- Water next to land is always coast. Of the rest, the tiles nearest to land
	-- (with a little noise for natural edges) become coast until only the chosen
	-- share of all water is deep ocean.
	local iW, iH = Map.GetGridSize();
	local share = 0.30;
	share = KekArchipelagoSettings().oceanShare;
	local dist, queue, head = {}, {}, 1;
	local nWater = 0;
	for i = 0, iW * iH - 1 do
		if Map.GetPlotByIndex(i):IsWater() then
			nWater = nWater + 1;
		else
			dist[i] = 0;
			table.insert(queue, i);
		end
	end
	while head <= table.maxn(queue) do
		local c = queue[head];
		head = head + 1;
		for loop, nb in ipairs(KekNeighbours(c)) do
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
				table.insert(far, {i = i, key = (dist[i] or 99) * 100 + Map.Rand(150, "KEK Archipelago - coast edge")});
			end
		end
	end
	table.sort(far, function(a, b) if a.key ~= b.key then return a.key < b.key end return a.i < b.i end);
	local nCoast = table.maxn(far) - math.floor(nWater * share + 0.5);
	for rank, entry in ipairs(far) do
		local terrain = TerrainTypes.TERRAIN_OCEAN;
		if rank <= nCoast then terrain = TerrainTypes.TERRAIN_COAST end
		Map.GetPlotByIndex(entry.i):SetTerrainType(terrain, false, false);
	end
end
------------------------------------------------------------------------------
function GeneratePlotTypes()
	print("Generating Plot Types (KEK Archipelago) ...");
	KekGenerateArchipelagoPlotTypes();
	GenerateCoasts({bExpandCoasts = false});
	KekArchipelagoCoasts();
end
------------------------------------------------------------------------------
function GenerateTerrain()
	print("Generating Terrain (KEK Archipelago) ...");
	local temp = KekOpt(KEK_OPT_TEMP, 2);
	if temp == 4 then
		temp = 1 + Map.Rand(3, "Random Temperature - Lua");
	end
	local terraingen = TerrainGenerator.Create({temperature = temp});
	local terrainTypes = terraingen:GenerateTerrain();
	SetTerrainTypes(terrainTypes);
	KekPolarTundra();
end
------------------------------------------------------------------------------
function AddLakes()
	-- No lakes: they would eat into the islands and change their sizes.
end
------------------------------------------------------------------------------
function AddFeatures()
	print("Adding Features (KEK Archipelago) ...");
	local rain = KekOpt(KEK_OPT_RAIN, 3);
	if rain == 4 then
		rain = 1 + Map.Rand(3, "Random Rainfall - Lua");
	end
	-- user 11-15: more forest and jungle (the game's defaults are 12% jungle, 18% forest)
	local featuregen = FeatureGenerator.Create({rainfall = rain, iJunglePercent = 20, iForestPercent = 28});
	-- False parameter removes mountains from coastlines.
	featuregen:AddFeatures(false);
	KekPolarForests();
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- START PLOT SYSTEM: one region per start island
------------------------------------------------------------------------------
function AssignStartingPlots:GenerateRegions(args)
	print("Map Generation - Dividing the map in to Regions (KEK Archipelago)");
	local iW, iH = Map.GetGridSize();
	self.method = 3;			-- rectangles (water inside them is ignored by the region measuring)
	self.resource_setting = 5;	-- strategic balance

	self.iNumCivs, self.iNumCityStates, self.player_ID_list, self.bTeamGame, self.teams_with_major_civs, self.number_civs_per_team = GetPlayerAndTeamInfo()
	self.iNumCityStatesUnassigned = self.iNumCityStates;
	print("-"); print("Civs:", self.iNumCivs); print("City States:", self.iNumCityStates);

	self.kek_regionArea = {};
	self.kek_startIslandArea = {};
	self.regionData = {};
	local function Box(tiles)
		local x0, y0, x1, y1 = 9999, 9999, -1, -1;
		for loop, i in ipairs(tiles) do
			local x, y = i % iW, math.floor(i / iW);
			x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y);
		end
		return x0, y0, x1 - x0 + 1, y1 - y0 + 1;
	end
	for r = 1, self.iNumCivs do
		local id = kek_startIslands[r];
		if id == nil then
			-- Not enough room for a start island (should not happen): fall back to the biggest free island.
			print("KEK Archipelago WARNING: no start island for civ", r);
			local bestId, bestSize = -1, -1;
			for n, island in ipairs(kek_islands) do
				if island.kind ~= "start" and table.maxn(island.plots) > bestSize then bestId, bestSize = n, table.maxn(island.plots) end
			end
			id = bestId;
			kek_islands[id].kind = "start";
			kek_startIslands[r] = id;
		end
		local tiles = kek_islands[id].plots;
		local x, y, w, h = Box(tiles);
		-- The area of a passable tile (a mountain from a natural wonder would have its own).
		local area = -1;
		for loop, i in ipairs(tiles) do
			local plot = Map.GetPlotByIndex(i);
			if not plot:IsWater() and not plot:IsMountain() then area = plot:GetArea(); break end
		end
		local fert = 0;
		for loop, i in ipairs(tiles) do
			fert = fert + self:MeasureStartPlacementFertilityOfPlot(i % iW, math.floor(i / iW), true);
		end
		local n = table.maxn(tiles);
		table.insert(self.regionData, {x, y, w, h, area, fert, n, fert / n});
		self.kek_regionArea[r] = area;
		self.kek_startIslandArea[area] = true;
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:ChooseLocations(args)
	print("Map Generation - Choosing Start Locations for Civilizations (KEK Archipelago)");
	-- Like the game's own, but every civ is placed on its own start island
	-- (FindStart respects the region's area).
	local args = args or {};
	self.minFoodMiddle = args.minFoodMiddle or self.minFoodMiddle;
	self.minFoodOuter = args.minFoodOuter or self.minFoodOuter;
	self.minProdOuter = args.minProdOuter or self.minProdOuter;

	self:MeasureTerrainInRegions()
	self:DetermineRegionTypes()

	-- Poorest regions first, as the core game does.
	local regionAssignList = {};
	local unsorted, sorted = {}, {};
	for i, region_data in ipairs(self.regionData) do
		table.insert(unsorted, {i, region_data[8]});
		table.insert(sorted, region_data[8]);
	end
	table.sort(sorted);
	for region_order = 1, table.maxn(sorted) do
		for loop, data_pair in ipairs(unsorted) do
			if sorted[region_order] == data_pair[2] then
				table.insert(regionAssignList, data_pair[1]);
				table.remove(unsorted, loop);
				break
			end
		end
	end
	for loop, region_number in ipairs(regionAssignList) do
		self:FindStart(region_number);
		KekCheckStartOnIsland(self, region_number);
	end
end
------------------------------------------------------------------------------
function KekCheckStartOnIsland(asp, region_number)
	-- FindStart's last resort forces a start on the region's south-west corner,
	-- which can be water. Keep the start on its own island instead, and always
	-- on the coast (user: everyone starts on the coast on the island maps).
	local data = asp.startingPlots[region_number];
	local area = asp.kek_regionArea[region_number];
	local plot = Map.GetPlot(data[1], data[2]);
	-- user 11-15: never on a neck (a tile with fewer than 3 land neighbours)
	local function LandNb(p)
		local c = 0;
		for d = 0, 5 do
			local q = Map.PlotDirection(p:GetX(), p:GetY(), d);
			if q ~= nil and not q:IsWater() then c = c + 1 end
		end
		return c;
	end
	if plot ~= nil and plot:GetArea() == area and not plot:IsWater() and not plot:IsMountain() and plot:IsCoastalLand() and LandNb(plot) >= 3 then return end
	local iW, iH = Map.GetGridSize();
	local tiles = kek_islands[kek_startIslands[region_number]].plots;
	local bestIndex, bestScore = -1, -99999;
	for pass = 1, 3 do
		for loop, i in ipairs(tiles) do
			local p = Map.GetPlotByIndex(i);
			if p:GetArea() == area and not p:IsWater() and not p:IsMountain() and (pass == 3 or p:IsCoastalLand())
				and (pass >= 2 or LandNb(p) >= 3) then
				local score = asp:EvaluateCandidatePlot(i + 1, asp.regionTypes[region_number]);
				if score > bestScore then bestIndex, bestScore = i, score end
			end
		end
		if bestIndex >= 0 then break end
	end
	if bestIndex >= 0 then
		if plot ~= nil and plot:IsWater() then
			-- undo the forced one-tile island
			plot:SetPlotType(PlotTypes.PLOT_OCEAN, false, true);
			plot:SetTerrainType(GameDefines.SHALLOW_WATER_TERRAIN, false, true);
		end
		local x, y = bestIndex % iW, math.floor(bestIndex / iW);
		print("KEK Archipelago: start of region", region_number, "moved onto its island at", x, y);
		asp.startingPlots[region_number] = {x, y, bestScore};
		asp:PlaceImpactAndRipples(x, y);
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:CanPlaceCityStateAt(x, y, area_ID, force_it, ignore_collisions)
	-- City states: never on a start island, only on islands of 4 tiles or more,
	-- not in the polar rows, not on the map edge.
	local iW, iH = Map.GetGridSize();
	local plot = Map.GetPlot(x, y)
	if plot == nil then return false end
	local area = plot:GetArea()
	if area ~= area_ID and area_ID ~= -1 then
		return false
	end
	if y < 1 or y >= iH - 1 then return false end
	if not KekWrapX() and (x < 1 or x >= iW - 1) then return false end
	if not KekCityStateRowOK(y) then return false end
	if self.kek_startIslandArea ~= nil and self.kek_startIslandArea[area] then return false end
	local a = Map.GetArea(area);
	if a == nil or a:GetNumTiles() < 4 then return false end
	local plotType = plot:GetPlotType()
	if plotType == PlotTypes.PLOT_OCEAN or plotType == PlotTypes.PLOT_MOUNTAIN then
		return false
	end
	if plot:GetTerrainType() == TerrainTypes.TERRAIN_SNOW then
		return false
	end
	local plotIndex = y * iW + x + 1;
	if self.cityStateData[plotIndex] > 0 and force_it == false then
		return false
	end
	if self.playerCollisionData[plotIndex] == true and ignore_collisions == false then
		return false
	end
	return true
end
------------------------------------------------------------------------------
function KekRecordCityState(asp, cs_number, x, y)
	-- Same bookkeeping the core game does for a placed city state.
	local iW, iH = Map.GetGridSize();
	asp.cityStatePlots[cs_number] = {x, y, -1};
	asp.city_state_validity_table[cs_number] = true;
	asp.city_state_region_assignments[cs_number] = -1;
	local city_state_ID = cs_number + GameDefines.MAX_MAJOR_CIVS - 1;
	Players[city_state_ID]:SetStartingPlot(Map.GetPlot(x, y))
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
function AssignStartingPlots:PlaceCityStates()
	print("Map Generation - Choosing sites for City States (KEK Archipelago)");
	-- Each city state goes to the valid site farthest from the capitals and the
	-- city states already placed (with a little dice), preferring islands that
	-- have no city state yet. Pass 1 keeps the core spacing rule, pass 2 drops
	-- it, so every city state gets a site while any valid plot is left.
	local iW, iH = Map.GetGridSize();
	local capitals = {};
	for loop, data in ipairs(self.startingPlots) do table.insert(capitals, {data[1], data[2]}) end
	local placed = {};
	local usedArea = {};
	for cs_number = 1, self.iNumCityStates do
		local done = false;
		local wantCap = 8 + Map.Rand(6, "KEK Archipelago - city state distance");
		if Map.Rand(3, "KEK Archipelago - city state close") == 0 then wantCap = 5 + Map.Rand(3, "KEK Archipelago - city state close distance") end
		for pass = 1, 2 do
			if done then break end
			local force_it = (pass == 2);
			local bestIndex, bestScore = -1, -99999;
			for i = 0, iW * iH - 1 do
				local x, y = i % iW, math.floor(i / iW);
				if self:CanPlaceCityStateAt(x, y, -1, force_it, false) then
					local dCap, dCS = 99, 99;
					for loop, c in ipairs(capitals) do dCap = math.min(dCap, Map.PlotDistance(x, y, c[1], c[2])) end
					for loop, c in ipairs(placed) do dCS = math.min(dCS, Map.PlotDistance(x, y, c[1], c[2])) end
					local plot = Map.GetPlot(x, y);
					-- user 11-15: not all far out at the top and bottom: each city state wants its own
					-- distance to the nearest capital (1 in 3 close, 5-7), and they spread out from each other.
					local score = -math.abs(math.min(dCap, 16) - wantCap) * 8 + math.min(dCS, 14) * 8 + Map.Rand(8, "KEK Archipelago - city state site");
					if dCap < 5 then score = score - 300 end
					if usedArea[plot:GetArea()] then score = score - 200 end
					if plot:IsCoastalLand() then score = score + 5 end
					if score > bestScore then bestIndex, bestScore = i, score end
				end
			end
			if bestIndex >= 0 then
				local x, y = bestIndex % iW, math.floor(bestIndex / iW);
				KekRecordCityState(self, cs_number, x, y);
				table.insert(placed, {x, y});
				usedArea[Map.GetPlot(x, y):GetArea()] = true;
				done = true;
			end
		end
		if not done then
			print("KEK Archipelago WARNING: no site left for city state", cs_number);
			self.iNumCityStatesDiscarded = self.iNumCityStatesDiscarded + 1;
		end
	end
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- STRATEGIC BALANCE: Horses + Iron in the capital, Coal + Aluminium nearby
------------------------------------------------------------------------------
kek_resourceRules = nil;
KEK_CAPITAL_COAL = 7;			-- Coal at every capital
KEK_CAPITAL_ALUMINIUM = 3;		-- Aluminium at every capital
KEK_CAPITAL_IRON = 9;			-- Iron at every capital (user 11-15: 9; was 12, then 6 = too weak)
ARCHIPELAGO_OIL_FACTOR = 1.5;	-- user 11-15: 60% of the 11-14 amount (2.5 was too much)
CAPITAL_EXTRA_MAX = 6;		-- user 11-15: at most 6 (4 was too weak) extra non-luxury resources within 3 of a capital

------------------------------------------------------------------------------
function KekLoadResourceRules()
	-- Which terrain / feature / plot type each resource may sit on, read from the
	-- game database at run time (so mods that change the rules are respected).
	if kek_resourceRules ~= nil then return end
	kek_resourceRules = {};
	for row in GameInfo.Resources() do
		kek_resourceRules[row.ID] = {
			hills = (row.Hills == true or row.Hills == 1),
			flat = (row.Flatlands == true or row.Flatlands == 1),
			noRiver = (row.NoRiverSide == true or row.NoRiverSide == 1),
			terrain = {}, feature = {}, featureTerrain = {},
		};
	end
	for row in GameInfo.Resource_TerrainBooleans() do
		local res, terrain = GameInfo.Resources[row.ResourceType], GameInfo.Terrains[row.TerrainType];
		if res ~= nil and terrain ~= nil then
			kek_resourceRules[res.ID].terrain[terrain.ID] = true;
		end
	end
	for row in GameInfo.Resource_FeatureBooleans() do
		local res, feature = GameInfo.Resources[row.ResourceType], GameInfo.Features[row.FeatureType];
		if res ~= nil and feature ~= nil then
			kek_resourceRules[res.ID].feature[feature.ID] = true;
		end
	end
	for row in GameInfo.Resource_FeatureTerrainBooleans() do
		local res, terrain = GameInfo.Resources[row.ResourceType], GameInfo.Terrains[row.TerrainType];
		if res ~= nil and terrain ~= nil then
			kek_resourceRules[res.ID].featureTerrain[terrain.ID] = true;
		end
	end
end
------------------------------------------------------------------------------
function KekResourceFits(plot, resID, bRespectRiver)
	-- Same rules the game uses for "can this resource be here".
	KekLoadResourceRules();
	local rules = kek_resourceRules[resID];
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
function KekPlanResourceFix(plot, resID)
	-- How to turn this plot into a valid spot for the resource, changing as little
	-- as possible. Returns cost (nil if not possible), new plot type, new terrain,
	-- and whether the feature has to go.
	KekLoadResourceRules();
	local rules = kek_resourceRules[resID];
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
function KekPlotsInRings(x, y, minRing, maxRing)
	-- Plots between minRing and maxRing tiles from (x, y), in a fixed order.
	local list = {};
	for loop, i in ipairs(KekPlotsInRange(x, y, minRing, maxRing)) do
		table.insert(list, Map.GetPlotByIndex(i));
	end
	return list;
end
------------------------------------------------------------------------------
function KekEnsureResourceNear(asp, x, y, resID, amount, minRing, maxRing, preferMinRing)
	-- Makes sure a deposit of at least "amount" resID lies minRing..maxRing tiles from (x, y).
	-- Never stacks on another resource (luxuries stay), never on a start plot,
	-- natural wonder, oasis or flood plains.
	if resID == nil then return false end
	local plots = KekPlotsInRings(x, y, minRing, maxRing);
	-- A deposit already there counts if its tile is valid for it. (The core game's
	-- placement sometimes puts Iron in a forest; such a tile is fixed in place.)
	local best, bestInvalid = nil, nil;
	for loop, plot in ipairs(plots) do
		if plot:GetResourceType(-1) == resID then
			if KekResourceFits(plot, resID, false) then
				if best == nil or plot:GetNumResource() > best:GetNumResource() then
					best = plot;
				end
			elseif KekPlanResourceFix(plot, resID) ~= nil and not plot:IsStartingPlot() then
				if bestInvalid == nil or plot:GetNumResource() > bestInvalid:GetNumResource() then
					bestInvalid = plot;
				end
			end
		end
	end
	if best == nil and bestInvalid ~= nil then
		local cost, plotType, terrain, removeFeature = KekPlanResourceFix(bestInvalid, resID);
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
				free = true;	-- very last resort (small island): Oil, which is not promised, makes room
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
				if KekResourceFits(plot, resID, true) then
					table.insert(fits, plot);
				else
					local cost = KekPlanResourceFix(plot, resID);
					if cost ~= nil then
						local riverBlocked = kek_resourceRules[resID].noRiver and plot:IsRiverSide();
						if riverBlocked then
							table.insert(riverOnly, plot);
						else
							table.insert(fixable, plot);
							table.insert(fixCost, cost);
							if cost < bestCost then bestCost = cost end
						end
					elseif KekResourceFits(plot, resID, false) then
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
		chosen = fits[1 + Map.Rand(table.maxn(fits), "KEK Archipelago - strategic spot")];
	elseif table.maxn(fixable) > 0 then
		local cheapest = {};
		for n, plot in ipairs(fixable) do
			if fixCost[n] == bestCost then table.insert(cheapest, plot) end
		end
		chosen = cheapest[1 + Map.Rand(table.maxn(cheapest), "KEK Archipelago - strategic spot")];
	elseif table.maxn(riverOnly) > 0 then
		chosen = riverOnly[1 + Map.Rand(table.maxn(riverOnly), "KEK Archipelago - strategic spot")];
	end
	if chosen == nil then
		print("KEK Archipelago WARNING: no room for resource", resID, "near start", x, y);
		return false
	end
	if chosen:GetResourceType(-1) ~= -1 then
		chosen:SetResourceType(-1, 0);
	end
	if not KekResourceFits(chosen, resID, false) then
		local cost, plotType, terrain, removeFeature = KekPlanResourceFix(chosen, resID);
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
function KekEnsureCapitalStrategics(asp, region_number)
	-- Horses, Iron, Coal and Aluminium all within 3 tiles of the capital.
	-- Horses and Iron are big deposits, as the core strategic balance uses;
	-- Coal 7 and Aluminium 3, placed in rings 2-3 when a valid tile is there.
	local data = asp.startingPlots[region_number];
	if data == nil then return end
	local x, y = data[1], data[2];
	local uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = asp:GetMajorStrategicResourceQuantityValues();
	KekEnsureResourceNear(asp, x, y, asp.horse_ID, horse_amt, 1, 3);
	KekEnsureResourceNear(asp, x, y, asp.iron_ID, KEK_CAPITAL_IRON, 1, 3);
	KekEnsureResourceNear(asp, x, y, asp.coal_ID, KEK_CAPITAL_COAL, 1, 3, 2);
	KekEnsureResourceNear(asp, x, y, asp.aluminum_ID, KEK_CAPITAL_ALUMINIUM, 1, 3, 2);
end
------------------------------------------------------------------------------
KekBase_AddStrategicBalanceResources = AssignStartingPlots.AddStrategicBalanceResources;
function AssignStartingPlots:AddStrategicBalanceResources(region_number)
	-- The core game adds Iron, Horses and Oil here. Then Horses and Iron are
	-- checked to be really inside the capital, and Coal and Aluminium are added.
	KekBase_AddStrategicBalanceResources(self, region_number);
	KekEnsureCapitalStrategics(self, region_number);
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- FISH AROUND ISLANDS ("Varied")
------------------------------------------------------------------------------
function KekIslandFish(asp)
	-- Archipelago resources:
	--  1. capitals levelled: exactly N Fish and at least M land bonus within 3 tiles,
	--     plus one sea luxury when coastal luxuries are "More"/"Lots";
	--  2. Fish around the other islands, spread evenly by coast length ("Even") or
	--     rich/poor islands ("Varied");
	--  3. land bonus resources by the density option (outside the capitals);
	--  4. extra coastal luxuries (Whales, Pearls, Crab) and atolls on the open coasts.
	local o = KekArchipelagoSettings();
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
	for r = 1, asp.iNumCivs do
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
		return plot:IsWater() and not plot:IsLake()
			and plot:GetTerrainType() == TerrainTypes.TERRAIN_COAST and plot:GetResourceType(-1) == -1
			and plot:GetFeatureType() == FeatureTypes.NO_FEATURE and plot:GetImprovementType() == -1 and plot:IsAdjacentToLand();
	end
	local function IsBonus(res)
		return res ~= -1 and GameInfo.Resources[res] ~= nil and GameInfo.Resources[res].ResourceUsage == 0;
	end
	local function TakeRandom(list)
		return table.remove(list, 1 + Map.Rand(table.maxn(list), "KEK Archipelago - resource spot"));
	end
	local stats = {fishAdded = 0, fishRemoved = 0, bonusAdded = 0, lux = 0, atolls = 0};

	-- 1. Capitals.
	for loop, data in ipairs(capitals) do
		local x, y = data[1], data[2];
		local fishPlots, freeSea, bonusLand, freeLand, haveLux = {}, {}, 0, {}, false;
		local nearSea = {};		-- free coast within 2 tiles: Fish there is worked from turn 1
		for dy = -3, 3 do
			for dx = -4, 4 do
				local plot = Map.PlotXYWithRangeCheck(x, y, dx, dy, 3);
				if plot ~= nil then
					local i = plot:GetY() * iW + plot:GetX();
					local d = Map.PlotDistance(x, y, plot:GetX(), plot:GetY());
					if d >= 1 and d <= 3 then
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
			Map.GetPlotByIndex(TakeRandom(freeSea)):SetResourceType(seaLux[1 + Map.Rand(table.maxn(seaLux), "KEK Archipelago - sea luxury")], 1);
			stats.lux = stats.lux + 1;
		end
		while bonusLand < o.capitalBonus and table.maxn(freeLand) > 0 do
			local plot = table.remove(freeLand, 1 + Map.Rand(table.maxn(freeLand), "KEK Archipelago - capital bonus"));
			if asp:AttemptToPlaceBonusResourceAtPlot(plot:GetX(), plot:GetY(), false) then
				bonusLand = bonusLand + 1;
				stats.bonusAdded = stats.bonusAdded + 1;
			end
		end
	end

	-- 2. + 3. The other islands (and start-island land beyond the capital's 3 tiles).
	local luxSpots = {};
	for id, island in ipairs(kek_islands) do
		local water, seen, have = {}, {}, 0;
		for loop, t in ipairs(island.plots) do
			for loop2, nb in ipairs(KekNeighbours(t)) do
				if not seen[nb] and CapitalDist(nb) > 3 then
					seen[nb] = true;
					local plot = Map.GetPlotByIndex(nb);
					if plot:IsWater() then
						if plot:GetResourceType(-1) == fishID then
							have = have + 1;
						elseif FreeCoast(nb) then
							table.insert(water, nb);
						end
					end
				end
			end
			-- land bonus by density
			if o.landBonus > 0 and CapitalDist(t) > 3 then
				local plot = Map.GetPlotByIndex(t);
				if not plot:IsMountain() and plot:GetResourceType(-1) == -1 and plot:GetImprovementType() == -1
					and Map.Rand(1000, "KEK Archipelago - land bonus") < o.landBonus * 1000 then
					if asp:AttemptToPlaceBonusResourceAtPlot(plot:GetX(), plot:GetY(), false) then
						stats.bonusAdded = stats.bonusAdded + 1;
					end
				end
			end
		end
		local nCoast = table.maxn(water) + have;
		local want = math.floor(nCoast / o.coastPerFish * (0.8 + 0.6 * (island.thin or 0.5)) + 0.5);
		if island.kind == "small" then want = math.max(want, 1) end
		if o.seaMode == 2 and island.kind ~= "start" then
			local roll = Map.Rand(100, "KEK Archipelago - island richness");
			if roll < 30 then want = 0 elseif roll >= 75 then want = want + 1 + Map.Rand(2, "KEK Archipelago - fish") end
		end
		-- spread out: a new Fish never next to another one
		local function NextToFish(i)
			for loop, nb in ipairs(KekNeighbours(i)) do
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
	local nLux = ({0, asp.iNumCivs, 2 * asp.iNumCivs})[o.coastLux] or 0;
	local nAtolls = ({0, 2 * asp.iNumCivs, 4 * asp.iNumCivs})[o.atolls] or 0;
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
		if FreeCoast(i) and CapitalDist(i) >= 3 then
			local plot = Map.GetPlotByIndex(i);
			if nLux > 0 and table.maxn(seaLux) > 0 and Spaced(i, 4) then
				plot:SetResourceType(seaLux[1 + Map.Rand(table.maxn(seaLux), "KEK Archipelago - sea luxury")], 1);
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
	print("KEK Archipelago : fish +", stats.fishAdded, "-", stats.fishRemoved, "land bonus +", stats.bonusAdded,
		"sea luxuries +", stats.lux, "atolls +", stats.atolls);
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
function AssignStartingPlots:PlaceResourcesAndCityStates()
	-- The core game's order of operations, plus the island fish and the
	-- strategic balance once more at the end.
	print("Map Generation - Assigning Luxury Resource Distribution");
	self:AssignLuxuryRoles()

	print("Map Generation - Placing City States");
	self:PlaceCityStates()

	self:GenerateGlobalResourcePlotLists()

	print("Map Generation - Placing Luxuries");
	self:PlaceLuxuries()

	self:PlaceStrategicAndBonusResources()

	print("Map Generation - Normalize City State Locations");
	self:NormalizeCityStateLocations()

	self:FixSugarJungles()

	-- More Fish at small islands, some islands rich, some poor.
	KekIslandFish(self);
	KekIslandScaling(self);

	-- Every capital gets its regional luxury, 2 at home and 3 on the islands around (user).
	KekRegionLuxuryAtCapitals(self, self.iNumCivs);

	-- 3-5 bonus resources at every capital, not more (user).
	KekCapitalBonusCap(self, self.iNumCivs);
	KekCapitalLuxuries(self, self.iNumCivs);
	KekCapitalSeaLux(self, self.iNumCivs);
	-- user 11-15: rounder islands get a couple of land resources, coastal luxuries a Fish.
	KekBulbLandResources(self, self.iNumCivs);
	KekCoastLuxFish(self, self.iNumCivs);

	-- No city site with more than a handful of Fish (user).
	KekFishCityCap(self, self.iNumCivs, ({3, 4, 5, 5, 5, 6, 7})[KekOpt("seaamount", 4)] or 5);
	-- user 11-15: even city sites - no spot with a pile of resources, no island with none.
	KekFarLands(self, self.iNumCivs);
	KekSiteSmoothing(self, self.iNumCivs);

	-- More Oil, one on every home island and one at sea (user).
	KekMoreOil(self, self.iNumCivs, ARCHIPELAGO_OIL_FACTOR);
	-- City states richer, so they are worth taking.
	KekCityStateBoost(self);
	-- a sea luxury that became someone's regional is only theirs (user 11-15)
	KekRegionalsAtHome(self, self.iNumCivs);

	-- Strategic balance once more, now that everything else is placed.
	for region_number = 1, self.iNumCivs do
		KekEnsureCapitalStrategics(self, region_number);
	end

	-- Must be last: invalidates all regional data by resetting Area IDs.
	Map.RecalculateAreas();

	self:PrintFinalResourceTotalsToLog()
end
------------------------------------------------------------------------------
function StartPlotSystem()
	print("Creating start plot database.");
	local start_plot_database = AssignStartingPlots.Create()
	kek_startPlotDatabase = start_plot_database;

	print("Dividing the map in to Regions (KEK Archipelago).");
	start_plot_database:GenerateRegions()

	print("Choosing start locations for civilizations.");
	start_plot_database:ChooseLocations({minFoodMiddle = 2, minFoodOuter = 3, minProdOuter = 1})

	print("Normalizing start locations and assigning them to Players.");
	start_plot_database:BalanceAndAssign()

	print("Placing Natural Wonders.");
	start_plot_database:PlaceNaturalWonders()

	print("Placing Resources and City States.");
	start_plot_database:PlaceResourcesAndCityStates()

	-- Tell the AI that this is a naval expansion map (as the game's Archipelago does).
	if Map.ChangeAIMapHint ~= nil then
		Map.ChangeAIMapHint(1 + 4);
	end
end
------------------------------------------------------------------------------
function GenerateMap()
	print("Generating Map (KEK Archipelago)");
	kek_neighbours = {};

	GeneratePlotTypes();
	GenerateTerrain();
	Map.RecalculateAreas();
	AddRivers();
	AddLakes();
	KekIslandMountainsAndRivers();
	AddFeatures();
	Map.RecalculateAreas();

	StartPlotSystem();
	if kek_startPlotDatabase ~= nil then KekCapitalRivers(kek_startPlotDatabase, kek_startPlotDatabase.iNumCivs) end

	AddGoodies();

	-- Strategic balance one last time (nothing after this changes resources).
	if kek_startPlotDatabase ~= nil then
		for region_number = 1, kek_startPlotDatabase.iNumCivs do
			KekEnsureCapitalStrategics(kek_startPlotDatabase, region_number);
		end
		KekCapitalExtraCap(kek_startPlotDatabase, kek_startPlotDatabase.iNumCivs, math.max(math.max(3, KekOpt("capstrength", 5) - 2), (CAPITAL_FOOD_WANT or 0) + 1));
	end
	Map.RecalculateAreas();

	KekJungleOnPlains();
	DetermineContinents();
end
------------------------------------------------------------------------------
------------------------------------------------------------------------------
function KekCityStateBoost(asp)
	-- City states worth taking (user, 11-14): within 2 tiles every city state
	-- gets at least 3 food bonus (land bonus or Fish) and within 3 tiles at
	-- least 2 luxuries (land, or Whales/Pearls/Crab on the coast).
	if asp.cityStatePlots == nil then return end
	KekLoadResourceRules();
	local iW, iH = Map.GetGridSize();
	local fish = GameInfo.Resources["RESOURCE_FISH"];
	local landLux, seaLux, onMap = {}, {}, {};
	for i = 0, iW * iH - 1 do
		local r = Map.GetPlotByIndex(i):GetResourceType(-1);
		if r ~= -1 then onMap[r] = true end
	end
	-- user 11-15: city states never get a player's regional luxury
	local isRegional = {};
	if asp.region_luxury_assignment ~= nil then
		for r, id in pairs(asp.region_luxury_assignment) do isRegional[id] = true end
	end
	for row in GameInfo.Resources() do
		if row.ResourceClassType == "RESOURCECLASS_LUXURY" and onMap[row.ID] and not isRegional[row.ID] then
			local rules = kek_resourceRules[row.ID];
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
		return true;
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
		if csPlot ~= nil and not csPlot:IsWater() and true then
			log.cs = log.cs + 1;
			local food, lux, freeLand2, freeSea2, freeLand3, freeSea3 = 0, 0, {}, {}, {}, {};
			for loop, plot in ipairs(KekPlotsInRings(x, y, 1, 3)) do
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
			-- 3 food bonus within 2 (user 11-15: 4 was more than needed, back to 3)
			while food < 3 and tries < 10 do
				tries = tries + 1;
				local placed = false;
				if fish ~= nil and table.maxn(freeSea2) > 0 then
					local p = Take(freeSea2, function(p) return kek_resourceRules[fish.ID].terrain[p:GetTerrainType()] == true end);
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
			-- ...add a luxury only when there is none within 3 tiles (user 11-15: never give more than 1;
			-- a city state like Brussels with 5 food and 2 luxuries is the upper bound).
			-- Food within 2 tiles: at most 5, the farthest extras go.
			if food > 5 then
				local foodPlots = {};
				for loop, plot in ipairs(KekPlotsInRings(x, y, 1, 2)) do
					if Kind(plot:GetResourceType(-1)) == "bonus" then table.insert(foodPlots, plot) end
				end
				table.sort(foodPlots, function(a, b)
					return Map.PlotDistance(x, y, a:GetX(), a:GetY()) < Map.PlotDistance(x, y, b:GetX(), b:GetY())
				end);
				for n = 6, table.maxn(foodPlots) do foodPlots[n]:SetResourceType(-1, 0) end
				food = 5;
			end
			while lux < 1 and tries < 10 do
				tries = tries + 1;
				local placed = false;
				if table.maxn(landLux) > 0 and table.maxn(freeLand3) > 0 then
					local id = landLux[1 + Map.Rand(table.maxn(landLux), "City state boost - luxury")];
					local p = Take(freeLand3, function(p) return KekResourceFits(p, id, false) end);
					if p ~= nil then p:SetResourceType(id, 1); placed = true end
				end
				if not placed and table.maxn(seaLux) > 0 and table.maxn(freeSea3) > 0 then
					local id = seaLux[1 + Map.Rand(table.maxn(seaLux), "City state boost - sea luxury")];
					local p = Take(freeSea3, function(p) return kek_resourceRules[id].terrain[p:GetTerrainType()] == true end);
					if p ~= nil then p:SetResourceType(id, 1); placed = true end
				end
				if placed then lux = lux + 1; log.lux = log.lux + 1 end
			end
		end
	end
	print("City state boost: city states", log.cs, "food bonus +", log.food, "luxuries +", log.lux);
end
------------------------------------------------------------------------------
KEK_REGION_LUX_HOME = 2;		-- copies of its regional luxury on the start island, within 3 tiles (user)
KEK_REGION_LUX_AROUND = 3;		-- copies on the islands around it, 4-8 tiles away, nearer to it than to anyone else
function KekRegionLuxuryAtCapitals(asp, nRegions)
	-- Every capital's regional luxury, spread out (user): exactly HOME copies on
	-- its own start island within 3 tiles, and AROUND copies on other islands
	-- nearby (4-8 tiles, closer to this capital than to any other, never on
	-- another start island). If too few tiles fit, a tile gets the feature, the
	-- terrain or the hill the luxury needs.
	KekLoadResourceRules();
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
		local rules = lux and kek_resourceRules[lux];
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
				return KekResourceFits(plot, lux, false)
			end
			local function MakeFit(plot)
				-- a land tile that would fit with the right feature: give it that feature
				if plot:IsWater() or plot:GetFeatureType() ~= FeatureTypes.NO_FEATURE then return false end
				if plot:IsHills() and not rules.hills then return false end
				if plot:IsFlatlands() and not rules.flat then return false end
				for f, ok in pairs(rules.feature) do
					if ok and rules.featureTerrain[plot:GetTerrainType()] == true then
						plot:SetFeatureType(f, -1);
						if KekResourceFits(plot, lux, false) then return true end
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
				if KekResourceFits(plot, lux, false) then return true end
				for t, ok in pairs(rules.terrain) do
					if ok and t ~= TerrainTypes.TERRAIN_SNOW and t ~= TerrainTypes.TERRAIN_COAST and t ~= TerrainTypes.TERRAIN_OCEAN then
						plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
						plot:SetTerrainType(t, false, true);
						if KekResourceFits(plot, lux, false) then return true end
					end
				end
				for f, ok in pairs(rules.feature) do
					if ok then
						for t, ok2 in pairs(rules.featureTerrain) do
							if ok2 and t ~= TerrainTypes.TERRAIN_SNOW then
								plot:SetTerrainType(t, false, true);
								plot:SetFeatureType(f, -1);
								if KekResourceFits(plot, lux, false) then return true end
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
			for loop, plot in ipairs(KekPlotsInRings(x, y, 1, 3)) do
				local i = plot:GetY() * iW + plot:GetX();
				if true and (plot:IsWater() or plot:GetArea() == homeArea) then
					local res = plot:GetResourceType(-1);
					if res == lux then
						table.insert(have, plot);
					elseif res == -1 and plot:GetImprovementType() == -1 and not plot:IsMountain() and not plot:IsLake() then
						table.insert(free, plot);
					end
				end
			end
			local nHome = Fill(have, free, KEK_REGION_LUX_HOME, "home");
			-- 2. around: other islands (and their coast) 4-8 tiles away, nearer to this capital
			have, free = {}, {};
			for loop, plot in ipairs(KekPlotsInRings(x, y, 4, 8)) do
				local i = plot:GetY() * iW + plot:GetX();
				if true and Mine(plot) and not plot:IsLake() then
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
			Fill(have, free, KEK_REGION_LUX_AROUND + math.max(0, KEK_REGION_LUX_HOME - nHome), "around");
		end
	end
	print("Region luxury at capitals: added", log.added, "removed", log.removed, "short", log.short);
end
------------------------------------------------------------------------------
function KekCapitalBonusCap(asp, nRegions)
	-- Good, not crazy (user, 11-14): within 3 tiles of every capital exactly
	-- 3-5 bonus resources, Fish and land bonus together (one number per game,
	-- the same for everybody). Strategic balance and luxuries are not counted.
	-- Too many: the more common kind (sea or land) loses one first. Too few:
	-- a land bonus or a Fish is added.
	KekLoadResourceRules();
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
	-- user 11-15 later: no guaranteed Fish. Each capital rolls its own split of 6 food resources:
	-- 0-3 Fish, the rest land food (an inland capital is stronger on land to make up for it).
	-- Capital strength option 1-10 (user 11-15; 8 = the 11-15 tuning: 6 food resources)
	local capLevel = KekOpt("capstrength", 5);
	want = math.max(2, math.floor(capLevel * 0.75 + 0.5));
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
			fishWant = Map.Rand(math.min(3, want) + 1, "Capital bonus cap - fish per capital");
			-- user 11-15: a capital with little land around it (under 10 of the 18 tiles within 2 are land)
			-- gets at least 2 Fish
			do
				local landNear = 0;
				for loop, p in ipairs(KekPlotsInRings(x, y, 1, 2)) do if not p:IsWater() then landNear = landNear + 1 end end
				if landNear < 10 then fishWant = math.max(fishWant, math.min(2, want)) end
				-- user 11-15: the more water within 2 tiles, the more Fish (1 per 4 water tiles over 6)
				local waterNear = 18 - landNear;
				fishWant = math.min(want, math.max(fishWant, math.floor((waterNear - 6) / 4)));
			end
			landWant = want - fishWant;
			local sea, land, freeSea, freeLand = {}, {}, {}, {};
			for loop, plot in ipairs(KekPlotsInRings(x, y, 1, 3)) do
				local i = plot:GetY() * iW + plot:GetX();
				if true then
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
					if kek_resourceRules[fish.ID].terrain[plot:GetTerrainType()] == true then
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
function KekMoreOil(asp, nRegions, factor)
	-- More Oil on the archipelago (user, 11-14: "barely see any oil ... increase it by 150%";
	-- "rule of thumb: one oil nearby on the island, and one in the ocean somewhere"):
	-- 1. every capital: one Oil on its own island (4-7 tiles out) and one at sea within 8 tiles;
	-- 2. then more Oil, half land half sea, until there is factor x what the game placed.
	-- Never within 3 tiles of a capital, never within 2 of other Oil.
	KekLoadResourceRules();
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
		return not plot:IsWater() and KekResourceFits(plot, oil, false);
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
			-- the start island's own tiles (an area id can also cover land next to it)
			local own = {};
			local iid = kek_startIslands and kek_startIslands[r];
			if iid ~= nil and kek_islands[iid] ~= nil then for loop, t in ipairs(kek_islands[iid].plots) do own[t] = true end end
			local function OnHome(plot)
				if next(own) == nil then return plot:GetArea() == area end
				return own[plot:GetY() * iW + plot:GetX()] == true;
			end
			local haveLand, haveSea, landSpots, seaSpots, closeSpots, anySpots = false, false, {}, {}, {}, {};
			for loop, plot in ipairs(KekPlotsInRings(data[1], data[2], 1, 12)) do
				local d = Map.PlotDistance(data[1], data[2], plot:GetX(), plot:GetY());
				if plot:GetResourceType(-1) == oil then
					if plot:IsWater() then haveSea = haveSea or d <= 8 elseif OnHome(plot) and d <= 8 then haveLand = true end
				elseif d <= 8 and SeaFits(plot) then table.insert(seaSpots, plot)
				elseif d >= 2 and d <= 8 and OnHome(plot) and not plot:IsWater() and not plot:IsMountain() then
					-- small islands: 2-3 tiles out if nothing farther, and any land if Oil fits nowhere
					if LandFits(plot) then
						if d >= 4 then table.insert(landSpots, plot) else table.insert(closeSpots, plot) end
					else
						table.insert(anySpots, plot);
					end
				end
			end
			if not haveLand then
				local placed = Place(landSpots, false) or Place(closeSpots, false, true) or Place(anySpots, false, true);
				if not placed then
					-- a small, full start island (user 11-15): a bonus resource 2+ tiles out makes room for the Oil
					local bonus = {};
					for loop, plot in ipairs(KekPlotsInRings(data[1], data[2], 1, 8)) do
						local res = plot:GetResourceType(-1);
						if not plot:IsWater() and not plot:IsMountain() and OnHome(plot) and plot:GetImprovementType() == -1
							and (res == -1 or (GameInfo.Resources[res] ~= nil and GameInfo.Resources[res].ResourceUsage == 0)) then table.insert(bonus, plot) end
					end
					if table.maxn(bonus) > 0 then
						local plot = bonus[1 + Map.Rand(table.maxn(bonus), "More oil - make room")];
						plot:SetResourceType(-1, 0);
						plot:SetResourceType(oil, Amount(landAmt, 6));
						added = added + 1;
					end
				end
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
function KekCapitalExtraCap(asp, nRegions, maxExtra)
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
			for loop, plot in ipairs(KekPlotsInRings(x, y, 1, 3)) do
				local res = plot:GetResourceType(-1);
				local row = res ~= -1 and GameInfo.Resources[res] or nil;
				if row ~= nil then
					local d = Map.PlotDistance(x, y, plot:GetX(), plot:GetY());
					if row.ResourceUsage == 0 then
						table.insert(extra, {plot, d, 0});
					elseif res == asp.horse_ID or res == asp.iron_ID then
						-- the standard deposit is the biggest one (the strategic balance's), nearest on a tie
						-- (a deposit on a tile it does not fit counts as smaller: it may not be workable)
						local amt = plot:GetNumResource() * 2 + (KekResourceFits(plot, res, false) and 1 or 0);
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
function KekFishCityCap(asp, nRegions, maxFish)
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
		if not plot:IsWater() and not plot:IsMountain() and true then table.insert(land, plot) end
	end
	local removed = 0;
	-- random order, so no corner of the map is favoured
	for n = table.maxn(land), 2, -1 do
		local k = 1 + Map.Rand(n, "Fish city cap - order");
		land[n], land[k] = land[k], land[n];
	end
	for loop, site in ipairs(land) do
		local here, removable = 0, {};
		for loop2, plot in ipairs(KekPlotsInRings(site:GetX(), site:GetY(), 1, 3)) do
			local i = plot:GetY() * iW + plot:GetX();
			if plot:IsWater() and plot:GetResourceType(-1) == fish.ID and true then
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
function KekCapitalLuxuries(asp, nRegions)
	-- Capitals as the user wants them (11-14): within 3 tiles exactly 2 copies
	-- of the capital's regional luxury and exactly 1 other luxury (land or sea).
	-- Missing ones are added on fitting free tiles, extras go (farthest first).
	KekLoadResourceRules();
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
			for loop, plot in ipairs(KekPlotsInRings(x, y, 1, 3)) do
				local i = plot:GetY() * iW + plot:GetX();
				if true then
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
					if KekResourceFits(plot, resID, false) then
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
function KekIslandScaling(asp)
	-- Speed vs scaling (user, 11-14): small islands (8 tiles or less) one more
	-- Fish (quick food), bigger free islands (15+) one more land food per 10
	-- tiles (they also have a lake). Start islands are not touched.
	local iW, iH = Map.GetGridSize();
	local fish = GameInfo.Resources["RESOURCE_FISH"];
	local log = {fish = 0, land = 0};
	for id, island in ipairs(kek_islands) do
		local n = table.maxn(island.plots);
		if island.kind ~= "start" and island.kind ~= "own" then
			if n <= 8 and fish ~= nil then
				local spots, seen = {}, {};
				for loop, t in ipairs(island.plots) do
					for loop2, j in ipairs(KekNeighbours(t)) do
						local plot = Map.GetPlotByIndex(j);
						if not seen[j] and (function(i) return true end)(j) and plot:IsWater() and not plot:IsLake() and plot:GetResourceType(-1) == -1
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
					if (function(i) return true end)(t) and not plot:IsWater() and not plot:IsMountain() and plot:GetResourceType(-1) == -1 and plot:GetImprovementType() == -1 then
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

------------------------------------------------------------------------------
-- Islands worth settling (user, 11-15): thin islands are the Fish/coast ones,
-- the rounder "bulbs" get fresh water and a couple of land resources. Small
-- touches, to be dialled later.
------------------------------------------------------------------------------
function KekRiverSide(plot, d)
	-- A one-edge river on side d of plot (plot and its neighbour there both dry land, not
	-- mountains), and only where one end of that edge touches the sea: the river flows out to
	-- it, so the game draws a river mouth (a river that ends inland on both sides draws as an
	-- odd pool). Both tiles get fresh water. Returns true when made.
	local x, y = plot:GetX(), plot:GetY();
	local n = Map.PlotDirection(x, y, d);
	if n == nil or plot:IsWater() or n:IsWater() or plot:IsMountain() or n:IsMountain() then return false end
	local function Water(dir)
		local q = Map.PlotDirection(x, y, dir % 6);
		return q ~= nil and q:IsWater() and not q:IsLake();
	end
	local F = FlowDirectionTypes;
	local D = DirectionTypes;
	-- the two ends of side d touch the neighbours at d-1 and d+1; the flow goes towards the sea end
	-- (in the game's terms the flow names the direction it comes from - checked in game 11-15)
	local lo, hi = Water(d + 5), Water(d + 1);
	if not lo and not hi then return false end
	if d == D.DIRECTION_EAST then
		if plot:IsWOfRiver() then return false end
		plot:SetWOfRiver(true, hi and F.FLOWDIRECTION_NORTH or F.FLOWDIRECTION_SOUTH)
	elseif d == D.DIRECTION_SOUTHEAST then
		if plot:IsNWOfRiver() then return false end
		plot:SetNWOfRiver(true, hi and F.FLOWDIRECTION_NORTHEAST or F.FLOWDIRECTION_SOUTHWEST)
	elseif d == D.DIRECTION_SOUTHWEST then
		if plot:IsNEOfRiver() then return false end
		plot:SetNEOfRiver(true, hi and F.FLOWDIRECTION_SOUTHEAST or F.FLOWDIRECTION_NORTHWEST)
	elseif d == D.DIRECTION_WEST then
		if n:IsWOfRiver() then return false end
		n:SetWOfRiver(true, hi and F.FLOWDIRECTION_SOUTH or F.FLOWDIRECTION_NORTH)
	elseif d == D.DIRECTION_NORTHWEST then
		if n:IsNWOfRiver() then return false end
		n:SetNWOfRiver(true, hi and F.FLOWDIRECTION_SOUTHWEST or F.FLOWDIRECTION_NORTHEAST)
	else	-- NORTHEAST
		if n:IsNEOfRiver() then return false end
		n:SetNEOfRiver(true, hi and F.FLOWDIRECTION_NORTHWEST or F.FLOWDIRECTION_SOUTHEAST)
	end
	return true;
end
function KekRiverEdge(plot)
	-- In the game: the game's own river builder (DoRiver from MapGenerator.lua) starts a river at an
	-- inland corner of this tile and runs it down to the sea, so it looks like any other river
	-- (user 11-15: one-edge rivers drew as odd pools whatever their direction).
	if DoRiver ~= nil and plot.GetInlandCorner ~= nil and not plot:IsWater() and not plot:IsMountain() then
		if plot:IsRiver() then return false end
		local corner = plot:GetInlandCorner();
		if corner == nil then return false end
		DoRiver(corner);
		return plot:IsRiver() or plot:IsFreshWater();
	end
	-- (offline test harness without DoRiver: a coast-reaching one-edge river on any side of plot)
	local dirs = {0, 1, 2, 3, 4, 5};
	while table.maxn(dirs) > 0 do
		local d = table.remove(dirs, 1 + Map.Rand(table.maxn(dirs), "KEK river side"));
		if KekRiverSide(plot, d) then return true end
	end
	return false;
end
function KekIslandMountainsAndRivers()
	local iW, iH = Map.GetGridSize();
	local log = {mountains = 0, rivers = 0};
	for id, island in ipairs(kek_islands) do
		local n = table.maxn(island.plots);
		if island.kind ~= "start" and island.kind ~= "own" then
			local own, hasMountain = {}, false;
			for loop, t in ipairs(island.plots) do
				own[t] = true;
				if Map.GetPlotByIndex(t):IsMountain() then hasMountain = true end
			end
			-- 4-12 tiles: a single mountain 7 times in 10 (user 11-15: more; was 5-9 tiles, half the time)
			if n >= 4 and n <= 12 and not hasMountain and Map.Rand(10, "KEK islands - single mountain") < 7 then
				local best, bestN = {}, -1;
				for loop, t in ipairs(island.plots) do
					local c = 0;
					for loop2, j in ipairs(KekNeighbours(t)) do if own[j] then c = c + 1 end end
					if c > bestN then best, bestN = {t}, c elseif c == bestN then table.insert(best, t) end
				end
				local t = best[1 + Map.Rand(table.maxn(best), "KEK islands - mountain spot")];
				Map.GetPlotByIndex(t):SetPlotType(PlotTypes.PLOT_MOUNTAIN, false, false);
				log.mountains = log.mountains + 1;
			end
			-- rounder islands from 8 tiles: a short river 40% (60% from 12 tiles)
			if island.shape ~= "stringy" and n >= 8 then
				local chance = 40;
				if n >= 12 then chance = 60 end
				if Map.Rand(100, "KEK islands - river") < chance then
					local spots = {};
					for loop, t in ipairs(island.plots) do
						local x, y = t % iW, math.floor(t / iW);
						if own[((x + 1) % iW) + y * iW] then table.insert(spots, t) end
					end
					while table.maxn(spots) > 0 do
						local t = table.remove(spots, 1 + Map.Rand(table.maxn(spots), "KEK islands - river spot"));
						if KekRiverEdge(Map.GetPlotByIndex(t)) then log.rivers = log.rivers + 1; break end
					end
				end
			end
		end
	end
	print("KEK islands: single mountains", log.mountains, "short rivers", log.rivers);
end
function KekCapitalRivers(asp, nRegions)
	-- Half the games every capital gets fresh water from a one-tile river next to
	-- it (gardens), when the land east or west of it allows; the same roll for all.
	-- user 11-15: not every spawn needs fresh water - each capital rolls (1 in 2); a capital whose
	-- regional luxury is mined (Gold, Silver, Gems, Salt, Copper) is a hill/mine start and never gets one.
	local mined = {};
	for loop, t in ipairs({"RESOURCE_GOLD", "RESOURCE_SILVER", "RESOURCE_GEMS", "RESOURCE_SALT", "RESOURCE_COPPER"}) do
		if GameInfo.Resources[t] ~= nil then mined[GameInfo.Resources[t].ID] = true end
	end
	local iW, iH = Map.GetGridSize();
	local made = 0;
	for r = 1, nRegions do
		local data = asp.startingPlots[r];
		if data ~= nil then
			local x, y = data[1], data[2];
			local cap = Map.GetPlot(x, y);
			local regional = asp.region_luxury_assignment and asp.region_luxury_assignment[r];
			if cap ~= nil and cap:IsFreshWater() then
				made = made + 1;	-- already has fresh water
			elseif cap ~= nil and not mined[regional] and Map.Rand(2, "KEK capitals - river roll") == 0 then
				-- a river mouth next to the capital (any side that reaches the sea)
				if KekRiverEdge(cap) then made = made + 1 end
			end
		end
	end
	print("KEK capitals: river at", made, "capitals");
end
function KekNearAnyCapital(asp, nRegions, x, y, d)
	for r = 1, nRegions do
		local data = asp.startingPlots[r];
		if data ~= nil and Map.PlotDistance(x, y, data[1], data[2]) <= d then return true end
	end
	return false;
end
function KekBulbLandResources(asp, nRegions)
	-- Rounder free islands: at least 1 land resource from 8 tiles, 2 from 15.
	local added = 0;
	for id, island in ipairs(kek_islands) do
		local n = table.maxn(island.plots);
		if island.kind ~= "start" and island.kind ~= "own" and island.shape ~= "stringy" and n >= 8 then
			local want = 1;
			if n >= 15 then want = 2 end
			local have, free = 0, {};
			for loop, t in ipairs(island.plots) do
				local plot = Map.GetPlotByIndex(t);
				if not plot:IsWater() then
					if plot:GetResourceType(-1) ~= -1 then have = have + 1
					elseif plot:GetImprovementType() == -1 and not plot:IsMountain()
						and not KekNearAnyCapital(asp, nRegions, plot:GetX(), plot:GetY(), 3) then table.insert(free, plot) end
				end
			end
			while have < want and table.maxn(free) > 0 do
				local plot = table.remove(free, 1 + Map.Rand(table.maxn(free), "KEK islands - bulb resource"));
				if asp:AttemptToPlaceBonusResourceAtPlot(plot:GetX(), plot:GetY(), false) then have = have + 1; added = added + 1 end
			end
		end
	end
	print("KEK islands: bulb land resources added", added);
end
function KekCoastLuxFish(asp, nRegions)
	-- Every Whales/Pearls/Crab (not near a capital: capitals have their own rules)
	-- gets at least one Fish within 2 tiles; KekFishCityCap still caps a site.
	KekLoadResourceRules();
	local fish = GameInfo.Resources["RESOURCE_FISH"];
	if fish == nil then return end
	local lux = {};
	for loop, t in ipairs({"RESOURCE_WHALE", "RESOURCE_PEARLS", "RESOURCE_CRAB"}) do
		if GameInfo.Resources[t] ~= nil then lux[GameInfo.Resources[t].ID] = true end
	end
	local iW, iH = Map.GetGridSize();
	local added = 0;
	for i = 0, iW * iH - 1 do
		local plot = Map.GetPlotByIndex(i);
		if plot:IsWater() and lux[plot:GetResourceType(-1)] then
			local x, y = plot:GetX(), plot:GetY();
			if not KekNearAnyCapital(asp, nRegions, x, y, 3) then
				local has, free = false, {};
				for loop, p in ipairs(KekPlotsInRings(x, y, 1, 2)) do
					if p:GetResourceType(-1) == fish.ID then has = true
					elseif p:IsWater() and not p:IsLake() and p:GetResourceType(-1) == -1 and p:GetFeatureType() == FeatureTypes.NO_FEATURE
						and kek_resourceRules[fish.ID].terrain[p:GetTerrainType()] == true then table.insert(free, p) end
				end
				if not has and table.maxn(free) > 0 then
					local p = free[1 + Map.Rand(table.maxn(free), "KEK coast lux - fish")];
					p:SetResourceType(fish.ID, 1);
					added = added + 1;
				end
			end
		end
	end
	print("KEK coast luxuries: Fish added", added);
end

------------------------------------------------------------------------------
function KekSiteSmoothing(asp, nRegions)
	-- Even city sites (user, 11-15): away from capitals and city states (they have
	-- their own rules) no land tile has more than SITE_CAP bonus resources (food,
	-- Fish, Stone) within 2 tiles; a site with fresh water (farms) SITE_CAP_FRESH.
	-- Luxuries and strategics are never removed. Then every free island of 5+
	-- tiles gets at least one site with 2 bonus resources within 2 tiles.
	local SITE_CAP, SITE_CAP_FRESH = 4, 3;
	local iW, iH = Map.GetGridSize();
	local function IsBonus(res)
		return res ~= -1 and GameInfo.Resources[res] ~= nil and GameInfo.Resources[res].ResourceUsage == 0;
	end
	local protected = {};
	local function Protect(x, y)
		for loop, p in ipairs(KekPlotsInRings(x, y, 0, 3)) do protected[p:GetY() * iW + p:GetX()] = true end
	end
	for r = 1, nRegions do
		local data = asp.startingPlots[r];
		if data ~= nil then Protect(data[1], data[2]) end
	end
	if asp.cityStatePlots ~= nil then
		for n, data in pairs(asp.cityStatePlots) do Protect(data[1], data[2]) end
	end
	-- sites: land, not mountain, not protected; count bonus within 2
	local sites, count, cap = {}, {}, {};
	for i = 0, iW * iH - 1 do
		local plot = Map.GetPlotByIndex(i);
		if not plot:IsWater() and not plot:IsMountain() and not protected[i] then
			local c = 0;
			for loop, p in ipairs(KekPlotsInRings(plot:GetX(), plot:GetY(), 0, 2)) do
				if IsBonus(p:GetResourceType(-1)) then c = c + 1 end
			end
			table.insert(sites, i);
			count[i] = c;
			if plot:IsFreshWater() then cap[i] = SITE_CAP_FRESH else cap[i] = SITE_CAP end
			-- far from every capital: a bit richer; desert sites (Petra) richer still
			if KekCapitalDistance(asp, nRegions, plot:GetX(), plot:GetY()) >= KEK_FAR then cap[i] = cap[i] + 1 end
			if KekDesertAround(plot) >= 3 then cap[i] = cap[i] + 2 end
		end
	end
	local removed, added = 0, 0;
	for round = 1, 2000 do
		local worst, worstEx = -1, 0;
		for loop, i in ipairs(sites) do
			local ex = count[i] - cap[i];
			if ex > worstEx then worst, worstEx = i, ex end
		end
		if worst < 0 then break end
		local wp = Map.GetPlotByIndex(worst);
		-- remove the removable bonus near it that sits in the most over-cap sites
		local best, bestScore = nil, -1;
		for loop, p in ipairs(KekPlotsInRings(wp:GetX(), wp:GetY(), 0, 2)) do
			local j = p:GetY() * iW + p:GetX();
			if IsBonus(p:GetResourceType(-1)) and not protected[j] then
				local score = 0;
				for loop2, q in ipairs(KekPlotsInRings(p:GetX(), p:GetY(), 0, 2)) do
					local k = q:GetY() * iW + q:GetX();
					if count[k] ~= nil and count[k] > cap[k] then score = score + 1 end
				end
				if score > bestScore or (score == bestScore and Map.Rand(2, "KEK sites - tie") == 0) then best, bestScore = p, score end
			end
		end
		if best == nil then
			cap[worst] = count[worst];	-- nothing removable here (protected): leave it
		else
			best:SetResourceType(-1, 0);
			removed = removed + 1;
			for loop, q in ipairs(KekPlotsInRings(best:GetX(), best:GetY(), 0, 2)) do
				local k = q:GetY() * iW + q:GetX();
				if count[k] ~= nil then count[k] = count[k] - 1 end
			end
		end
	end
	-- floor: every free island of 5+ tiles has a site with at least 2
	local fish = GameInfo.Resources["RESOURCE_FISH"];
	KekLoadResourceRules();
	for id, island in ipairs(kek_islands) do
		if island.kind ~= "start" and island.kind ~= "own" and table.maxn(island.plots) >= 5 then
			local bestSite, bestC = nil, -1;
			for loop, t in ipairs(island.plots) do
				if count[t] ~= nil and count[t] > bestC then bestSite, bestC = t, count[t] end
			end
			if bestSite ~= nil and bestC < 2 then
				local sp = Map.GetPlotByIndex(bestSite);
				local land, sea = {}, {};
				for loop, p in ipairs(KekPlotsInRings(sp:GetX(), sp:GetY(), 1, 2)) do
					local j = p:GetY() * iW + p:GetX();
					if p:GetResourceType(-1) == -1 and p:GetImprovementType() == -1 and not protected[j] then
						if p:IsWater() then
							if fish ~= nil and not p:IsLake() and p:GetFeatureType() == FeatureTypes.NO_FEATURE
								and kek_resourceRules[fish.ID].terrain[p:GetTerrainType()] == true then table.insert(sea, p) end
						elseif not p:IsMountain() then table.insert(land, p) end
					end
				end
				local need = 2 - bestC;
				while need > 0 and table.maxn(land) > 0 do
					local p = table.remove(land, 1 + Map.Rand(table.maxn(land), "KEK sites - floor land"));
					if asp:AttemptToPlaceBonusResourceAtPlot(p:GetX(), p:GetY(), false) then need = need - 1; added = added + 1 end
				end
				while need > 0 and table.maxn(sea) > 0 do
					local p = table.remove(sea, 1 + Map.Rand(table.maxn(sea), "KEK sites - floor fish"));
					p:SetResourceType(fish.ID, 1); need = need - 1; added = added + 1;
				end
			end
		end
	end
	print("KEK sites: removed", removed, "added", added);
end

------------------------------------------------------------------------------
-- Start island kinds (user, 11-15): not a blob every time. One roll per player.
--   blob      the old round/irregular island
--   isthmus   two lobes joined by a 2-tile wide neck
--   peninsula a main lobe with a long arm, 2-3 islets close by (more Fish: thin)
--   fortress  round, with a hilly shore
------------------------------------------------------------------------------
function KekPickStartKind()
	local roll = Map.Rand(100, "KEK start kind");
	-- user 11-15: "islet" = a small capital island with bigger land just across the water (1 in 7)
	if roll < 20 then return "blob" elseif roll < 37 then return "isthmus" elseif roll < 54 then return "peninsula"
	elseif roll < 70 then return "cluster" elseif roll < 85 then return "islet" end
	return "fortress";
end
local function KekCanGrow(j, id, isLand, yMin, yMax)
	local iW, iH = Map.GetGridSize();
	if isLand[j] or not KekIslandAllowed(j) then return false end
	if yMin ~= nil then
		local y = math.floor(j / iW);
		if y < yMin or y > yMax then return false end
	end
	for loop, nb in ipairs(KekNeighbours(j)) do
		if isLand[nb] and kek_islandOf[nb] ~= id then return false end
	end
	return true;
end
local function KekStep(j, d)
	local iW, iH = Map.GetGridSize();
	local p = Map.PlotDirection(j % iW, math.floor(j / iW), d);
	if p == nil then return nil end
	return p:GetY() * iW + p:GetX();
end
function KekGrowStartIsland(id, seed, size, isLand, yLo, yHi, kind)
	if kind == "islet" then
		-- the capital's own island: 8-12 tiles; the rest of the land comes as islands in front (below)
		return KekGrowIsland(id, seed, math.min(size, 8 + Map.Rand(5, "KEK start - islet size")), isLand, yLo, yHi, "round");
	end
	if kind == "blob" or kind == "fortress" or kind == "cluster" then
		local shape = "round";
		if kind == "blob" and Map.Rand(2, "KEK start blob shape") == 0 then shape = "uniform" end
		return KekGrowIsland(id, seed, size, isLand, yLo, yHi, shape);
	end
	local iW, iH = Map.GetGridSize();
	local mainSize = math.floor(size * 0.55 + 0.5);
	if kind == "peninsula" then mainSize = math.floor(size * 0.7 + 0.5) end
	local tiles = KekGrowIsland(id, seed, mainSize, isLand, yLo, yHi, "round");
	if tiles == nil then return nil end
	local inA = {};
	for loop, t in ipairs(tiles) do inA[t] = true end
	local function Add(j) table.insert(tiles, j); isLand[j] = true; kek_islandOf[j] = id end
	-- walk from the seed in direction d to the shore
	local d = Map.Rand(6, "KEK start - neck direction");
	local e = seed;
	for n = 1, 30 do
		local nx = KekStep(e, d);
		if nx == nil or not inA[nx] then break end
		e = nx;
	end
	local function GrowTo(want, tag, farFromA)
		-- grow 'want' tiles round-ish from the neck end; farFromA keeps 3 tiles off lobe A
		local grown = 0;
		local last = tiles[table.maxn(tiles)];
		local mine = {[last] = true};
		while grown < want do
			local cands, best = {}, -1;
			for t, flag in pairs(mine) do
				for loop, nb in ipairs(KekNeighbours(t)) do
					if not mine[nb] and KekCanGrow(nb, id, isLand, yLo, yHi) then
						local ok = true;
						if farFromA then
							for a, flag2 in pairs(inA) do
								if Map.PlotDistance(nb % iW, math.floor(nb / iW), a % iW, math.floor(a / iW)) < 3 then ok = false; break end
							end
						end
						if ok then
							local c = 0;
							for loop2, nb2 in ipairs(KekNeighbours(nb)) do if mine[nb2] then c = c + 1 end end
							if c > best then cands, best = {nb}, c elseif c == best then table.insert(cands, nb) end
						end
					end
				end
			end
			if table.maxn(cands) == 0 then break end
			local j = cands[1 + Map.Rand(table.maxn(cands), tag)];
			mine[j] = true;
			Add(j);
			grown = grown + 1;
		end
		return grown;
	end
	-- the neck (isthmus: 2 wide, 2 long) or the arm (peninsula: 1-2 wide, 4-6 long)
	local length, wide = 2, true;
	if kind == "peninsula" then length = 4 + Map.Rand(3, "KEK start - arm length"); wide = (Map.Rand(2, "KEK start - arm width") == 0) end
	local cur = e;
	for n = 1, length do
		local nx = KekStep(cur, d);
		if table.maxn(tiles) >= size or nx == nil or not KekCanGrow(nx, id, isLand, yLo, yHi) then break end
		Add(nx);
		if wide and table.maxn(tiles) < size then
			local side = KekStep(nx, (d + 1) % 6);
			if side ~= nil and KekCanGrow(side, id, isLand, yLo, yHi) then Add(side) end
		end
		cur = nx;
	end
	-- the rest of the tiles: the second lobe (isthmus) or the tip of the arm
	local rest = size - table.maxn(tiles);
	if rest > 0 then
		local got = GrowTo(rest, "KEK start - second lobe", kind == "isthmus");
		if got < rest then
			-- no room out there: the main lobe takes the rest
			local more = KekGrowIsland(id, seed, 1, isLand, yLo, yHi, "round");
			if more ~= nil then for loop, j in ipairs(more) do table.insert(tiles, j) end end
			local missing = size - table.maxn(tiles);
			for n = 1, missing do
				local cands = {};
				for loop, t in ipairs(tiles) do
					if inA[t] then
						for loop2, nb in ipairs(KekNeighbours(t)) do
							if KekCanGrow(nb, id, isLand, yLo, yHi) then table.insert(cands, nb) end
						end
					end
				end
				if table.maxn(cands) == 0 then break end
				local j = cands[1 + Map.Rand(table.maxn(cands), "KEK start - fill main lobe")];
				Add(j); inA[j] = true;
			end
		end
	end
	return tiles;
end
function KekStartIslets(startTiles, isLand, yLo, yHi, want, minSize, maxSize)
	-- 2-3 islets of 2-4 tiles, 2 tiles off a peninsula start island
	local iW, iH = Map.GetGridSize();
	local own = {};
	for loop, t in ipairs(startTiles) do own[t] = true end
	local ring = {};
	for loop, t in ipairs(startTiles) do
		for loop2, nb in ipairs(KekNeighbours(t)) do
			if not own[nb] then
				for loop3, nb2 in ipairs(KekNeighbours(nb)) do
					if not own[nb2] and not isLand[nb2] then table.insert(ring, nb2) end
				end
			end
		end
	end
	local made = {};
	want = want or (2 + Map.Rand(2, "KEK start - islets"));
	minSize, maxSize = minSize or 2, maxSize or 4;
	local tries = 0;
	while table.maxn(made) < want and table.maxn(ring) > 0 and tries < 30 do
		tries = tries + 1;
		local seed = table.remove(ring, 1 + Map.Rand(table.maxn(ring), "KEK start - islet spot"));
		local id = table.maxn(kek_islands) + 1;
		local tiles = KekGrowIsland(id, seed, minSize + Map.Rand(maxSize - minSize + 1, "KEK start - islet size"), isLand, yLo, yHi, "round");
		if tiles ~= nil then
			kek_islands[id] = {kind = "small", plots = tiles, shape = "round"};
			table.insert(made, tiles);
		end
	end
	return made;
end
------------------------------------------------------------------------------
-- Far lands (user, 11-15): going far to settle should pay. Land far from every
-- capital gets a few more bonus resources, cold coasts more Fish, flat desert
-- about every second tile a bonus (Petra cities).
------------------------------------------------------------------------------
KEK_FAR = 9;
function KekCapitalDistance(asp, nRegions, x, y)
	local best = 999;
	for r = 1, nRegions do
		local data = asp.startingPlots[r];
		if data ~= nil then best = math.min(best, Map.PlotDistance(x, y, data[1], data[2])) end
	end
	return best;
end
local function KekIsFlatDesert(plot)
	if plot:IsWater() or plot:IsHills() or plot:IsMountain() then return false end
	if plot:GetTerrainType() ~= TerrainTypes.TERRAIN_DESERT then return false end
	local fp = GameInfo.Features["FEATURE_FLOOD_PLAINS"];
	return fp == nil or plot:GetFeatureType() ~= fp.ID;
end
function KekDesertAround(plot)
	local c = 0;
	for loop, p in ipairs(KekPlotsInRings(plot:GetX(), plot:GetY(), 0, 1)) do
		if KekIsFlatDesert(p) then c = c + 1 end
	end
	return c;
end
function KekFarLands(asp, nRegions)
	KekLoadResourceRules();
	local iW, iH = Map.GetGridSize();
	local fish = GameInfo.Resources["RESOURCE_FISH"];
	local stone = GameInfo.Resources["RESOURCE_STONE"];
	local log = {far = 0, cold = 0, desert = 0};
	for i = 0, iW * iH - 1 do
		local plot = Map.GetPlotByIndex(i);
		local x, y = plot:GetX(), plot:GetY();
		local d = KekCapitalDistance(asp, nRegions, x, y);
		if d > 3 and plot:GetResourceType(-1) == -1 and plot:GetImprovementType() == -1 then
			if plot:IsWater() then
				-- cold coasts: Fish next to tundra / snow land (1 in 4)
				if fish ~= nil and not plot:IsLake() and plot:GetFeatureType() == FeatureTypes.NO_FEATURE
					and kek_resourceRules[fish.ID].terrain[plot:GetTerrainType()] == true then
					local cold = false;
					for loop, nb in ipairs(KekNeighbours(i)) do
						local q = Map.GetPlotByIndex(nb);
						local t = q:GetTerrainType();
						if not q:IsWater() and (t == TerrainTypes.TERRAIN_TUNDRA or t == TerrainTypes.TERRAIN_SNOW) then cold = true end
					end
					if cold and Map.Rand(4, "KEK far - cold fish") == 0 then
						plot:SetResourceType(fish.ID, 1); log.cold = log.cold + 1;
					end
				end
			elseif not plot:IsMountain() then
				if KekIsFlatDesert(plot) then
					-- flat desert: about every second tile a bonus (Stone when nothing else fits)
					if Map.Rand(100, "KEK far - desert") < 45 then
						if asp:AttemptToPlaceBonusResourceAtPlot(x, y, false) then log.desert = log.desert + 1
						elseif stone ~= nil and kek_resourceRules[stone.ID] ~= nil and kek_resourceRules[stone.ID].terrain[plot:GetTerrainType()] == true then
							plot:SetResourceType(stone.ID, 1); log.desert = log.desert + 1;
						end
					end
				elseif d >= KEK_FAR and Map.Rand(100, "KEK far - land") < 10 then
					if asp:AttemptToPlaceBonusResourceAtPlot(x, y, false) then log.far = log.far + 1 end
				end
			end
		end
	end
	print("KEK far lands: far bonus", log.far, "cold Fish", log.cold, "desert bonus", log.desert);
end

------------------------------------------------------------------------------
function KekCapitalSeaLux(asp, nRegions)
	kek_seaRegionals = {};
	-- Coastal luxuries at capitals (user 11-15): about a third of the players have one within 3
	-- tiles (2 of 6, 1-2 of 4); the rest don't. The capital's "other" luxury (the one that is not
	-- its regional) is swapped between a sea and a land luxury, so the count stays the same.
	KekLoadResourceRules();
	local sea, land = {}, {};
	local onMap = {};
	local iW, iH = Map.GetGridSize();
	for i = 0, iW * iH - 1 do
		local r = Map.GetPlotByIndex(i):GetResourceType(-1);
		if r ~= -1 then onMap[r] = true end
	end
	for loop, t in ipairs({"RESOURCE_WHALE", "RESOURCE_PEARLS", "RESOURCE_CRAB"}) do
		if GameInfo.Resources[t] ~= nil then sea[GameInfo.Resources[t].ID] = true end
	end
	local landList = {};
	for row in GameInfo.Resources() do
		if row.ResourceUsage == 2 and not sea[row.ID] and onMap[row.ID] and row.Type ~= "RESOURCE_JEWELRY" and row.Type ~= "RESOURCE_PORCELAIN" then
			table.insert(landList, row.ID); land[row.ID] = true;
		end
	end
	local seaList = {};
	for id, ok in pairs(sea) do table.insert(seaList, id) end
	table.sort(seaList);
	local caps = {};
	for r = 1, nRegions do if asp.startingPlots[r] ~= nil then table.insert(caps, r) end end
	local n = table.maxn(caps);
	if n == 0 then return end
	local want = math.floor(n / 3 + 0.5);
	if n <= 4 then want = 1 + Map.Rand(2, "KEK capital sea lux - tiny") end
	want = math.max(1, math.min(n, want));
	local chosen = {};
	local order = {};
	for loop, r in ipairs(caps) do table.insert(order, r) end
	-- islet starts first (user 11-15: a small capital island needs its luxuries at sea)
	local isletFirst = {};
	for n2 = table.maxn(order), 1, -1 do
		local iid = kek_startIslands and kek_startIslands[order[n2]];
		if iid ~= nil and kek_islands[iid] ~= nil and kek_islands[iid].startKind == "islet" then
			table.insert(isletFirst, table.remove(order, n2));
		end
	end
	for m = 1, want do
		local pick;
		if table.maxn(isletFirst) > 0 then pick = table.remove(isletFirst, 1)
		elseif table.maxn(order) > 0 then pick = table.remove(order, 1 + Map.Rand(table.maxn(order), "KEK capital sea lux - who")) end
		if pick ~= nil then chosen[pick] = true end
	end
	for loop, r in ipairs(isletFirst) do chosen[r] = true end	-- every islet start gets one
	local log = {toSea = 0, toLand = 0};
	local seaPick = Map.Rand(3, "KEK coastal regional - first kind");
	for loop, r in ipairs(caps) do
		local x, y = asp.startingPlots[r][1], asp.startingPlots[r][2];
		local regional = asp.region_luxury_assignment and asp.region_luxury_assignment[r];
		local seaHere, otherLand, freeSea, freeLand = {}, {}, {}, {};
		for loop2, p in ipairs(KekPlotsInRings(x, y, 1, 3)) do
			local res = p:GetResourceType(-1);
			if sea[res] then table.insert(seaHere, p)
			elseif land[res] and res ~= regional then table.insert(otherLand, p)
			elseif res == -1 and p:GetImprovementType() == -1 and not p:IsMountain() then
				if p:IsWater() then
					if not p:IsLake() and p:GetFeatureType() == FeatureTypes.NO_FEATURE then table.insert(freeSea, p) end
				else table.insert(freeLand, p) end
			end
		end
		if chosen[r] and table.maxn(seaList) > 0 and regional ~= nil and not sea[regional] then
			-- user 11-15: a coastal REGIONAL - this player's regional luxury becomes a sea luxury: every
			-- copy of it within 8 tiles (2 at home, the ones on the islands around) moves to the coast next to it.
			seaPick = (seaPick or 0) + 1;
			local id = seaList[1 + (seaPick - 1) % table.maxn(seaList)];
			for loop2, p in ipairs(KekPlotsInRings(x, y, 1, 8)) do
				if p:GetResourceType(-1) == regional then
					local spots = {};
					for loop3, q in ipairs(KekPlotsInRings(p:GetX(), p:GetY(), 1, 2)) do
						if q:IsWater() and not q:IsLake() and q:GetResourceType(-1) == -1 and q:GetFeatureType() == FeatureTypes.NO_FEATURE
							and kek_resourceRules[id] ~= nil and kek_resourceRules[id].terrain[q:GetTerrainType()] == true
							and (Map.PlotDistance(x, y, p:GetX(), p:GetY()) > 3 or Map.PlotDistance(x, y, q:GetX(), q:GetY()) <= 3) then
							table.insert(spots, q)
						end
					end
					if table.maxn(spots) > 0 then
						local q = spots[1 + Map.Rand(table.maxn(spots), "KEK coastal regional - spot")];
						q:SetResourceType(id, p:GetNumResource());
						p:SetResourceType(-1, 0);
						log.toSea = log.toSea + 1;
					end
				end
			end
			if asp.region_luxury_assignment ~= nil then asp.region_luxury_assignment[r] = id end
			kek_seaRegionals = kek_seaRegionals or {};
			kek_seaRegionals[id] = {x, y};
		elseif not chosen[r] and table.maxn(seaHere) > 0 then
			-- no sea luxury here: it becomes a land luxury that fits
			for loop2, p in ipairs(seaHere) do p:SetResourceType(-1, 0) end
			for tries = 1, 20 do
				if table.maxn(freeLand) == 0 or table.maxn(landList) == 0 then break end
				local p = freeLand[1 + Map.Rand(table.maxn(freeLand), "KEK capital land lux - spot")];
				local id = landList[1 + Map.Rand(table.maxn(landList), "KEK capital land lux - kind")];
				if id ~= regional and KekResourceFits(p, id, false) then
					p:SetResourceType(id, 1); log.toLand = log.toLand + 1; break;
				end
			end
		end
	end
	print("KEK coastal regionals: players", want, "of", n, "copies moved to the coast", log.toSea, "sea lux removed at others", log.toLand);
end


------------------------------------------------------------------------------
function KekWidenStringy(isLand)
	-- Thin islands are sometimes 2 tiles wide (user 11-15): on every thin island about a third of
	-- the tiles get a land neighbour beside them (never touching another island).
	local added = 0;
	for id, island in ipairs(kek_islands) do
		if island.shape == "stringy" and island.kind ~= "start" then
			local snapshot = {};
			for loop, t in ipairs(island.plots) do table.insert(snapshot, t) end
			for loop, t in ipairs(snapshot) do
				if Map.Rand(3, "KEK widen thin") == 0 then
					local cands = {};
					for loop2, nb in ipairs(KekNeighbours(t)) do
						if KekCanGrow(nb, id, isLand, nil, nil) then table.insert(cands, nb) end
					end
					if table.maxn(cands) > 0 then
						local j = cands[1 + Map.Rand(table.maxn(cands), "KEK widen thin - spot")];
						isLand[j] = true; kek_islandOf[j] = id;
						table.insert(island.plots, j);
						added = added + 1;
					end
				end
			end
		end
	end
	print("KEK widen thin islands: tiles", added);
end
------------------------------------------------------------------------------
function KekPolarTundra()
	-- Towards the top and bottom (user 11-15): more tundra land (Furs, Deer, Sheep on the hills);
	-- grass/plains/desert in the outer 25% of rows become tundra, 75% at the poles to 35% inside.
	local iW, iH = Map.GetGridSize();
	local band = math.floor(iH * 0.25);
	local changed = 0;
	for y = 0, iH - 1 do
		local edge = math.min(y, iH - 1 - y);
		if edge < band then
			local chance = 75 - math.floor(40 * edge / math.max(1, band));
			for x = 0, iW - 1 do
				local p = Map.GetPlot(x, y);
				if p ~= nil and not p:IsWater() then
					local t = p:GetTerrainType();
					if (t == TerrainTypes.TERRAIN_GRASS or t == TerrainTypes.TERRAIN_PLAINS or t == TerrainTypes.TERRAIN_DESERT)
						and Map.Rand(100, "KEK polar tundra") < chance then
						p:SetTerrainType(TerrainTypes.TERRAIN_TUNDRA, false, false);
						changed = changed + 1;
					end
				end
			end
		end
	end
	print("KEK polar tundra: tiles", changed);
end
function KekPolarForests()
	-- Flat tundra and plains in the outer 25% of rows: forest on about half the bare tiles.
	local iW, iH = Map.GetGridSize();
	local band = math.floor(iH * 0.25);
	local forest = GameInfo.Features["FEATURE_FOREST"];
	if forest == nil then return end
	local made = 0;
	for y = 0, iH - 1 do
		if math.min(y, iH - 1 - y) < band then
			for x = 0, iW - 1 do
				local p = Map.GetPlot(x, y);
				if p ~= nil and not p:IsWater() and not p:IsMountain() and not p:IsHills()
					and p:GetFeatureType() == FeatureTypes.NO_FEATURE and not p:IsRiver()
					and (p:GetTerrainType() == TerrainTypes.TERRAIN_TUNDRA or p:GetTerrainType() == TerrainTypes.TERRAIN_PLAINS)
					and Map.Rand(2, "KEK polar forest") == 0 then
					p:SetFeatureType(forest.ID, -1);
					made = made + 1;
				end
			end
		end
	end
	print("KEK polar forests:", made);
end

------------------------------------------------------------------------------
function KekSeaRegionalOnlyHome()
	-- A coastal regional (Whales, Pearls or Crab that became a player's regional) is not also a
	-- random luxury across the map (user 11-15): copies more than 8 tiles from that capital
	-- become another sea luxury that is nobody's regional, or go when there is none.
	if kek_seaRegionals == nil or next(kek_seaRegionals) == nil then return end
	KekLoadResourceRules();
	local free = {};
	for loop, t in ipairs({"RESOURCE_WHALE", "RESOURCE_PEARLS", "RESOURCE_CRAB"}) do
		local row = GameInfo.Resources[t];
		if row ~= nil and kek_seaRegionals[row.ID] == nil then table.insert(free, row.ID) end
	end
	local iW, iH = Map.GetGridSize();
	local swapped, removed = 0, 0;
	for i = 0, iW * iH - 1 do
		local p = Map.GetPlotByIndex(i);
		local res = p:GetResourceType(-1);
		local home = kek_seaRegionals[res];
		if home ~= nil and Map.PlotDistance(p:GetX(), p:GetY(), home[1], home[2]) > 8 then
			local n = p:GetNumResource();
			local done = false;
			for tries = 1, table.maxn(free) do
				local id = free[1 + Map.Rand(table.maxn(free), "KEK sea regional - swap")];
				if kek_resourceRules[id] ~= nil and kek_resourceRules[id].terrain[p:GetTerrainType()] == true then
					p:SetResourceType(-1, 0);
					p:SetResourceType(id, n);
					swapped = swapped + 1; done = true; break;
				end
			end
			if not done then p:SetResourceType(-1, 0); removed = removed + 1 end
		end
	end
	print("KEK sea regionals only at home: swapped", swapped, "removed", removed);
end

------------------------------------------------------------------------------
function KekRegionalsAtHome(asp, nRegions)
	-- Regionals like on the game's normal maps (user 11-15): a player's regional luxury (land or
	-- coastal) never lies inside a city state's borders (3 tiles) or within 5 tiles of another
	-- player's capital. Any other copy becomes a
	-- luxury that is nobody's regional (land for land, sea for sea), or goes when none fits.
	if asp.region_luxury_assignment == nil then return end
	KekLoadResourceRules();
	local owner = {};
	for r = 1, nRegions do
		local id = asp.region_luxury_assignment[r];
		local data = asp.startingPlots[r];
		if id ~= nil and data ~= nil then owner[id] = r end
	end
	local seaKinds = {};
	for loop, t in ipairs({"RESOURCE_WHALE", "RESOURCE_PEARLS", "RESOURCE_CRAB"}) do
		if GameInfo.Resources[t] ~= nil then seaKinds[GameInfo.Resources[t].ID] = true end
	end
	local freeLand, freeSea = {}, {};
	for row in GameInfo.Resources() do
		if row.ResourceUsage == 2 and owner[row.ID] == nil and row.Type ~= "RESOURCE_JEWELRY" and row.Type ~= "RESOURCE_PORCELAIN" then
			if seaKinds[row.ID] then table.insert(freeSea, row.ID) else table.insert(freeLand, row.ID) end
		end
	end
	local function NearestCapital(x, y)
		local best, bestD = nil, 999;
		for r = 1, nRegions do
			local data = asp.startingPlots[r];
			if data ~= nil then
				local d = Map.PlotDistance(x, y, data[1], data[2]);
				if d < bestD then best, bestD = r, d end
			end
		end
		return best, bestD;
	end
	local function NearCityState(x, y)
		if asp.cityStatePlots == nil then return false end
		for n, data in pairs(asp.cityStatePlots) do
			if data[1] ~= nil and Map.PlotDistance(x, y, data[1], data[2]) <= 3 then return true end
		end
		return false;
	end
	local iW, iH = Map.GetGridSize();
	local swapped, removed = 0, 0;
	for i = 0, iW * iH - 1 do
		local p = Map.GetPlotByIndex(i);
		local res = p:GetResourceType(-1);
		local r = owner[res];
		if r ~= nil then
			local x, y = p:GetX(), p:GetY();
			local data = asp.startingPlots[r];
			local nearest, nd = NearestCapital(x, y);
			local dOwn = Map.PlotDistance(x, y, data[1], data[2]);
			-- user 11-15: spread out like the game's own maps - anywhere except inside a city state's borders
			-- (3 tiles) or within 5 tiles of another player's capital
			local nearOther = false;
			for r2 = 1, nRegions do
				local d2 = asp.startingPlots[r2];
				if r2 ~= r and d2 ~= nil and Map.PlotDistance(x, y, d2[1], d2[2]) <= 5 then nearOther = true end
			end
			if nearOther or NearCityState(x, y) then
				local n = p:GetNumResource();
				p:SetResourceType(-1, 0);
				local list = p:IsWater() and freeSea or freeLand;
				local done = false;
				for tries = 1, 2 * table.maxn(list) do
					local id = list[1 + Map.Rand(table.maxn(list), "KEK regionals at home - swap")];
					local fits;
					if p:IsWater() then fits = kek_resourceRules[id] ~= nil and kek_resourceRules[id].terrain[p:GetTerrainType()] == true
					else fits = KekResourceFits(p, id, false) end
					if fits then p:SetResourceType(id, n); swapped = swapped + 1; done = true; break end
				end
				if not done then
					-- second try: any free luxury the terrain allows
					for tries = 1, 2 * table.maxn(list) do
						local id = list[1 + Map.Rand(table.maxn(list), "KEK regionals at home - swap 2")];
						if kek_resourceRules[id] ~= nil and kek_resourceRules[id].terrain[p:GetTerrainType()] == true then
							p:SetResourceType(id, n); swapped = swapped + 1; done = true; break
						end
					end
				end
				if not done then removed = removed + 1 end
			end
		end
	end
	print("KEK regionals at home: swapped", swapped, "removed", removed);
	-- user 11-15: at most 3 sea luxuries within 3 tiles of a capital (the farthest extras go)
	local cut = 0;
	for r = 1, nRegions do
		local data = asp.startingPlots[r];
		if data ~= nil then
			local list = {};
			for loop, p in ipairs(KekPlotsInRings(data[1], data[2], 1, 3)) do
				if seaKinds[p:GetResourceType(-1)] then table.insert(list, p) end
			end
			table.sort(list, function(a, b)
				return Map.PlotDistance(data[1], data[2], a:GetX(), a:GetY()) < Map.PlotDistance(data[1], data[2], b:GetX(), b:GetY())
			end);
			for n = 4, table.maxn(list) do list[n]:SetResourceType(-1, 0); cut = cut + 1 end
		end
	end
	print("KEK capitals: sea luxuries over 3 removed", cut);
	-- user 11-15: a city state has at most 1 luxury within 3 tiles (the nearest stays); a tile that is
	-- also within 3 of a capital belongs to the capital's count and is left alone
	local csCut = 0;
	if asp.cityStatePlots ~= nil then
		for n, data in pairs(asp.cityStatePlots) do
			if data[1] ~= nil then
				local list = {};
				for loop, p in ipairs(KekPlotsInRings(data[1], data[2], 1, 3)) do
					local res = p:GetResourceType(-1);
					if res ~= -1 and GameInfo.Resources[res] ~= nil and GameInfo.Resources[res].ResourceUsage == 2 then table.insert(list, p) end
				end
				table.sort(list, function(a, b)
					return Map.PlotDistance(data[1], data[2], a:GetX(), a:GetY()) < Map.PlotDistance(data[1], data[2], b:GetX(), b:GetY())
				end);
				for k = 2, table.maxn(list) do
					local p = list[k];
					local nearCap = false;
					for r = 1, nRegions do
						local c = asp.startingPlots[r];
						if c ~= nil and Map.PlotDistance(p:GetX(), p:GetY(), c[1], c[2]) <= 3 then nearCap = true end
					end
					if not nearCap then p:SetResourceType(-1, 0); csCut = csCut + 1 end
				end
			end
		end
	end
	print("KEK city states: luxuries over 1 removed", csCut);
end
