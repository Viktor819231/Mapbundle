------------------------------------------------------------------------------
--	FILE:	 KEKLargeIslands.lua
--	AUTHOR:  KEK multiplayer community (2026), built on Firaxis' Large_Islands.lua
--	         (Bob Thomas)
--	PURPOSE: The game's Large Islands (same island making, options, sizes, wrap),
--	         made fair for free for all games. NOT mirrored.
--	         1. Every player starts alone on an own large island (the game's
--	            Large Islands sometimes puts two players on one island).
--	         2. All start islands get the same land: the same number of tiles,
--	            the same number of hills and the same number of mountains
--	            (option: 45 / 55 / 65 / 75 tiles; the game's islands are about
--	            40-70). Mountains on start islands are lone peaks inside the
--	            island, never a wall, never cutting the island in two.
--	         3. Start islands are spread out over the map and kept away from the
--	            polar rows. No lakes and no natural wonders on start islands;
--	            the game's small island chains and natural wonders stay at
--	            least 3 tiles away from them.
--	         4. Free large islands (nobody starts there): option None / Few /
--	            Game's / More. Expansion islands of 16 tiles: the same number
--	            for every player (option None / One / Two each), 3-5 tiles of
--	            water off its own start island, same hills; no city states or
--	            natural wonders there. Small islands (20 tiles or less) get about
--	            one Fish per 4 coast tiles (none within 3 tiles of a start island).
--	         5. Strategic Balance (the default resource setting here): every
--	            capital gets Horses, Iron (12), Coal (7) and Aluminium (3) within
--	            3 tiles; weak starts get a hill and food bonuses (the same start
--	            lifts as KEK BitMoreFairPangea).
--	         Deterministic: only Map.Rand is used (multiplayer safe).
------------------------------------------------------------------------------
--	Copyright (c) 2012 Firaxis Games, Inc. All rights reserved.
--	KEK additions (2026) are free to use and change.
------------------------------------------------------------------------------

include("MapGenerator");
include("MultilayeredFractal");
include("FeatureGenerator");
include("TerrainGenerator");
include("IslandMaker");

------------------------------------------------------------------------------
-- Sea maps: half the game's ruins (user, 11-14). Sea ruins are their own option.
------------------------------------------------------------------------------
KekLIRuinHalf_AddGoodies = AddGoodies;
function AddGoodies()
	KekLIRuinHalf_AddGoodies();
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
KEK_START_SIZES = {45, 55, 65, 75};		-- land tiles of every start island, by option
KEK_FREE_PER_PLAYER = {0, 0.35, 0.65, 1.0};	-- free large islands per player, by option (game: 0.65)
KEK_EXPANSION_PER_PLAYER = {0, 1, 2};		-- expansion islands per player, by option
KEK_EXPANSION_SIZE = 16;				-- tiles of every expansion island
KEK_CHAIN_KEEP_PERCENT = 30;			-- share of the game's small island pieces that stay (user: mostly large islands)
KEK_SMALL_ISLAND_TILES = 20;			-- islands this small or smaller get more Fish
KEK_COAST_PER_FISH = 4;					-- small islands: about one Fish per this many coast tiles (set from the option)
KEK_SEA_COAST_PER_FISH = {5, 4, 3.5, 3, 2.5, 2};	-- "Sea resources" option: small islands, coast tiles per Fish (2 = the old rule)
KEK_SEA_CAPITAL_FISH = {1, 2, 2, 3, 3, 4};		-- "Sea resources" option: Fish within 3 tiles of every capital (the same for all)
KEK_SEA_BIG_COAST = {0, 0, 14, 10, 8, 6};		-- "Sea resources" option: big islands, one extra Fish per this many coast tiles (0 = none)
KEK_TREASURE_COUNT = {0, 2, 3, 0};				-- "Small treasure islands" option (option 4 = one per player)
kek_treasureTile = {};	-- GLOBAL plot index (1-based) -> treasure island number (3-5 tiles, a luxury and sea resources)
kek_treasureIslands = {};	-- GLOBAL treasure island number -> list of plot indices (1-based)
kek_seaLog = nil;		-- GLOBAL what the sea resources did (for the offline tests)
KEK_HILL_PERCENTS = {20, 30, 42, 56, 72, 90};	-- "Hills" option (as KEK Archipelago): share of hills
KEK_LAND_BONUS = {0.04, 0.08, 0.12, 0.16, 0.20, 0.25};	-- "Land resources" option: extra bonus per free land tile
KEK_CAPITAL_BONUS = {2, 3, 3, 4, 4, 5};		-- "Land resources" option: land bonus within 3 tiles of every capital
KEK_CAPITAL_IRON = 9;					-- Strategic Balance: Iron at every capital (user 11-15: 9; was 12, then 6)
kek_hillPercent = 30;	-- GLOBAL the chosen hill share
kek_bonusLog = nil;		-- GLOBAL what the land bonus did (for the offline tests)
KEK_TILES_PER_MOUNTAIN = 25;			-- at most one mountain per this many tiles of a start island
KEK_POLAR_PERCENT = 15;					-- start islands stay out of this share of rows at each pole (was 12: a capital got iced in; user: 15)
KEK_FORMATIONS = { {4, 2}, {2, 4}, {3, 3} };	-- the game's large island blocks, in cells of 5 x 4 tiles

kek_startIslands = {};	-- GLOBAL one entry per start island: tiles (plot index 1-based -> true), box, size
kek_startTile = {};		-- GLOBAL plot index (1-based) -> start island number
kek_nearStart = {};		-- GLOBAL plot index (1-based) -> true: start island tiles and 2 tiles around them
kek_shapeLog = nil;		-- GLOBAL what the shaping did (for the offline tests)
kek_expansionTile = {};	-- GLOBAL plot index (1-based) -> player number (start island) of its expansion island
kek_expansionCount = 0;	-- GLOBAL expansion islands each player got
kek_fishLog = nil;		-- GLOBAL what the small island Fish did (for the offline tests)
------------------------------------------------------------------------------
function GetMapScriptInfo()
	local world_age, temperature, rainfall, sea_level, resources = GetCoreMapOptions()
	-- Same list as Large Islands; Strategic Balance (5) is the default here.
	resources.DefaultValue = 5;
	return {
		Name = "KEK Large Islands 1.1",
		Description = "The game's Large Islands, fair for free for all: every player starts alone on an own island, all start islands have the same size, hills and mountains, spread out and away from the poles. Strategic Balance: 12 Iron, Coal and Aluminium near every capital. Hills and land resource options as KEK Archipelago.",
		IsAdvancedMap = false,
		IconIndex = 2,
		SortIndex = 3,
		CustomOptions = {world_age, temperature, rainfall, resources,
			{
				Name = "Start island size",
				Values = {
					"Smaller (45 tiles)",
					"Normal (55 tiles)",
					"Bigger (65 tiles)",
					"Large (75 tiles)",
				},
				DefaultValue = 3,
				SortPriority = 1,
			},
			{
				Name = "Free large islands",
				Values = {
					"None",
					"Few",
					"Normal (as the game)",
					"More",
				},
				DefaultValue = 3,
				SortPriority = 2,
			},
			{
				Name = "Expansion islands (16 tiles)",
				Values = {
					"None",
					"One per player",
					"Two per player",
				},
				DefaultValue = 2,
				SortPriority = 3,
			},
			{
				Name = "Hills",
				Values = {
					"1 (about 20%)",
					"2 (about 30%)",
					"3 (about 42%)",
					"4 (about 56%)",
					"5 (about 72%)",
					"6 (about 90%)",
				},
				DefaultValue = 4,
				SortPriority = 4,
			},
			{
				Name = "Land resources (bonus)",
				Values = {
					"1 (4% extra, capitals 2)",
					"2 (8% extra, capitals 3)",
					"3 (12% extra, capitals 3)",
					"4 (16% extra, capitals 4)",
					"5 (20% extra, capitals 4)",
					"6 (25% extra, capitals 5)",
				},
				DefaultValue = 4,
				SortPriority = 5,
			},
			{
				Name = "Sea resources (Fish)",
				Values = {
					"1 (fewer)",
					"2 (about as before)",
					"3 (more)",
					"4 (lots)",
					"5 (very many)",
					"6 (most)",
				},
				DefaultValue = 3,
				SortPriority = 6,
			},
			{
				Name = "Small treasure islands (3-5 tiles)",
				Values = {
					"None",
					"A couple (2)",
					"A few (3)",
					"One per player",
				},
				DefaultValue = 4,
				SortPriority = 7,
			},
			{
				-- option 12 (read by position); shown first
				Name = "Map size",
				Values = {
					"Normal",
					"Compact",
				},
				DefaultValue = 1,
				SortPriority = -1,
			},
		},
	}
end
------------------------------------------------------------------------------
function GetMapInitData(worldSize)
	local worldsizes = {
		[GameInfo.Worlds.WORLDSIZE_DUEL.ID] = {30, 24},
		[GameInfo.Worlds.WORLDSIZE_TINY.ID] = {50, 40},
		[GameInfo.Worlds.WORLDSIZE_SMALL.ID] = {60, 48},
		[GameInfo.Worlds.WORLDSIZE_STANDARD.ID] = {80, 56},
		[GameInfo.Worlds.WORLDSIZE_LARGE.ID] = {100, 64},
		[GameInfo.Worlds.WORLDSIZE_HUGE.ID] = {120, 80}
		}
	local grid_size = worldsizes[worldSize];
	-- Map size option (12): Normal / Compact (about 3/4 of the tiles) / Brawl (about 0.55)
	local f = ({1.0, 0.87, 0.74})[KekOption(12, 3, 1)] or 1.0;
	-- never smaller than the start islands need: about 10 map tiles per start-island tile
	local okP, players = pcall(function()
		local n = 0;
		for i = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
			local st = PreGame.GetSlotStatus(i);
			if st == SlotStatus.SS_TAKEN or st == SlotStatus.SS_COMPUTER then n = n + 1 end
		end
		return n;
	end);
	if okP and players and players > 0 and grid_size ~= nil then
		local islandTiles = ({45, 55, 65, 75})[KekOption(5, 4, 3)] or 65;
		local need = players * islandTiles * 10;
		while f < 1.0 and grid_size[1] * grid_size[2] * f * f < need do f = math.min(1.0, f + 0.02) end
	end
	--
	local world = GameInfo.Worlds[worldSize];
	if (world ~= nil) then
		return {
			Width = math.floor(grid_size[1] * f + 0.5),
			Height = math.floor(grid_size[2] * f + 0.5),
			WrapX = true,
		};
	end
end
------------------------------------------------------------------------------
function KekOption(n, count, default)
	local v = Map.GetCustomOption(n);
	if v == nil or v < 1 or v > count then
		return default;
	end
	return v;
end
------------------------------------------------------------------------------
function KekBuildAdjacency()
	-- adj[i] = the 6 neighbours of plot i (1-based), in direction order
	-- (NE, E, SE, SW, W, NW), 0 off the map. Wraps east-west like the map.
	local iW, iH = Map.GetGridSize();
	local adj = {};
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local list = {};
			for dir = 0, 5 do
				local p = Map.PlotDirection(x, y, dir);
				if p ~= nil then
					list[dir + 1] = p:GetY() * iW + p:GetX() + 1;
				else
					list[dir + 1] = 0;
				end
			end
			adj[y * iW + x + 1] = list;
		end
	end
	return adj;
end
------------------------------------------------------------------------------
function KekPickFormation()
	-- The game's appearance rates: 4x2 cells 5, 2x4 cells 5, 3x3 cells 6.
	local roll = Map.Rand(16, "KEK Large Islands - formation");
	if roll < 5 then
		return 1;
	elseif roll < 10 then
		return 2;
	end
	return 3;
end
------------------------------------------------------------------------------
function KekBlockFree(cells, cols, rows, cx, cy, cw, ch)
	if cx < 1 or cy < 1 or cx + cw - 1 > cols or cy + ch - 1 > rows then
		return false;
	end
	for y = cy, cy + ch - 1 do
		for x = cx, cx + cw - 1 do
			if cells[(y - 1) * cols + x] then
				return false;
			end
		end
	end
	return true;
end
------------------------------------------------------------------------------
function KekTakeBlock(cells, cols, cx, cy, cw, ch)
	for y = cy, cy + ch - 1 do
		for x = cx, cx + cw - 1 do
			cells[(y - 1) * cols + x] = true;
		end
	end
	return cw * ch;
end
------------------------------------------------------------------------------
function MultilayeredFractal:KekMakeLargeIsland(formation, cx, cy, cellW, cellH)
	-- One large island in its block of cells, made exactly as the game's Large Islands does.
	local iWestX = cellW * (cx - 1) + 1;
	local iSouthY = cellH * (cy - 1) + 1;
	local iWidth, iHeight;
	local iWater, iCohesionWater = 55, 60;
	local FracXExp, FracYExp = 5, 5;
	if formation == 1 then -- four cells wide, two cells tall.
		iWidth = cellW * 4 - 2;
		iHeight = cellH * 2 - 2;
		FracXExp = 6;
	elseif formation == 2 then -- two cells wide, four cells tall.
		iWidth = cellW * 2 - 2;
		iHeight = cellH * 4 - 2;
		FracYExp = 6;
	else -- three cells wide, three cells tall.
		iWidth = cellW * 3 - 2;
		iHeight = cellH * 3 - 2;
		iWater = 60;
	end
	local iCohesionW = math.floor(iWidth / 2);
	local iCohesionH = math.floor(iHeight / 2);
	local iCoWestX = iWestX + math.floor(iWidth / 4);
	local iCoSouthY = iSouthY + math.floor(iHeight / 4);

	local args = {};
	args.iWaterPercent = iWater;
	args.iRegionWidth = iWidth;
	args.iRegionHeight = iHeight;
	args.iRegionWestX = iWestX;
	args.iRegionSouthY = iSouthY;
	args.iRegionPlotFlags = self.iRoundFlags;
	args.iRegionFracXExp = FracXExp;
	args.iRegionFracYExp = FracYExp;
	args.iRiftGrain = -1;
	self:GenerateFractalLayerWithoutHills(args)

	local args = {};
	args.iWaterPercent = iCohesionWater;
	args.iRegionWidth = iCohesionW;
	args.iRegionHeight = iCohesionH;
	args.iRegionWestX = iCoWestX;
	args.iRegionSouthY = iCoSouthY;
	args.iRegionPlotFlags = self.iRoundFlags;
	args.iRegionFracXExp = FracXExp;
	args.iRegionFracYExp = FracYExp;
	args.iRiftGrain = -1;
	self:GenerateFractalLayerWithoutHills(args)

	return {x0 = iWestX, y0 = iSouthY, x1 = iWestX + iWidth - 1, y1 = iSouthY + iHeight - 1};
end
------------------------------------------------------------------------------
function KekFindBlocks(cells, cols, rows, cellW, cellH, formation, polarRows)
	-- Every free place for this formation, in a fixed order. polarRows > 0: the
	-- island's own rows must stay that far from both poles.
	local iW, iH = Map.GetGridSize();
	local cw, ch = KEK_FORMATIONS[formation][1], KEK_FORMATIONS[formation][2];
	local list = {};
	for cy = 1, rows - ch + 1 do
		for cx = 1, cols - cw + 1 do
			local south = cellH * (cy - 1) + 1;
			local north = cellH * (cy + ch - 1) - 2;
			if south >= polarRows and north <= iH - 1 - polarRows and KekBlockFree(cells, cols, rows, cx, cy, cw, ch) then
				table.insert(list, {f = formation, cx = cx, cy = cy, cw = cw, ch = ch,
					mx = cellW * (cx - 1) + math.floor(cellW * cw / 2), my = cellH * (cy - 1) + math.floor(cellH * ch / 2)});
			end
		end
	end
	return list;
end
------------------------------------------------------------------------------
function MultilayeredFractal:KekPlaceStartIslands(numCivs, cells, cols, rows, cellW, cellH)
	-- One large island per player. The first goes anywhere; each next one goes
	-- where it is furthest from the start islands already placed (a random
	-- pick among the places within 1 tile of the best), so they spread out.
	local iW, iH = Map.GetGridSize();
	local polar = math.floor(iH * KEK_POLAR_PERCENT / 100);
	local used = 0;
	kek_startIslands = {};
	for n = 1, numCivs do
		local first = KekPickFormation();
		local cands = {};
		for pass = 1, 2 do
			for k = 0, 2 do
				local f = ((first - 1 + k) % 3) + 1;
				cands = KekFindBlocks(cells, cols, rows, cellW, cellH, f, (pass == 1) and polar or 0);
				if #cands > 0 then
					break
				end
			end
			if #cands > 0 then
				break
			end
		end
		if #cands == 0 then
			print("KEK Large Islands: no room for start island", n);
			break
		end
		local pick;
		if #kek_startIslands == 0 then
			pick = cands[1 + Map.Rand(#cands, "KEK Large Islands - first start island")];
		else
			local best = -1;
			for _, c in ipairs(cands) do
				local d = 9999;
				for _, isl in ipairs(kek_startIslands) do
					d = math.min(d, Map.PlotDistance(c.mx, c.my, isl.mx, isl.my));
				end
				c.d = d;
				if d > best then
					best = d;
				end
			end
			local good = {};
			for _, c in ipairs(cands) do
				if c.d >= best - 1 then
					table.insert(good, c);
				end
			end
			pick = good[1 + Map.Rand(#good, "KEK Large Islands - start island place")];
		end
		used = used + KekTakeBlock(cells, cols, pick.cx, pick.cy, pick.cw, pick.ch);
		local region = self:KekMakeLargeIsland(pick.f, pick.cx, pick.cy, cellW, cellH);
		table.insert(kek_startIslands, {
			mx = pick.mx, my = pick.my, region = region,
			box = {x0 = cellW * (pick.cx - 1), y0 = cellH * (pick.cy - 1),
				x1 = cellW * (pick.cx + pick.cw - 1) - 1, y1 = cellH * (pick.cy + pick.ch - 1) - 1},
		});
	end
	return used;
end
------------------------------------------------------------------------------
function MultilayeredFractal:KekPlaceFreeIslands(count, cells, cols, rows, cellW, cellH, used, target)
	-- Large islands where nobody starts, placed at random like the game's.
	local placed = 0;
	for n = 1, count do
		if used >= target then
			break
		end
		local first = KekPickFormation();
		local cands = {};
		for k = 0, 2 do
			cands = KekFindBlocks(cells, cols, rows, cellW, cellH, ((first - 1 + k) % 3) + 1, 0);
			if #cands > 0 then
				break
			end
		end
		if #cands == 0 then
			break
		end
		local pick = cands[1 + Map.Rand(#cands, "KEK Large Islands - free island place")];
		used = used + KekTakeBlock(cells, cols, pick.cx, pick.cy, pick.cw, pick.ch);
		self:KekMakeLargeIsland(pick.f, pick.cx, pick.cy, cellW, cellH);
		placed = placed + 1;
	end
	return placed;
end
------------------------------------------------------------------------------
-- START ISLANDS: same land, hills and mountains on every one
------------------------------------------------------------------------------
function KekShapeStartIslands(plots, adj, targetSize)
	local iW, iH = Map.GetGridSize();
	local OCEAN, LAND, HILLS, MOUNTAIN = PlotTypes.PLOT_OCEAN, PlotTypes.PLOT_LAND, PlotTypes.PLOT_HILLS, PlotTypes.PLOT_MOUNTAIN;
	local log = {target = targetSize, before = {}, grown = {}};

	local function BoxTiles(isl)
		-- the island's block, row by row (a fixed order: the same on every computer)
		local list = {};
		for y = isl.box.y0, isl.box.y1 do
			for x = isl.box.x0, isl.box.x1 do
				table.insert(list, y * iW + x + 1);
			end
		end
		return list;
	end
	local function InBox(isl, i)
		local x, y = (i - 1) % iW, math.floor((i - 1) / iW);
		return x >= isl.box.x0 and x <= isl.box.x1 and y >= isl.box.y0 and y <= isl.box.y1;
	end
	local function PickRandom(list, what)
		return list[1 + Map.Rand(#list, "KEK Large Islands - " .. what)];
	end

	-- 1. The biggest piece of land in the block is the island; everything else
	--    in the block, and any land within 2 tiles of the island, becomes sea.
	for k, isl in ipairs(kek_startIslands) do
		isl.boxTiles = BoxTiles(isl);
		local seen, bestPiece = {}, nil;
		for _, i in ipairs(isl.boxTiles) do
			if plots[i] ~= OCEAN and not seen[i] then
				local piece, stack = {i}, {i};
				seen[i] = true;
				while #stack > 0 do
					local c = table.remove(stack);
					for _, j in ipairs(adj[c]) do
						if j > 0 and not seen[j] and plots[j] ~= OCEAN and InBox(isl, j) then
							seen[j] = true;
							table.insert(piece, j);
							table.insert(stack, j);
						end
					end
				end
				if bestPiece == nil or #piece > #bestPiece then
					bestPiece = piece;
				end
			end
		end
		isl.tiles = {};
		if bestPiece == nil then
			-- the fractal made no land at all: start from the middle of the island's region
			local cx = math.floor((isl.region.x0 + isl.region.x1) / 2);
			local cy = math.floor((isl.region.y0 + isl.region.y1) / 2);
			bestPiece = {cy * iW + cx + 1};
			plots[bestPiece[1]] = LAND;
		end
		for _, i in ipairs(bestPiece) do
			isl.tiles[i] = true;
		end
		for _, i in ipairs(isl.boxTiles) do
			if plots[i] ~= OCEAN and not isl.tiles[i] then
				plots[i] = OCEAN;
			end
		end
	end
	for k, isl in ipairs(kek_startIslands) do
		for _, i in ipairs(isl.boxTiles) do
			if isl.tiles[i] then
				for _, j in ipairs(adj[i]) do
					if j > 0 then
						if plots[j] ~= OCEAN and not isl.tiles[j] then plots[j] = OCEAN; end
						for _, m in ipairs(adj[j]) do
							if m > 0 and plots[m] ~= OCEAN and not isl.tiles[m] then plots[m] = OCEAN; end
						end
					end
				end
			end
		end
	end

	-- 2. Mountains become hills for now (lone peaks are put back in step 5).
	for k, isl in ipairs(kek_startIslands) do
		local n = 0;
		for _, i in ipairs(isl.boxTiles) do
			if isl.tiles[i] then
				n = n + 1;
				if plots[i] == MOUNTAIN then
					plots[i] = HILLS;
				end
			end
		end
		isl.size = n;
		table.insert(log.before, n);
	end

	-- 3. Size: grow (fill bays first) or trim (spits first) to the same number of tiles.
	local function CanGrowInto(isl, i)
		if plots[i] ~= OCEAN or not InBox(isl, i) then
			return false;
		end
		-- never within 2 tiles of land that is not this island
		for _, j in ipairs(adj[i]) do
			if j == 0 then
				return false;	-- not on the map's top or bottom row
			end
			if plots[j] ~= OCEAN and not isl.tiles[j] then
				return false;
			end
			for _, m in ipairs(adj[j]) do
				if m > 0 and plots[m] ~= OCEAN and not isl.tiles[m] then
					return false;
				end
			end
		end
		return true;
	end
	local function Grow(isl)
		local best, list, seen = 0, {}, {};
		for _, i in ipairs(isl.boxTiles) do
			if isl.tiles[i] then
				for _, j in ipairs(adj[i]) do
					if j > 0 and not seen[j] then
						seen[j] = true;
						if CanGrowInto(isl, j) then
							local n = 0;
							for _, m in ipairs(adj[j]) do
								if m > 0 and isl.tiles[m] then n = n + 1; end
							end
							if n > best then
								best, list = n, {j};
							elseif n == best then
								table.insert(list, j);
							end
						end
					end
				end
			end
		end
		if #list == 0 then
			return false;
		end
		local i = PickRandom(list, "grow start island");
		plots[i] = LAND;
		isl.tiles[i] = true;
		isl.size = isl.size + 1;
		return true;
	end
	local function CanTrim(isl, i)
		-- a coast tile whose island neighbours form one unbroken run round it:
		-- taking it away never cuts the island in two
		local inIsl, n, water = {}, 0, false;
		for d = 1, 6 do
			local j = adj[i][d];
			inIsl[d] = (j > 0 and isl.tiles[j] == true);
			if inIsl[d] then n = n + 1; else water = true; end
		end
		if not water or n == 0 then
			return false, n;
		end
		local runs = 0;
		for d = 1, 6 do
			local prev = (d == 1) and 6 or (d - 1);
			if inIsl[d] and not inIsl[prev] then runs = runs + 1; end
		end
		return runs == 1, n;
	end
	local function Trim(isl)
		local best, list = 99, {};
		for _, i in ipairs(isl.boxTiles) do
			if isl.tiles[i] then
				local ok, n = CanTrim(isl, i);
				if ok then
					if n < best then
						best, list = n, {i};
					elseif n == best then
						table.insert(list, i);
					end
				end
			end
		end
		if #list == 0 then
			return false;
		end
		local i = PickRandom(list, "trim start island");
		plots[i] = OCEAN;
		isl.tiles[i] = nil;
		isl.size = isl.size - 1;
		return true;
	end
	local size = targetSize;
	for k, isl in ipairs(kek_startIslands) do
		while isl.size < size and Grow(isl) do end
		while isl.size > size and Trim(isl) do end
		table.insert(log.grown, isl.size);
	end
	for k, isl in ipairs(kek_startIslands) do
		size = math.min(size, isl.size);	-- an island boxed in short of the target: all go down to it
	end
	for k, isl in ipairs(kek_startIslands) do
		while isl.size > size and Trim(isl) do end
	end
	log.size = size;

	-- 4. Hills: the same number on every start island (the "Hills" option's share).
	for k, isl in ipairs(kek_startIslands) do
		local h = 0;
		for _, i in ipairs(isl.boxTiles) do
			if isl.tiles[i] and plots[i] == HILLS then h = h + 1; end
		end
		isl.hills = h;
	end
	local hills = math.floor(size * kek_hillPercent / 100 + 0.5);
	log.hills = hills;
	local function HillNeighbours(i)
		local n = 0;
		for _, j in ipairs(adj[i]) do
			if j > 0 and (plots[j] == HILLS or plots[j] == MOUNTAIN) then n = n + 1; end
		end
		return n;
	end
	for k, isl in ipairs(kek_startIslands) do
		while isl.hills < hills do	-- new hills next to hills (ranges, not scattered dots)
			local best, list = -1, {};
			for _, i in ipairs(isl.boxTiles) do
				if isl.tiles[i] and plots[i] == LAND then
					local n = HillNeighbours(i);
					if n > best then best, list = n, {i}; elseif n == best then table.insert(list, i); end
				end
			end
			if #list == 0 then break end
			plots[PickRandom(list, "add hill")] = HILLS;
			isl.hills = isl.hills + 1;
		end
		while isl.hills > hills do	-- lone hills go first
			local best, list = 99, {};
			for _, i in ipairs(isl.boxTiles) do
				if isl.tiles[i] and plots[i] == HILLS then
					local n = HillNeighbours(i);
					if n < best then best, list = n, {i}; elseif n == best then table.insert(list, i); end
				end
			end
			if #list == 0 then break end
			plots[PickRandom(list, "remove hill")] = LAND;
			isl.hills = isl.hills - 1;
		end
	end

	-- 5. Mountains: lone peaks on inland hills (all 6 neighbours island land,
	--    none a mountain), so a peak never cuts the island. Same count on all.
	local cap = math.floor(size / KEK_TILES_PER_MOUNTAIN);
	local fewest = cap;
	for k, isl in ipairs(kek_startIslands) do
		isl.peaks = {};
		for n = 1, cap do
			local list = {};
			for _, i in ipairs(isl.boxTiles) do
				if isl.tiles[i] and plots[i] == HILLS then
					local inland = true;
					for _, j in ipairs(adj[i]) do
						if j == 0 or not isl.tiles[j] or plots[j] == MOUNTAIN then inland = false; break end
					end
					if inland then table.insert(list, i); end
				end
			end
			if #list == 0 then break end
			local i = PickRandom(list, "start island peak");
			plots[i] = MOUNTAIN;
			table.insert(isl.peaks, i);
		end
		fewest = math.min(fewest, #isl.peaks);
	end
	for k, isl in ipairs(kek_startIslands) do
		while #isl.peaks > fewest do
			plots[table.remove(isl.peaks)] = HILLS;
		end
	end
	log.mountains = fewest;

	-- 6. Remember the islands: no lakes there, no small islands next to them.
	kek_startTile, kek_nearStart = {}, {};
	for k, isl in ipairs(kek_startIslands) do
		for _, i in ipairs(isl.boxTiles) do
			if isl.tiles[i] then
				kek_startTile[i] = k;
				kek_nearStart[i] = true;
				for _, j in ipairs(adj[i]) do
					if j > 0 then
						kek_nearStart[j] = true;
						for _, m in ipairs(adj[j]) do
							if m > 0 then kek_nearStart[m] = true; end
						end
					end
				end
			end
		end
	end
	kek_shapeLog = log;
	print("KEK Large Islands: start islands", #kek_startIslands, "size", size, "hills", hills - fewest, "mountains", fewest,
		"(made", table.concat(log.before, " "), ")");
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- EXPANSION ISLANDS: the same number and size for every player, off its own coast
------------------------------------------------------------------------------
function KekDistances(adj, sources, maxD)
	-- Steps from the nearest source tile (any terrain), up to maxD; nil = further.
	local dist, queue, head = {}, {}, 1;
	for _, i in ipairs(sources) do
		dist[i] = 0;
		table.insert(queue, i);
	end
	while head <= #queue do
		local i = queue[head];
		head = head + 1;
		local d = dist[i];
		if d < maxD then
			for _, j in ipairs(adj[i]) do
				if j > 0 and dist[j] == nil then
					dist[j] = d + 1;
					table.insert(queue, j);
				end
			end
		end
	end
	return dist;
end
------------------------------------------------------------------------------
function KekPlaceExpansionIslands(plots, adj, perPlayer, size)
	local iW, iH = Map.GetGridSize();
	local N = iW * iH;
	local OCEAN, LAND, HILLS = PlotTypes.PLOT_OCEAN, PlotTypes.PLOT_LAND, PlotTypes.PLOT_HILLS;
	kek_expansionTile = {};
	kek_expansionCount = 0;
	if perPlayer <= 0 or #kek_startIslands == 0 then
		return
	end
	local distStart = {};
	for k, isl in ipairs(kek_startIslands) do
		local src = {};
		for i = 1, N do
			if isl.tiles[i] then table.insert(src, i); end
		end
		distStart[k] = KekDistances(adj, src, 12);
	end
	local function Clear(t, own)
		-- water, not near the poles, no land within 2 tiles except this island's own
		if plots[t] ~= OCEAN then return false end
		local y = math.floor((t - 1) / iW);
		if y < 2 or y > iH - 3 then return false end
		for _, j in ipairs(adj[t]) do
			if j == 0 then return false end
			if plots[j] ~= OCEAN and not own[j] then return false end
			for _, m in ipairs(adj[j]) do
				if m > 0 and plots[m] ~= OCEAN and not own[m] then return false end
			end
		end
		return true
	end
	local function Centres(k)
		-- 3-5 tiles of water from its own start island, clearly closer to it than to any other
		local list = {};
		for i = 1, N do
			local d = distStart[k][i];
			if d ~= nil and d >= 4 and d <= 6 then
				local mine = true;
				for j = 1, #kek_startIslands do
					if j ~= k and distStart[j][i] ~= nil and distStart[j][i] <= d + 1 then
						mine = false;
						break
					end
				end
				if mine and Clear(i, {}) then
					table.insert(list, i);
				end
			end
		end
		return list;
	end
	local function Grow(c)
		local own, list = {[c] = true}, {c};
		plots[c] = LAND;
		while #list < size do
			local best, cands, seen = -1, {}, {};
			for _, i in ipairs(list) do
				for _, j in ipairs(adj[i]) do
					if j > 0 and not own[j] and not seen[j] then
						seen[j] = true;
						if Clear(j, own) then
							local n = 0;
							for _, m in ipairs(adj[j]) do
								if m > 0 and own[m] then n = n + 1; end
							end
							if n > best then
								best, cands = n, {j};
							elseif n == best then
								table.insert(cands, j);
							end
						end
					end
				end
			end
			if #cands == 0 then break end
			local t = cands[1 + Map.Rand(#cands, "KEK Large Islands - grow expansion island")];
			own[t] = true;
			table.insert(list, t);
			plots[t] = LAND;
		end
		if #list < size then
			for _, i in ipairs(list) do plots[i] = OCEAN; end
			return nil
		end
		return list;
	end
	-- Round by round, one island per player each round; a round where any
	-- player gets none is undone for everybody (all players keep the same count).
	local made = {};
	for round = 1, perPlayer do
		local thisRound, ok = {}, true;
		for k = 1, #kek_startIslands do
			local cands, isl = Centres(k), nil;
			for try = 1, 12 do
				if #cands == 0 then break end
				local c = table.remove(cands, 1 + Map.Rand(#cands, "KEK Large Islands - expansion island place"));
				if Clear(c, {}) then
					isl = Grow(c);
				end
				if isl ~= nil then break end
			end
			if isl == nil then
				ok = false;
				break
			end
			thisRound[k] = isl;
		end
		if not ok then
			for k = 1, #kek_startIslands do
				if thisRound[k] then
					for _, i in ipairs(thisRound[k]) do plots[i] = OCEAN; end
				end
			end
			break
		end
		for k = 1, #kek_startIslands do
			table.insert(made, {owner = k, tiles = thisRound[k]});
		end
		kek_expansionCount = round;
	end
	-- Same hills on each (the "Hills" option's share), in one group.
	local hills = math.floor(size * kek_hillPercent / 100 + 0.5);
	for _, e in ipairs(made) do
		local own = {};
		for _, i in ipairs(e.tiles) do own[i] = true; end
		local h = 0;
		while h < hills do
			local best, cands = -1, {};
			for _, i in ipairs(e.tiles) do
				if plots[i] == LAND then
					local n = 0;
					for _, m in ipairs(adj[i]) do
						if m > 0 and own[m] and plots[m] == HILLS then n = n + 1; end
					end
					if n > best then best, cands = n, {i}; elseif n == best then table.insert(cands, i); end
				end
			end
			if #cands == 0 then break end
			plots[cands[1 + Map.Rand(#cands, "KEK Large Islands - expansion hill")]] = HILLS;
			h = h + 1;
		end
		for _, i in ipairs(e.tiles) do
			kek_expansionTile[i] = e.owner;
			kek_nearStart[i] = true;
			for _, j in ipairs(adj[i]) do
				if j > 0 then
					kek_nearStart[j] = true;
					for _, m in ipairs(adj[j]) do
						if m > 0 then kek_nearStart[m] = true; end
					end
				end
			end
		end
	end
	print("KEK Large Islands: expansion islands per player", kek_expansionCount, "of", perPlayer, "size", size);
end
------------------------------------------------------------------------------

-------------------------------------------------------------------------------
function MultilayeredFractal:GeneratePlotsByRegion()
	-- Sirian's MultilayeredFractal controlling function.
	-- You -MUST- customize this function for each script using MultilayeredFractal.
	--
	-- This implementation is specific to KEK Large Islands.
	local iW, iH = Map.GetGridSize();
	local fracFlags = {FRAC_WRAP_X = true, FRAC_POLAR = true};
	local iNumCivs = 0;
	for i = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
		local player = Players[i];
		if player:IsEverAlive() then
			iNumCivs = iNumCivs + 1;
		end
	end

	-- Get user inputs.
	local world_age = Map.GetCustomOption(1)
	if world_age == 4 then
		world_age = 1 + Map.Rand(3, "Random World Age - Lua");
	end
	local startSize = KEK_START_SIZES[KekOption(5, #KEK_START_SIZES, 3)];
	local freePerPlayer = KEK_FREE_PER_PLAYER[KekOption(6, #KEK_FREE_PER_PLAYER, 3)];
	-- Map size Compact / Brawl: fewer free large islands (there is less sea for them)
	freePerPlayer = freePerPlayer * (({1.0, 0.75, 0.5})[KekOption(12, 3, 1)] or 1.0);
	local expansionPerPlayer = KEK_EXPANSION_PER_PLAYER[KekOption(7, #KEK_EXPANSION_PER_PLAYER, 2)];
	kek_hillPercent = KEK_HILL_PERCENTS[KekOption(8, #KEK_HILL_PERCENTS, 4)];

	-- A cell system will be used to generate the large islands (the game's: cells of 5 x 4 tiles).
	local iCellWidth = 5;
	local iCellHeight = 4;
	local iNumCellColumns = math.floor(iW / iCellWidth);
	local iNumCellRows = math.floor(iH / iCellHeight);
	local iNumTotalCells = iNumCellColumns * iNumCellRows;
	local cell_data = {};
	local iNumCellTarget = math.floor(iNumTotalCells * 0.7);

	-- KEK: one start island per player first, spread out; then the free ones.
	local iNumCellsInUse = self:KekPlaceStartIslands(iNumCivs, cell_data, iNumCellColumns, iNumCellRows, iCellWidth, iCellHeight);
	local iNumFree = math.floor(iNumCivs * (1 + freePerPlayer)) - iNumCivs;
	local iNumFreePlaced = self:KekPlaceFreeIslands(iNumFree, cell_data, iNumCellColumns, iNumCellRows, iCellWidth, iCellHeight, iNumCellsInUse, iNumCellTarget);
	print("-"); print("- KEK Large Islands: start islands", #kek_startIslands, "for", iNumCivs, "players; free large islands", iNumFreePlaced, "of", iNumFree); print("-");

	-- Large islands are set. Now apply hills and mountains.
	local args = {
		extra_mountains = 10,
		adjust_plates = 2,
		tectonic_islands = true,
		world_age = world_age,
	};
	self:ApplyTectonics(args)

	-- KEK: every start island gets the same land, hills and mountains.
	local adj = KekBuildAdjacency();
	KekShapeStartIslands(self.wholeworldPlotTypes, adj, startSize);
	-- KEK: expansion islands off each start island's coast, the same for everybody.
	KekPlaceExpansionIslands(self.wholeworldPlotTypes, adj, expansionPerPlayer, KEK_EXPANSION_SIZE);

	-- Now we begin to add the island chains.
	print("-"); print("- Large Islands placed. Begin placement of tiny island chains."); print("-");

	-- A cell system will be used to combine predefined land chunks with randomly generated island groups.
	-- Define the cell traits. (These need to fit correctly with the map grid width and height.)
	local iW, iH = Map.GetGridSize();
	local iCellWidth = 10;
	local iCellHeight = 8;
	local iNumCellColumns = math.floor(iW / iCellWidth);
	local iNumCellRows = math.floor(iH / iCellHeight);
	local iNumTotalCells = iNumCellColumns * iNumCellRows;
	local cell_data = table.fill(false, iNumTotalCells) -- Stores data on map cells in use. All cells begin as empty.
	local iNumCellsInUse = 0;
	local iNumCellTarget = math.floor(iNumTotalCells * 0.7);
	local island_chain_PlotTypes = table.fill(PlotTypes.PLOT_OCEAN, iW * iH);

	-- Add randomly generated island groups
	local iNumGroups = iNumCellTarget; -- Should virtually never use all the groups.
	for group = 1, iNumGroups do
		if iNumCellsInUse >= iNumCellTarget then -- Map has reeached desired island population.
			--print("-"); print("** Number of Island Groups produced:", group - 1); print("-");
			break
		end
		--[[ Formation Chart
		1. Single Cell, Axis Only
		2. Double Cell, Horizontal, Axis Only
		3. Single Cell With Dots
		4. Double Cell, Horizontal, With Shifted Dots
		5. Double Cell, Vertical, Axis Only
		6. Double Cell, Vertical, With Shifted Dots
		7. Triple Cell, Vertical, With Double Dots
		8. Square of Cells 2x2 With Double Dots
		9. Rectangle 3x2 With Double Dots
		10. Rectangle 2x3 With Double Dots ]]--
		--
		-- Choose a formation
		local rate_threshold = {};
		local total_appearance_rate, iNumFormations = 0, 0;
		local appearance_rates = { -- These numbers are relative to one another. No specific target total is necessary.
			7, -- #1
			3, -- #2
			15, --#3
			8, -- #4
			3, -- #5
			6, -- #6
			4, -- #7
			6, -- #8
			4, -- #9
			3, -- #10
		};
		for i, rate in ipairs(appearance_rates) do
			total_appearance_rate = total_appearance_rate + rate;
			iNumFormations = iNumFormations + 1;
		end
		local accumulated_rate = 0;
		for index = 1, iNumFormations do
			local threshold = (appearance_rates[index] + accumulated_rate) * 10000 / total_appearance_rate;
			table.insert(rate_threshold, threshold);
			accumulated_rate = accumulated_rate + appearance_rates[index];
		end
		local formation_type;
		local diceroll = Map.Rand(10000, "Choose formation type - Island Making - Lua");
		for index, threshold in ipairs(rate_threshold) do
			if diceroll <= threshold then -- Choose this formation type.
				formation_type = index;
				break
			end
		end
		-- Choose cell(s) not in use;
		local iNumAttemptsToFindOpenCells = 0;
		local found_unoccupied_cell = false;
		local anchor_cell, cell_x, cell_y, foo;
		while found_unoccupied_cell == false do
			if iNumAttemptsToFindOpenCells > 100 then -- Too many attempts on this pass. Might not be any valid locations for this formation.
				--print("-"); print("*-* ALERT! Formation type of", formation_type, "for island group#", group, "unable to find an open space. Switching to single-cell.");
				formation_type = 3; -- Reset formation type.
				iNumAttemptsToFindOpenCells = 0;
			end
			local diceroll = 1 + Map.Rand(iNumTotalCells, "Choosing a cell for an island group - Polynesia LUA");
			if cell_data[diceroll] == false then -- Anchor cell is unoccupied.
				-- If formation type is multiple-cell, all secondary cells must also be unoccupied.
				if formation_type == 1 or formation_type == 3 then -- single cell, proceed.
					anchor_cell = diceroll;
					found_unoccupied_cell = true;
				elseif formation_type == 2 or formation_type == 4 then -- double cell, horizontal.
					-- Check to see if anchor cell is in the final column. If so, reject.
					cell_x = math.fmod(diceroll, iNumCellColumns);
					if cell_x ~= 0 then -- Anchor cell is valid, but still have to check adjacent cell.
						if cell_data[diceroll + 1] == false then -- Adjacent cell is unoccupied.
							anchor_cell = diceroll;
							found_unoccupied_cell = true;
						end
					end
				elseif formation_type == 5 or formation_type == 6 then -- double cell, vertical.
					-- Check to see if anchor cell is in the final row. If so, reject.
					cell_y, foo = math.modf(diceroll / iNumCellColumns);
					cell_y = cell_y + 1;
					if cell_y < iNumCellRows then -- Anchor cell is valid, but still have to check cell above it.
						if cell_data[diceroll + iNumCellColumns] == false then -- Adjacent cell is unoccupied.
							anchor_cell = diceroll;
							found_unoccupied_cell = true;
						end
					end
				elseif formation_type == 7 then -- triple cell, vertical.
					-- Check to see if anchor cell is in the northern two rows. If so, reject.
					cell_y, foo = math.modf(diceroll / iNumCellColumns);
					cell_y = cell_y + 1;
					if cell_y < iNumCellRows - 1 then -- Anchor cell is valid, but still have to check cells above it.
						if cell_data[diceroll + iNumCellColumns] == false then -- Cell directly above is unoccupied.
							if cell_data[diceroll + (iNumCellColumns * 2)] == false then -- Cell two rows above is unoccupied.
								anchor_cell = diceroll;
								found_unoccupied_cell = true;
							end
						end
					end
				elseif formation_type == 8 then -- square, 2x2.
					-- Check to see if anchor cell is in the final row or column. If so, reject.
					cell_x = math.fmod(diceroll, iNumCellColumns);
					if cell_x ~= 0 then
						cell_y, foo = math.modf(diceroll / iNumCellColumns);
						cell_y = cell_y + 1;
						if cell_y < iNumCellRows then -- Anchor cell is valid. Still have to check the other three cells.
							if cell_data[diceroll + iNumCellColumns] == false then
								if cell_data[diceroll + 1] == false then
									if cell_data[diceroll + iNumCellColumns + 1] == false then -- All cells are open.
										anchor_cell = diceroll;
										found_unoccupied_cell = true;
									end
								end
							end
						end
					end
				elseif formation_type == 9 then -- horizontal, 3x2.
					-- Check to see if anchor cell is too near to an edge. If so, reject.
					cell_x = math.fmod(diceroll, iNumCellColumns);
					if cell_x ~= 0 and cell_x ~= iNumCellColumns - 1 then
						cell_y, foo = math.modf(diceroll / iNumCellColumns);
						cell_y = cell_y + 1;
						if cell_y < iNumCellRows then -- Anchor cell is valid. Still have to check the other cells.
							if cell_data[diceroll + iNumCellColumns] == false then
								if cell_data[diceroll + 1] == false and cell_data[diceroll + 2] == false then
									if cell_data[diceroll + iNumCellColumns + 1] == false then
										if cell_data[diceroll + iNumCellColumns + 2] == false then -- All cells are open.
											anchor_cell = diceroll;
											found_unoccupied_cell = true;
										end
									end
								end
							end
						end
					end
				elseif formation_type == 10 then -- vertical, 2x3.
					-- Check to see if anchor cell is too near to an edge. If so, reject.
					cell_x = math.fmod(diceroll, iNumCellColumns);
					if cell_x ~= 0 then
						cell_y, foo = math.modf(diceroll / iNumCellColumns);
						cell_y = cell_y + 1;
						if cell_y < iNumCellRows - 1 then -- Anchor cell is valid. Still have to check the other cells.
							if cell_data[diceroll + iNumCellColumns] == false then
								if cell_data[diceroll + 1] == false then
									if cell_data[diceroll + iNumCellColumns + 1] == false then
										if cell_data[diceroll + (iNumCellColumns * 2)] == false then
											if cell_data[diceroll + (iNumCellColumns * 2) + 1] == false then -- All cells are open.
												anchor_cell = diceroll;
												found_unoccupied_cell = true;
											end
										end
									end
								end
							end
						end
					end
				end
			end
			iNumAttemptsToFindOpenCells = iNumAttemptsToFindOpenCells + 1;
		end
		-- Find Cell X and Y
		cell_x = math.fmod(anchor_cell, iNumCellColumns);
		if cell_x == 0 then
			cell_x = iNumCellColumns;
		end
		cell_y, foo = math.modf(anchor_cell / iNumCellColumns);
		cell_y = cell_y + 1;
		
		-- Debug
		--print("-"); print("-"); print("* Group# " .. group, "Formation Type: " .. formation_type, "Cell X, Y: " .. cell_x .. ", " .. cell_y);

		-- Create this island group.
		local iWidth, iHeight, fTilt; -- Scope the variables needed for island group creation.
		local plot_data = {};
		local x_shift, y_shift;
		if formation_type == 1 then -- single cell
			local x_shrinkage = Map.Rand(4, "Cell Width adjustment - Lua");
			if x_shrinkage > 2 then
				x_shrinkage = 0;
			end
			local y_shrinkage = Map.Rand(5, "Cell Height adjustment - Lua");
			if y_shrinkage > 2 then
				y_shrinkage = 0;
			end
			x_shift, y_shift = 0, 0;
			if x_shrinkage > 0 then
				x_shift = Map.Rand(x_shrinkage, "Cell Width offset - Lua");
			end
			if y_shrinkage > 0 then
				y_shift = Map.Rand(y_shrinkage, "Cell Height offset - Lua");
			end
			iWidth = iCellWidth - x_shrinkage;
			iHeight = iCellHeight - y_shrinkage;
			fTilt = Map.Rand(181, "Angle for island chain axis - LUA");
			plot_data = CreateSingleAxisIslandChain(iWidth, iHeight, fTilt)

		elseif formation_type == 2 then -- two cells, horizontal
			local x_shrinkage = Map.Rand(8, "Cell Width adjustment - Lua");
			if x_shrinkage > 5 then
				x_shrinkage = 0;
			end
			local y_shrinkage = Map.Rand(5, "Cell Height adjustment - Lua");
			if y_shrinkage > 2 then
				y_shrinkage = 0;
			end
			x_shift, y_shift = 0, 0;
			if x_shrinkage > 0 then
				x_shift = Map.Rand(x_shrinkage, "Cell Width offset - Lua");
			end
			if y_shrinkage > 0 then
				y_shift = Map.Rand(y_shrinkage, "Cell Height offset - Lua");
			end
			iWidth = iCellWidth * 2 - x_shrinkage;
			iHeight = iCellHeight - y_shrinkage;
			-- Limit angles to mostly horizontal ones.
			fTilt = 145 + Map.Rand(90, "Angle for island chain axis - LUA");
			if fTilt > 180 then
				fTilt = fTilt - 180;
			end
			plot_data = CreateSingleAxisIslandChain(iWidth, iHeight, fTilt)
			
		elseif formation_type == 3 then -- single cell, with dots
			local x_shrinkage = Map.Rand(4, "Cell Width adjustment - Lua");
			if x_shrinkage > 2 then
				x_shrinkage = 0;
			end
			local y_shrinkage = Map.Rand(5, "Cell Height adjustment - Lua");
			if y_shrinkage > 2 then
				y_shrinkage = 0;
			end
			x_shift, y_shift = 0, 0;
			if x_shrinkage > 0 then
				x_shift = Map.Rand(x_shrinkage, "Cell Width offset - Lua");
			end
			if y_shrinkage > 0 then
				y_shift = Map.Rand(y_shrinkage, "Cell Height offset - Lua");
			end
			iWidth = iCellWidth - x_shrinkage;
			iHeight = iCellHeight - y_shrinkage;
			fTilt = Map.Rand(181, "Angle for island chain axis - LUA");
			-- Determine "dot box"
			local iInnerWidth, iInnerHeight = iWidth - 2, iHeight - 2;
			-- Determine number of dots
			local die_1 = Map.Rand(4, "Diceroll - Lua");
			local die_2 = Map.Rand(8, "Diceroll - Lua");
			local iNumDots = 4;
			if die_1 + die_2 > 1 then
				iNumDots = iNumDots + Map.Rand(die_1 + die_2, "Number of dots to add to island chain - Lua");
			else
				iNumDots = iNumDots + die_1 + die_2;
			end
			plot_data = CreateAxisChainWithDots(iWidth, iHeight, fTilt, iInnerWidth, iInnerHeight, iNumDots)

		elseif formation_type == 4 then -- two cells, horizontal, with dots
			local x_shrinkage = Map.Rand(8, "Cell Width adjustment - Lua");
			if x_shrinkage > 5 then
				x_shrinkage = 0;
			end
			local y_shrinkage = Map.Rand(5, "Cell Height adjustment - Lua");
			if y_shrinkage > 2 then
				y_shrinkage = 0;
			end
			x_shift, y_shift = 0, 0;
			if x_shrinkage > 0 then
				x_shift = Map.Rand(x_shrinkage, "Cell Width offset - Lua");
			end
			if y_shrinkage > 0 then
				y_shift = Map.Rand(y_shrinkage, "Cell Height offset - Lua");
			end
			iWidth = iCellWidth * 2 - x_shrinkage;
			iHeight = iCellHeight - y_shrinkage;
			-- Limit angles to mostly horizontal ones.
			fTilt = 145 + Map.Rand(90, "Angle for island chain axis - LUA");
			if fTilt > 180 then
				fTilt = fTilt - 180;
			end
			-- Determine "dot box"
			local iInnerWidth = math.floor(iWidth / 2);
			local iInnerHeight = iHeight - 2;
			local iInnerWest = 2 + Map.Rand((iWidth - 1) - iInnerWidth, "Shift for sub island group - Lua");
			local iInnerSouth = 2;
			-- Determine number of dots
			local die_1 = Map.Rand(4, "Diceroll - Lua");
			local die_2 = Map.Rand(10, "Diceroll - Lua");
			local iNumDots = 5;
			if die_1 + die_2 > 1 then
				iNumDots = iNumDots + Map.Rand(die_1 + die_2, "Number of dots to add to island chain - Lua");
			else
				iNumDots = iNumDots + die_1 + die_2;
			end
			plot_data = CreateAxisChainWithShiftedDots(iWidth, iHeight, fTilt, iInnerWidth, iInnerHeight, iInnerWest, iInnerSouth, iNumDots)
			
		elseif formation_type == 5 then -- Double Cell, Vertical, Axis Only
			local x_shrinkage = Map.Rand(5, "Cell Width adjustment - Lua");
			if x_shrinkage > 2 then
				x_shrinkage = 0;
			end
			local y_shrinkage = Map.Rand(7, "Cell Height adjustment - Lua");
			if y_shrinkage > 4 then
				y_shrinkage = 0;
			end
			x_shift, y_shift = 0, 0;
			if x_shrinkage > 0 then
				x_shift = Map.Rand(x_shrinkage, "Cell Width offset - Lua");
			end
			if y_shrinkage > 0 then
				y_shift = Map.Rand(y_shrinkage, "Cell Height offset - Lua");
			end
			iWidth = iCellWidth - x_shrinkage;
			iHeight = iCellHeight * 2 - y_shrinkage;
			-- Limit angles to mostly vertical ones.
			fTilt = 55 + Map.Rand(71, "Angle for island chain axis - LUA");
			plot_data = CreateSingleAxisIslandChain(iWidth, iHeight, fTilt)
		
		elseif formation_type == 6 then -- Double Cell, Vertical With Dots
			local x_shrinkage = Map.Rand(5, "Cell Width adjustment - Lua");
			if x_shrinkage > 2 then
				x_shrinkage = 0;
			end
			local y_shrinkage = Map.Rand(7, "Cell Height adjustment - Lua");
			if y_shrinkage > 4 then
				y_shrinkage = 0;
			end
			x_shift, y_shift = 0, 0;
			if x_shrinkage > 0 then
				x_shift = Map.Rand(x_shrinkage, "Cell Width offset - Lua");
			end
			if y_shrinkage > 0 then
				y_shift = Map.Rand(y_shrinkage, "Cell Height offset - Lua");
			end
			iWidth = iCellWidth - x_shrinkage;
			iHeight = iCellHeight * 2 - y_shrinkage;
			-- Limit angles to mostly vertical ones.
			fTilt = 55 + Map.Rand(71, "Angle for island chain axis - LUA");
			-- Determine "dot box"
			local iInnerWidth = iWidth - 2;
			local iInnerHeight = math.floor(iHeight / 2);
			local iInnerWest = 2;
			local iInnerSouth = 2 + Map.Rand((iHeight - 1) - iInnerHeight, "Shift for sub island group - Lua");
			-- Determine number of dots
			local die_1 = Map.Rand(4, "Diceroll - Lua");
			local die_2 = Map.Rand(10, "Diceroll - Lua");
			local iNumDots = 5;
			if die_1 + die_2 > 1 then
				iNumDots = iNumDots + Map.Rand(die_1 + die_2, "Number of dots to add to island chain - Lua");
			else
				iNumDots = iNumDots + die_1 + die_2;
			end
			plot_data = CreateAxisChainWithShiftedDots(iWidth, iHeight, fTilt, iInnerWidth, iInnerHeight, iInnerWest, iInnerSouth, iNumDots)
		
		elseif formation_type == 7 then -- Triple Cell, Vertical With Double Dots
			local x_shrinkage = Map.Rand(4, "Cell Width adjustment - Lua");
			if x_shrinkage > 1 then
				x_shrinkage = 0;
			end
			local y_shrinkage = Map.Rand(9, "Cell Height adjustment - Lua");
			if y_shrinkage > 5 then
				y_shrinkage = 0;
			end
			x_shift, y_shift = 0, 0;
			if x_shrinkage > 0 then
				x_shift = Map.Rand(x_shrinkage, "Cell Width offset - Lua");
			end
			if y_shrinkage > 0 then
				y_shift = Map.Rand(y_shrinkage, "Cell Height offset - Lua");
			end
			iWidth = iCellWidth - x_shrinkage;
			iHeight = iCellHeight * 3 - y_shrinkage;
			-- Limit angles to steep ones.
			fTilt = 70 + Map.Rand(41, "Angle for island chain axis - LUA");
			-- Handle Dots Group 1.
			local iInnerWidth1 = iWidth - 3;
			local iInnerHeight1 = iCellHeight - 1;
			local iInnerWest1 = 2 + Map.Rand(2, "Shift for sub island group - Lua");
			local iInnerSouth1 = 2 + Map.Rand(iCellHeight - 3, "Shift for sub island group - Lua");
			-- Determine number of dots
			local die_1 = Map.Rand(4, "Diceroll - Lua");
			local die_2 = Map.Rand(8, "Diceroll - Lua");
			local iNumDots1 = 4;
			if die_1 + die_2 > 1 then
				iNumDots1 = iNumDots1 + Map.Rand(die_1 + die_2, "Number of dots to add to island chain - Lua");
			else
				iNumDots1 = iNumDots1 + die_1 + die_2;
			end
			-- Handle Dots Group 2.
			local iInnerWidth2 = iWidth - 3;
			local iInnerHeight2 = iCellHeight - 1;
			local iInnerWest2 = 2 + Map.Rand(2, "Shift for sub island group - Lua");
			local iInnerSouth2 = iCellHeight + 2 + Map.Rand(iCellHeight - 3, "Shift for sub island group - Lua");
			-- Determine number of dots
			local die_1 = Map.Rand(4, "Diceroll - Lua");
			local die_2 = Map.Rand(8, "Diceroll - Lua");
			local iNumDots2 = 4;
			if die_1 + die_2 > 1 then
				iNumDots2 = iNumDots2 + Map.Rand(die_1 + die_2, "Number of dots to add to island chain - Lua");
			else
				iNumDots2 = iNumDots2 + die_1 + die_2;
			end
			plot_data = CreateAxisChainWithDoubleDots(iWidth, iHeight, fTilt, iInnerWidth1, iInnerHeight1, iInnerWest1, iInnerSouth1,
                                                      iNumDots1, iInnerWidth2, iInnerHeight2, iInnerWest2, iInnerSouth2, iNumDots2)
		elseif formation_type == 8 then -- Square Block 2x2 With Double Dots
			local x_shrinkage = Map.Rand(6, "Cell Width adjustment - Lua");
			if x_shrinkage > 4 then
				x_shrinkage = 0;
			end
			local y_shrinkage = Map.Rand(5, "Cell Height adjustment - Lua");
			if y_shrinkage > 3 then
				y_shrinkage = 0;
			end
			x_shift, y_shift = 0, 0;
			if x_shrinkage > 0 then
				x_shift = Map.Rand(x_shrinkage, "Cell Width offset - Lua");
			end
			if y_shrinkage > 0 then
				y_shift = Map.Rand(y_shrinkage, "Cell Height offset - Lua");
			end
			iWidth = iCellWidth * 2 - x_shrinkage;
			iHeight = iCellHeight * 2 - y_shrinkage;
			-- Full range of angles
			fTilt = Map.Rand(181, "Angle for island chain axis - LUA");
			-- Handle Dots Group 1.
			local iInnerWidth1 = iCellWidth - 2;
			local iInnerHeight1 = iCellHeight - 2;
			local iInnerWest1 = 3 + Map.Rand(iCellWidth - 2, "Shift for sub island group - Lua");
			local iInnerSouth1 = 3 + Map.Rand(iCellHeight - 2, "Shift for sub island group - Lua");
			-- Determine number of dots
			local die_1 = Map.Rand(6, "Diceroll - Lua");
			local die_2 = Map.Rand(10, "Diceroll - Lua");
			local iNumDots1 = 5;
			if die_1 + die_2 > 1 then
				iNumDots1 = iNumDots1 + Map.Rand(die_1 + die_2, "Number of dots to add to island chain - Lua");
			else
				iNumDots1 = iNumDots1 + die_1 + die_2;
			end
			-- Handle Dots Group 2.
			local iInnerWidth2 = iCellWidth - 2;
			local iInnerHeight2 = iCellHeight - 2;
			local iInnerWest2 = 3 + Map.Rand(iCellWidth - 2, "Shift for sub island group - Lua");
			local iInnerSouth2 = 3 + Map.Rand(iCellHeight - 2, "Shift for sub island group - Lua");
			-- Determine number of dots
			local die_1 = Map.Rand(4, "Diceroll - Lua");
			local die_2 = Map.Rand(8, "Diceroll - Lua");
			local iNumDots2 = 5;
			if die_1 + die_2 > 1 then
				iNumDots2 = iNumDots2 + Map.Rand(die_1 + die_2, "Number of dots to add to island chain - Lua");
			else
				iNumDots2 = iNumDots2 + die_1 + die_2;
			end
			plot_data = CreateAxisChainWithDoubleDots(iWidth, iHeight, fTilt, iInnerWidth1, iInnerHeight1, iInnerWest1, iInnerSouth1,
                                                      iNumDots1, iInnerWidth2, iInnerHeight2, iInnerWest2, iInnerSouth2, iNumDots2)

		elseif formation_type == 9 then -- Horizontal Block 3x2 With Double Dots
			local x_shrinkage = Map.Rand(8, "Cell Width adjustment - Lua");
			if x_shrinkage > 5 then
				x_shrinkage = 0;
			end
			local y_shrinkage = Map.Rand(5, "Cell Height adjustment - Lua");
			if y_shrinkage > 3 then
				y_shrinkage = 0;
			end
			x_shift, y_shift = 0, 0;
			if x_shrinkage > 0 then
				x_shift = Map.Rand(x_shrinkage, "Cell Width offset - Lua");
			end
			if y_shrinkage > 0 then
				y_shift = Map.Rand(y_shrinkage, "Cell Height offset - Lua");
			end
			iWidth = iCellWidth * 3 - x_shrinkage;
			iHeight = iCellHeight * 2 - y_shrinkage;
			-- Limit angles to mostly horizontal ones.
			fTilt = 145 + Map.Rand(90, "Angle for island chain axis - LUA");
			if fTilt > 180 then
				fTilt = fTilt - 180;
			end
			-- Handle Dots Group 1.
			local iInnerWidth1 = iCellWidth;
			local iInnerHeight1 = iCellHeight - 2;
			local iInnerWest1 = 4 + Map.Rand(iCellWidth + 2, "Shift for sub island group - Lua");
			local iInnerSouth1 = 3 + Map.Rand(iCellHeight - 2, "Shift for sub island group - Lua");
			-- Determine number of dots
			local die_1 = Map.Rand(4, "Diceroll - Lua");
			local die_2 = Map.Rand(8, "Diceroll - Lua");
			local iNumDots1 = 9;
			if die_1 + die_2 > 1 then
				iNumDots1 = iNumDots1 + Map.Rand(die_1 + die_2, "Number of dots to add to island chain - Lua");
			else
				iNumDots1 = iNumDots1 + die_1 + die_2;
			end
			-- Handle Dots Group 2.
			local iInnerWidth2 = iCellWidth;
			local iInnerHeight2 = iCellHeight - 2;
			local iInnerWest2 = 4 + Map.Rand(iCellWidth + 2, "Shift for sub island group - Lua");
			local iInnerSouth2 = 3 + Map.Rand(iCellHeight - 2, "Shift for sub island group - Lua");
			-- Determine number of dots
			local die_1 = Map.Rand(5, "Diceroll - Lua");
			local die_2 = Map.Rand(7, "Diceroll - Lua");
			local iNumDots2 = 8;
			if die_1 + die_2 > 1 then
				iNumDots2 = iNumDots2 + Map.Rand(die_1 + die_2, "Number of dots to add to island chain - Lua");
			else
				iNumDots2 = iNumDots2 + die_1 + die_2;
			end
			plot_data = CreateAxisChainWithDoubleDots(iWidth, iHeight, fTilt, iInnerWidth1, iInnerHeight1, iInnerWest1, iInnerSouth1,
                                                      iNumDots1, iInnerWidth2, iInnerHeight2, iInnerWest2, iInnerSouth2, iNumDots2)

		elseif formation_type == 10 then -- Vertical Block 2x3 With Double Dots
			local x_shrinkage = Map.Rand(6, "Cell Width adjustment - Lua");
			if x_shrinkage > 4 then
				x_shrinkage = 0;
			end
			local y_shrinkage = Map.Rand(8, "Cell Height adjustment - Lua");
			if y_shrinkage > 5 then
				y_shrinkage = 0;
			end
			x_shift, y_shift = 0, 0;
			if x_shrinkage > 0 then
				x_shift = Map.Rand(x_shrinkage, "Cell Width offset - Lua");
			end
			if y_shrinkage > 0 then
				y_shift = Map.Rand(y_shrinkage, "Cell Height offset - Lua");
			end
			iWidth = iCellWidth * 2 - x_shrinkage;
			iHeight = iCellHeight * 3 - y_shrinkage;
			-- Mostly vertical
			fTilt = 55 + Map.Rand(71, "Angle for island chain axis - LUA");
			-- Handle Dots Group 1.
			local iInnerWidth1 = iCellWidth - 2;
			local iInnerHeight1 = iCellHeight;
			local iInnerWest1 = 3 + Map.Rand(iCellWidth - 2, "Shift for sub island group - Lua");
			local iInnerSouth1 = 4 + Map.Rand(iCellHeight + 2, "Shift for sub island group - Lua");
			-- Determine number of dots
			local die_1 = Map.Rand(4, "Diceroll - Lua");
			local die_2 = Map.Rand(10, "Diceroll - Lua");
			local iNumDots1 = 8;
			if die_1 + die_2 > 1 then
				iNumDots1 = iNumDots1 + Map.Rand(die_1 + die_2, "Number of dots to add to island chain - Lua");
			else
				iNumDots1 = iNumDots1 + die_1 + die_2;
			end
			-- Handle Dots Group 2.
			local iInnerWidth2 = iCellWidth - 2;
			local iInnerHeight2 = iCellHeight;
			local iInnerWest2 = 3 + Map.Rand(iCellWidth - 2, "Shift for sub island group - Lua");
			local iInnerSouth2 = 4 + Map.Rand(iCellHeight + 2, "Shift for sub island group - Lua");
			-- Determine number of dots
			local die_1 = Map.Rand(4, "Diceroll - Lua");
			local die_2 = Map.Rand(8, "Diceroll - Lua");
			local iNumDots2 = 7;
			if die_1 + die_2 > 1 then
				iNumDots2 = iNumDots2 + Map.Rand(die_1 + die_2, "Number of dots to add to island chain - Lua");
			else
				iNumDots2 = iNumDots2 + die_1 + die_2;
			end
			plot_data = CreateAxisChainWithDoubleDots(iWidth, iHeight, fTilt, iInnerWidth1, iInnerHeight1, iInnerWest1, iInnerSouth1,
                                                      iNumDots1, iInnerWidth2, iInnerHeight2, iInnerWest2, iInnerSouth2, iNumDots2)
		end

		-- Obtain land plots from the plot data
		local x_adjust = (cell_x - 1) * iCellWidth + x_shift;
		local y_adjust = (cell_y - 1) * iCellHeight + y_shift;
		for y = 1, iHeight do
			for x = 1, iWidth do
				local data_index = (y - 1) * iWidth + x;
				if plot_data[data_index] == true then -- This plot is land.
					local real_x, real_y = x + x_adjust - 1, y + y_adjust - 1;
					local plot_index = real_y * iW + real_x + 1;
					island_chain_PlotTypes[plot_index] = PlotTypes.PLOT_LAND;
				end
			end
		end
		
		-- Record cells in use
		if formation_type == 1 then -- single cell
			cell_data[anchor_cell] = true;
			iNumCellsInUse = iNumCellsInUse + 1;
		elseif formation_type == 2 then
			cell_data[anchor_cell], cell_data[anchor_cell + 1] = true, true;
			iNumCellsInUse = iNumCellsInUse + 2;
		elseif formation_type == 3 then
			cell_data[anchor_cell] = true;
			iNumCellsInUse = iNumCellsInUse + 1;
		elseif formation_type == 4 then
			cell_data[anchor_cell], cell_data[anchor_cell + 1] = true, true;
			iNumCellsInUse = iNumCellsInUse + 2;
		elseif formation_type == 5 then
			cell_data[anchor_cell], cell_data[anchor_cell + iNumCellColumns] = true, true;
			iNumCellsInUse = iNumCellsInUse + 2;
		elseif formation_type == 6 then
			cell_data[anchor_cell], cell_data[anchor_cell + iNumCellColumns] = true, true;
			iNumCellsInUse = iNumCellsInUse + 2;
		elseif formation_type == 7 then
			cell_data[anchor_cell], cell_data[anchor_cell + iNumCellColumns] = true, true;
			cell_data[anchor_cell + (iNumCellColumns * 2)] = true;
			iNumCellsInUse = iNumCellsInUse + 3;
		elseif formation_type == 8 then
			cell_data[anchor_cell], cell_data[anchor_cell + 1] = true, true;
			cell_data[anchor_cell + iNumCellColumns], cell_data[anchor_cell + iNumCellColumns + 1] = true, true;
			iNumCellsInUse = iNumCellsInUse + 4;
		elseif formation_type == 9 then
			cell_data[anchor_cell], cell_data[anchor_cell + 1] = true, true;
			cell_data[anchor_cell + iNumCellColumns], cell_data[anchor_cell + iNumCellColumns + 1] = true, true;
			cell_data[anchor_cell + 2], cell_data[anchor_cell + iNumCellColumns + 2] = true, true;
			iNumCellsInUse = iNumCellsInUse + 6;
		elseif formation_type == 10 then
			cell_data[anchor_cell], cell_data[anchor_cell + 1] = true, true;
			cell_data[anchor_cell + iNumCellColumns], cell_data[anchor_cell + iNumCellColumns + 1] = true, true;
			cell_data[anchor_cell + (iNumCellColumns * 2)], cell_data[anchor_cell + (iNumCellColumns * 2) + 1] = true, true;
			iNumCellsInUse = iNumCellsInUse + 6;
		end
	end
	
	--[[ Debug check of cell occupation.
	print("- - -");
	for loop = iNumCellRows, 1, -1 do
		local c = (loop - 1) * iNumCellColumns;
		local stringdata = {};
		for innerloop = 1, iNumCellColumns do
			if cell_data[c + innerloop] == false then
				stringdata[innerloop] = "false ";
			else
				stringdata[innerloop] = "true  ";
			end
		end
		print("Row: ", table.concat(stringdata));
	end
	]]--
	
	-- Add Hills and Peaks to randomly generated islands.
	local regionHillsFrac = Fractal.Create(iW, iH, 5, {}, 7, 7);
	local regionPeaksFrac = Fractal.Create(iW, iH, 6, {}, 7, 7);
	local iHillsBottom1 = regionHillsFrac:GetHeight(20);
	local iHillsTop1 = regionHillsFrac:GetHeight(35);
	local iHillsBottom2 = regionHillsFrac:GetHeight(65);
	local iHillsTop2 = regionHillsFrac:GetHeight(80);
	local iPeakThreshold = regionPeaksFrac:GetHeight(80);
	for x = 0, iW - 1 do
		for y = 0, iH - 1 do
			local i = y * iW + x + 1;
			if island_chain_PlotTypes[i] ~= PlotTypes.PLOT_OCEAN then
				local hillVal = regionHillsFrac:GetHeight(x,y);
				if ((hillVal >= iHillsBottom1 and hillVal <= iHillsTop1) or (hillVal >= iHillsBottom2 and hillVal <= iHillsTop2)) then
					local peakVal = regionPeaksFrac:GetHeight(x,y);
					if (peakVal >= iPeakThreshold) then
						island_chain_PlotTypes[i] = PlotTypes.PLOT_MOUNTAIN
					else
						island_chain_PlotTypes[i] = PlotTypes.PLOT_HILLS
					end
				end
			end
		end
	end
	
	-- KEK: mostly large islands (user, 11-14): only KEK_CHAIN_KEEP_PERCENT of the small
	-- island pieces stay ("a couple here and there"); the rest is ocean again.
	do
		local pieceOf, kept, nPieces, nKept = {}, {}, 0, 0;
		for start = 1, iW * iH do
			if island_chain_PlotTypes[start] ~= PlotTypes.PLOT_OCEAN and pieceOf[start] == nil then
				nPieces = nPieces + 1;
				pieceOf[start] = nPieces;
				local stack = {start};
				while #stack > 0 do
					local t = table.remove(stack);
					for _, j in ipairs(adj[t]) do
						if j > 0 and pieceOf[j] == nil and island_chain_PlotTypes[j] ~= PlotTypes.PLOT_OCEAN then
							pieceOf[j] = nPieces;
							table.insert(stack, j);
						end
					end
				end
				kept[nPieces] = Map.Rand(100, "KEK Large Islands - keep small island") < KEK_CHAIN_KEEP_PERCENT;
				if kept[nPieces] then nKept = nKept + 1 end
			end
		end
		for i = 1, iW * iH do
			if pieceOf[i] ~= nil and not kept[pieceOf[i]] then
				island_chain_PlotTypes[i] = PlotTypes.PLOT_OCEAN;
			end
		end
		print("KEK Large Islands: small island pieces kept", nKept, "of", nPieces);
	end

	-- Apply island data to the map.
	-- KEK: small islands never within 2 tiles of a start island.
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local i = y * iW + x + 1;
			if island_chain_PlotTypes[i] ~= PlotTypes.PLOT_OCEAN then
				if self.wholeworldPlotTypes[i] == PlotTypes.PLOT_OCEAN and not kek_nearStart[i] then
					self.wholeworldPlotTypes[i] = island_chain_PlotTypes[i];
				end
			end
		end
	end

	-- KEK: a couple of small "treasure" islands in open water (a luxury and sea
	-- resources come later, KekTreasureIslandResources).
	local treasureOpt = KekOption(11, #KEK_TREASURE_COUNT, 4);
	local treasureCount = KEK_TREASURE_COUNT[treasureOpt];
	if treasureOpt == 4 then treasureCount = iNumCivs end
	KekPlaceTreasureIslands(self.wholeworldPlotTypes, adj, treasureCount);

	-- KEK: the rest of the land gets at least the "Hills" option's share (raised
	-- next to hills first; land that already has more keeps its hills).
	KekRaiseOtherHills(self.wholeworldPlotTypes, adj);

	-- Plot Type generation completed. Return global plot array.
	return self.wholeworldPlotTypes
end
------------------------------------------------------------------------------
function KekPlaceTreasureIslands(plots, adj, count)
	-- Islands of 3-5 tiles in open water: no other land within 2 tiles, at least
	-- 5 tiles from every start island, out of the polar rows.
	local iW, iH = Map.GetGridSize();
	local N = iW * iH;
	local OCEAN, LAND = PlotTypes.PLOT_OCEAN, PlotTypes.PLOT_LAND;
	kek_treasureTile, kek_treasureIslands = {}, {};
	if count <= 0 then return end
	local startSrc = {};
	for i = 1, N do
		if kek_startTile[i] then table.insert(startSrc, i); end
	end
	local nearStart = KekDistances(adj, startSrc, 4);
	local function Clear(t, own)
		if plots[t] ~= OCEAN or nearStart[t] ~= nil then return false end
		local y = math.floor((t - 1) / iW);
		if y < math.floor(iH * 0.15) or y > math.ceil(iH * 0.85) - 1 then return false end
		for _, j in ipairs(adj[t]) do
			if j == 0 then return false end
			if plots[j] ~= OCEAN and not own[j] then return false end
			for _, m in ipairs(adj[j]) do
				if m > 0 and plots[m] ~= OCEAN and not own[m] then return false end
			end
		end
		return true
	end
	local placed, tries = 0, 0;
	while placed < count and tries < 400 do
		tries = tries + 1;
		local seed = 1 + Map.Rand(N, "KEK Large Islands - treasure island spot");
		if Clear(seed, {}) then
			local size = 3 + Map.Rand(3, "KEK Large Islands - treasure island size");
			local own, tiles = {[seed] = true}, {seed};
			local grow = 0;
			while #tiles < size and grow < 30 do
				grow = grow + 1;
				local from = tiles[1 + Map.Rand(#tiles, "KEK Large Islands - treasure island grow")];
				local nbs = adj[from];
				local j = nbs[1 + Map.Rand(#nbs, "KEK Large Islands - treasure island grow dir")];
				if j > 0 and not own[j] and Clear(j, own) then
					own[j] = true;
					table.insert(tiles, j);
				end
			end
			if #tiles >= 3 then
				placed = placed + 1;
				kek_treasureIslands[placed] = tiles;
				for _, t in ipairs(tiles) do
					plots[t] = LAND;
					kek_treasureTile[t] = placed;
				end
			end
		end
	end
	print("KEK Large Islands: treasure islands", placed, "of", count);
end
------------------------------------------------------------------------------
function KekRaiseOtherHills(plots, adj)
	local iW, iH = Map.GetGridSize();
	local LAND, HILLS, MOUNTAIN = PlotTypes.PLOT_LAND, PlotTypes.PLOT_HILLS, PlotTypes.PLOT_MOUNTAIN;
	local land, hills, flat = 0, 0, {};
	for i = 1, iW * iH do
		if kek_startTile[i] == nil and kek_expansionTile[i] == nil then
			if plots[i] == LAND then
				land = land + 1;
				table.insert(flat, i);
			elseif plots[i] == HILLS then
				land = land + 1;
				hills = hills + 1;
			end
		end
	end
	local want = math.floor(land * kek_hillPercent / 100 + 0.5) - hills;
	if want <= 0 or #flat == 0 then return end
	-- chance per flat tile, doubled next to a hill (ranges grow instead of dots)
	local chance = math.min(1000, math.floor(want * 1000 / #flat + 0.5));
	local added = 0;
	for _, i in ipairs(flat) do
		local nextToHill = false;
		for _, j in ipairs(adj[i]) do
			if j > 0 and (plots[j] == HILLS or plots[j] == MOUNTAIN) then nextToHill = true; break end
		end
		local c = nextToHill and math.min(1000, chance * 2) or math.floor(chance / 2);
		if Map.Rand(1000, "KEK Large Islands - more hills") < c then
			plots[i] = HILLS;
			added = added + 1;
		end
	end
	print("KEK Large Islands: other land hills", hills, "+", added, "of", land, "land tiles");
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
function GeneratePlotTypes()
	print("Generating Plot Types (Lua KEK Large Islands) ...");

	local layered_world = MultilayeredFractal.Create();
	local plotsLI = layered_world:GeneratePlotsByRegion();

	SetPlotTypes(plotsLI);

	GenerateCoasts();
end
------------------------------------------------------------------------------
function GenerateTerrain()
	print("Generating Terrain (Lua KEK Large Islands) ...");

	-- Get Temperature setting input by user.
	local temp = Map.GetCustomOption(2)
	if temp == 4 then
		temp = 1 + Map.Rand(3, "Random Temperature - Lua");
	end

	local args = {temperature = temp};
	local terraingen = TerrainGenerator.Create(args);

	terrainTypes = terraingen:GenerateTerrain();

	SetTerrainTypes(terrainTypes);
end
------------------------------------------------------------------------------
function AddLakes()
	-- The game's AddLakes, but never on a start island (they all keep the same land).
	print("Map Generation - Adding Lakes (KEK Large Islands: none on start islands)");
	local iW, iH = Map.GetGridSize();
	local numLakesAdded = 0;
	local lakePlotRand = GameDefines.LAKE_PLOT_RAND;
	for i, plot in Plots() do
		if not plot:IsWater() then
			if not plot:IsCoastalLand() then
				if not plot:IsRiver() then
					local r = Map.Rand(lakePlotRand, "MapGenerator AddLakes");
					if r == 0 and kek_startTile[plot:GetY() * iW + plot:GetX() + 1] == nil and kek_expansionTile[plot:GetY() * iW + plot:GetX() + 1] == nil then
						plot:SetArea(-1);
						plot:SetPlotType(PlotTypes.PLOT_OCEAN);
						numLakesAdded = numLakesAdded + 1;
					end
				end
			end
		end
	end
	if numLakesAdded > 0 then
		print(tostring(numLakesAdded).." lakes added")
		Map.CalculateAreas();
	end
end
------------------------------------------------------------------------------
function AddFeatures()
	print("Adding Features (Lua KEK Large Islands) ...");

	-- Get Rainfall setting input by user.
	local rain = Map.GetCustomOption(3)
	if rain == 4 then
		rain = 1 + Map.Rand(3, "Random Rainfall - Lua");
	end

	local args = {rainfall = rain}
	local featuregen = FeatureGenerator.Create(args);

	-- False parameter removes mountains from coastlines.
	featuregen:AddFeatures(false);

	-- KEK: no capital blocked in by ice (user, 11-14): no ice within 3 tiles of a
	-- start island, and no snow on a start island (it becomes tundra).
	local iW, iH = Map.GetGridSize();
	local adj = KekBuildAdjacency();
	local src = {};
	for i = 1, iW * iH do
		if kek_startTile[i] then table.insert(src, i) end
	end
	local near = KekDistances(adj, src, 3);
	local ice = GameInfo.Features["FEATURE_ICE"];
	local cleared, thawed = 0, 0;
	for i, d in pairs(near) do
		local plot = Map.GetPlotByIndex(i - 1);
		if plot ~= nil then
			if ice ~= nil and plot:GetFeatureType() == ice.ID then
				plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
				cleared = cleared + 1;
			end
			if kek_startTile[i] and plot:GetTerrainType() == TerrainTypes.TERRAIN_SNOW then
				plot:SetTerrainType(TerrainTypes.TERRAIN_TUNDRA, false, true);
				thawed = thawed + 1;
			end
		end
	end
	print("KEK Large Islands: ice cleared near start islands", cleared, "snow tiles thawed", thawed);
end
------------------------------------------------------------------------------
KekBase_GenerateRegions = AssignStartingPlots.GenerateRegions;
function AssignStartingPlots:GenerateRegions(args)
	-- One start region per start island, so every player gets an own island.
	-- (The game's continental method shares players out by fertility and can
	-- put two on one island.) Falls back to the game's way only when the map
	-- had no room for an island per player.
	local args = args or {};
	self.method = 2;
	self.resource_setting = args.resources or 2;
	self.iNumCivs, self.iNumCityStates, self.player_ID_list, self.bTeamGame, self.teams_with_major_civs, self.number_civs_per_team = GetPlayerAndTeamInfo()
	self.iNumCityStatesUnassigned = self.iNumCityStates;

	local iW, iH = Map.GetGridSize();
	local areaIDs, taken = {}, {};
	local ok = (#kek_startIslands >= self.iNumCivs);
	if ok then
		for k = 1, self.iNumCivs do
			-- the area most of the island's flat land and hills belong to
			local count, bestID, bestN = {}, nil, 0;
			for y = 0, iH - 1 do
				for x = 0, iW - 1 do
					if kek_startTile[y * iW + x + 1] == k then
						local plot = Map.GetPlot(x, y);
						if not plot:IsWater() and not plot:IsMountain() then
							local a = plot:GetArea();
							count[a] = (count[a] or 0) + 1;
							if count[a] > bestN or (count[a] == bestN and a < bestID) then
								bestID, bestN = a, count[a];
							end
						end
					end
				end
			end
			if bestID == nil or taken[bestID] then
				ok = false;
				break
			end
			taken[bestID] = true;
			areaIDs[k] = bestID;
		end
	end
	if not ok then
		print("KEK Large Islands: not one island per player, using the game's continental regions");
		return KekBase_GenerateRegions(self, args);
	end

	for k = 1, self.iNumCivs do
		local landmass_data = ObtainLandmassBoundaries(areaIDs[k]);
		local iWestX = landmass_data[1];
		local iSouthY = landmass_data[2];
		local iEastX = landmass_data[3];
		local iNorthY = landmass_data[4];
		local iWidth = landmass_data[5];
		local iHeight = landmass_data[6];
		local wrapsX = landmass_data[7];
		local wrapsY = landmass_data[8];
		local fert_table, fertCount, plotCount = self:MeasureStartPlacementFertilityOfLandmass(areaIDs[k],
			iWestX, iEastX, iSouthY, iNorthY, wrapsX, wrapsY);
		local rect_table = {iWestX, iSouthY, iWidth, iHeight, areaIDs[k], fertCount, plotCount};
		self:DivideIntoRegions(1, fert_table, rect_table)
	end
	print("KEK Large Islands: one start region on each of", self.iNumCivs, "start islands");

	self:CustomOverride()
end
------------------------------------------------------------------------------
KekBase_ExaminePlotForNaturalWondersEligibility = AssignStartingPlots.ExaminePlotForNaturalWondersEligibility;
function AssignStartingPlots:ExaminePlotForNaturalWondersEligibility(x, y)
	-- No natural wonder on a start island or within 2 tiles of one: it would
	-- give one player a wonder (and take a tile) the others do not get.
	local iW, iH = Map.GetGridSize();
	if kek_nearStart[y * iW + x + 1] then
		return false
	end
	return KekBase_ExaminePlotForNaturalWondersEligibility(self, x, y);
end
------------------------------------------------------------------------------
function KekCoastalStarts(asp)
	-- mustBeCoast above falls back to an inland plot when a region has no good
	-- coastal one. Everyone starts on the coast (user): move such a start to the
	-- best coastal plot of the same island, at least 4 tiles from other starts.
	local iW, iH = Map.GetGridSize();
	for r, data in ipairs(asp.startingPlots) do
		local plot = Map.GetPlot(data[1], data[2]);
		if plot ~= nil and not plot:IsCoastalLand() then
			local area = plot:GetArea();
			local bestIndex, bestScore = -1, -99999;
			for i = 0, iW * iH - 1 do
				local p = Map.GetPlotByIndex(i);
				if p:GetArea() == area and p:IsCoastalLand() and not p:IsMountain() then
					local x, y = i % iW, math.floor(i / iW);
					local okSpacing = true;
					for r2, d2 in ipairs(asp.startingPlots) do
						if r2 ~= r and Map.PlotDistance(x, y, d2[1], d2[2]) < 4 then okSpacing = false end
					end
					if okSpacing then
						local score = asp:EvaluateCandidatePlot(i + 1, asp.regionTypes[r]) - 5 * Map.PlotDistance(x, y, data[1], data[2]);
						if score > bestScore then bestIndex, bestScore = i, score end
					end
				end
			end
			if bestIndex >= 0 then
				local x, y = bestIndex % iW, math.floor(bestIndex / iW);
				print("KEK Large Islands: start of region", r, "moved to the coast at", x, y);
				asp.startingPlots[r] = {x, y, bestScore};
				asp:PlaceImpactAndRipples(x, y);
			end
		end
	end
end
------------------------------------------------------------------------------
function StartPlotSystem()
	-- Get Resources setting input by user.
	local res = Map.GetCustomOption(4)
	if res == 6 then
		res = 1 + Map.Rand(3, "Random Resources Option - Lua");
	end

	print("Creating start plot database (MapGenerator.Lua)");
	local start_plot_database = AssignStartingPlots.Create()
	fair_startPlotDatabase = start_plot_database;

	print("Dividing the map in to Regions (Lua KEK Large Islands)");
	local args = {
		method = 2,
		resources = res,
		};
	start_plot_database:GenerateRegions(args)

	print("Choosing start locations for civilizations (Lua KEK Large Islands)");
	-- Forcing starts along the ocean.
	-- Lowering start position minimum eligibility thresholds.
	local args = {
	mustBeCoast = true,
	minFoodMiddle = 2,
	minFoodOuter = 3,
	minProdOuter = 1
	};
	start_plot_database:ChooseLocations(args)
	KekCoastalStarts(start_plot_database);

	print("Normalizing start locations and assigning them to Players (MapGenerator.Lua)");
	start_plot_database:BalanceAndAssign()

	print("Placing Natural Wonders (MapGenerator.Lua)");
	start_plot_database:PlaceNaturalWonders()

	print("Placing Resources and City States (MapGenerator.Lua)");
	start_plot_database:PlaceResourcesAndCityStates()

	-- tell the AI that we should treat this as a offshore expansion (+ naval) map
	Map.ChangeAIMapHint(4+1);

end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- KEK FAIR STARTS (the same code as KEK BitMoreFairPangea)
------------------------------------------------------------------------------
function FairWrapX()
	return Map.IsWrapX() == true;
end
------------------------------------------------------------------------------
function FairWindowIndex(x, y)
	-- Plot index of (x, y), with x wrapped round on a wrapping map; nil when off the map.
	local iW, iH = Map.GetGridSize();
	if y < 0 or y >= iH then return nil end
	if FairWrapX() then
		x = x % iW;
	elseif x < 0 or x >= iW then
		return nil
	end
	return y * iW + x;
end
------------------------------------------------------------------------------
function FairPlotsInRange(x, y, minRing, maxRing)
	-- Plot indices between minRing and maxRing tiles from (x, y), in a fixed order.
	local iW, iH = Map.GetGridSize();
	local list, seen = {}, {};
	for dy = -maxRing, maxRing do
		for dx = -maxRing - 1, maxRing + 1 do
			local j = FairWindowIndex(x + dx, y + dy);
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
-- STRATEGIC BALANCE: Horses + Iron in the capital, Coal + Aluminium nearby
------------------------------------------------------------------------------
fair_resourceRules = nil;
FAIR_CAPITAL_COAL = 7;			-- Coal at every capital
FAIR_CAPITAL_ALUMINIUM = 3;		-- Aluminium at every capital
------------------------------------------------------------------------------
function FairLoadResourceRules()
	-- Which terrain / feature / plot type each resource may sit on, read from the
	-- game database at run time (so mods that change the rules are respected).
	if fair_resourceRules ~= nil then return end
	fair_resourceRules = {};
	for row in GameInfo.Resources() do
		fair_resourceRules[row.ID] = {
			hills = (row.Hills == true or row.Hills == 1),
			flat = (row.Flatlands == true or row.Flatlands == 1),
			noRiver = (row.NoRiverSide == true or row.NoRiverSide == 1),
			terrain = {}, feature = {}, featureTerrain = {},
		};
	end
	for row in GameInfo.Resource_TerrainBooleans() do
		local res, terrain = GameInfo.Resources[row.ResourceType], GameInfo.Terrains[row.TerrainType];
		if res ~= nil and terrain ~= nil then
			fair_resourceRules[res.ID].terrain[terrain.ID] = true;
		end
	end
	for row in GameInfo.Resource_FeatureBooleans() do
		local res, feature = GameInfo.Resources[row.ResourceType], GameInfo.Features[row.FeatureType];
		if res ~= nil and feature ~= nil then
			fair_resourceRules[res.ID].feature[feature.ID] = true;
		end
	end
	for row in GameInfo.Resource_FeatureTerrainBooleans() do
		local res, terrain = GameInfo.Resources[row.ResourceType], GameInfo.Terrains[row.TerrainType];
		if res ~= nil and terrain ~= nil then
			fair_resourceRules[res.ID].featureTerrain[terrain.ID] = true;
		end
	end
end
------------------------------------------------------------------------------
function FairResourceFits(plot, resID, bRespectRiver)
	-- Same rules the game uses for "can this resource be here".
	FairLoadResourceRules();
	local rules = fair_resourceRules[resID];
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
function FairPlanResourceFix(plot, resID)
	-- How to turn this plot into a valid spot for the resource, changing as little
	-- as possible. Returns cost (nil if not possible), new plot type, new terrain,
	-- and whether the feature has to go.
	FairLoadResourceRules();
	local rules = fair_resourceRules[resID];
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
function FairPlotsInRings(x, y, minRing, maxRing)
	-- Plots between minRing and maxRing tiles from (x, y), in a fixed order.
	local list = {};
	for loop, i in ipairs(FairPlotsInRange(x, y, minRing, maxRing)) do
		table.insert(list, Map.GetPlotByIndex(i));
	end
	return list;
end
------------------------------------------------------------------------------
function FairEnsureResourceNear(asp, x, y, resID, amount, minRing, maxRing, preferMinRing)
	-- Makes sure a deposit of at least "amount" resID lies minRing..maxRing tiles from (x, y).
	-- Never stacks on another resource (luxuries stay), never on a start plot,
	-- natural wonder, oasis or flood plains.
	if resID == nil then return false end
	local plots = FairPlotsInRings(x, y, minRing, maxRing);
	-- A deposit already there counts if its tile is valid for it. (The core game's
	-- placement sometimes puts Iron in a forest; such a tile is fixed in place.)
	local best, bestInvalid = nil, nil;
	for loop, plot in ipairs(plots) do
		if plot:GetResourceType(-1) == resID then
			if FairResourceFits(plot, resID, false) then
				if best == nil or plot:GetNumResource() > best:GetNumResource() then
					best = plot;
				end
			elseif FairPlanResourceFix(plot, resID) ~= nil and not plot:IsStartingPlot() then
				if bestInvalid == nil or plot:GetNumResource() > bestInvalid:GetNumResource() then
					bestInvalid = plot;
				end
			end
		end
	end
	if best == nil and bestInvalid ~= nil then
		local cost, plotType, terrain, removeFeature = FairPlanResourceFix(bestInvalid, resID);
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
				free = true;	-- very last resort (very small land): Oil, which is not promised, makes room
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
				if FairResourceFits(plot, resID, true) then
					table.insert(fits, plot);
				else
					local cost = FairPlanResourceFix(plot, resID);
					if cost ~= nil then
						local riverBlocked = fair_resourceRules[resID].noRiver and plot:IsRiverSide();
						if riverBlocked then
							table.insert(riverOnly, plot);
						else
							table.insert(fixable, plot);
							table.insert(fixCost, cost);
							if cost < bestCost then bestCost = cost end
						end
					elseif FairResourceFits(plot, resID, false) then
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
		chosen = fits[1 + Map.Rand(table.maxn(fits), "KEK Large Islands - strategic spot")];
	elseif table.maxn(fixable) > 0 then
		local cheapest = {};
		for n, plot in ipairs(fixable) do
			if fixCost[n] == bestCost then table.insert(cheapest, plot) end
		end
		chosen = cheapest[1 + Map.Rand(table.maxn(cheapest), "KEK Large Islands - strategic spot")];
	elseif table.maxn(riverOnly) > 0 then
		chosen = riverOnly[1 + Map.Rand(table.maxn(riverOnly), "KEK Large Islands - strategic spot")];
	end
	if chosen == nil then
		print("KEK Large Islands WARNING: no room for resource", resID, "near start", x, y);
		return false
	end
	if chosen:GetResourceType(-1) ~= -1 then
		chosen:SetResourceType(-1, 0);
	end
	if not FairResourceFits(chosen, resID, false) then
		local cost, plotType, terrain, removeFeature = FairPlanResourceFix(chosen, resID);
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
function FairEnsureCapitalStrategics(asp, region_number)
	-- Horses, Iron, Coal and Aluminium all within 3 tiles of the capital.
	-- Horses and Iron are big deposits, as the core strategic balance uses;
	-- Coal 7 and Aluminium 3, placed in rings 2-3 when a valid tile is there.
	local data = asp.startingPlots[region_number];
	if data == nil then return end
	local x, y = data[1], data[2];
	local uran_amt, horse_amt, oil_amt, iron_amt, coal_amt, alum_amt = asp:GetMajorStrategicResourceQuantityValues();
	FairEnsureResourceNear(asp, x, y, asp.horse_ID, horse_amt, 1, 3);
	FairEnsureResourceNear(asp, x, y, asp.iron_ID, KEK_CAPITAL_IRON, 1, 3);
	FairEnsureResourceNear(asp, x, y, asp.coal_ID, FAIR_CAPITAL_COAL, 1, 3, 2);
	FairEnsureResourceNear(asp, x, y, asp.aluminum_ID, FAIR_CAPITAL_ALUMINIUM, 1, 3, 2);
end
------------------------------------------------------------------------------
FairBase_AddStrategicBalanceResources = AssignStartingPlots.AddStrategicBalanceResources;
function AssignStartingPlots:AddStrategicBalanceResources(region_number)
	-- The core game adds Iron, Horses and Oil here. Then Horses and Iron are
	-- checked to be really inside the capital, and Coal and Aluminium are added.
	FairBase_AddStrategicBalanceResources(self, region_number);
	FairEnsureCapitalStrategics(self, region_number);
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- KEK Large Islands ADDITIONS
------------------------------------------------------------------------------
fair_startPlotDatabase = nil;	-- GLOBAL the AssignStartingPlots instance
fair_liftLog = {};				-- GLOBAL what the start lifts did, one entry per major start

FAIR_WEAK_SHARE_PERCENT = 40;	-- weak start: this share (or more) of the land within 2 tiles is sparse
------------------------------------------------------------------------------
-- WHOLE MAP: a few more hills (mostly tundra)
------------------------------------------------------------------------------
fair_foodBonus = nil;		-- resource ID -> true: bonus resources that give food (Stone and artifacts do not)
fair_luxury = nil;			-- resource ID -> true: luxuries
fair_plantationLux = nil;	-- resource ID -> true: luxuries improved by a Plantation ("calendar" luxuries)
------------------------------------------------------------------------------
function FairLoadResourceKinds()
	if fair_foodBonus ~= nil then return end
	fair_foodBonus, fair_luxury, fair_plantationLux = {}, {}, {};
	for row in GameInfo.Resources() do
		if row.ResourceUsage == 0 and row.Type ~= "RESOURCE_STONE" and row.ResourceClassType ~= "RESOURCECLASS_RUSH" then
			fair_foodBonus[row.ID] = true;
		elseif row.ResourceUsage == 2 then
			fair_luxury[row.ID] = true;
		end
	end
	if GameInfo.Improvement_ResourceTypes ~= nil then
		for row in GameInfo.Improvement_ResourceTypes() do
			if row.ImprovementType == "IMPROVEMENT_PLANTATION" then
				local res = GameInfo.Resources[row.ResourceType];
				if res ~= nil and fair_luxury[res.ID] then
					fair_plantationLux[res.ID] = true;
				end
			end
		end
	else
		print("KEK Large Islands WARNING: no Improvement_ResourceTypes table, calendar check off");
	end
end
------------------------------------------------------------------------------
function FairIsSparse(plot)
	-- Land that feeds and builds almost nothing: flat tundra, snow, flat desert
	-- without flood plains. (A tundra or desert hill gives 2 production like any hill.)
	local terrain = plot:GetTerrainType();
	if terrain == TerrainTypes.TERRAIN_SNOW then
		return true
	end
	if plot:GetPlotType() ~= PlotTypes.PLOT_LAND then
		return false
	end
	if terrain == TerrainTypes.TERRAIN_TUNDRA then
		return true
	end
	if terrain == TerrainTypes.TERRAIN_DESERT and plot:GetFeatureType() ~= FeatureTypes.FEATURE_FLOOD_PLAINS
		and plot:GetFeatureType() ~= FeatureTypes.FEATURE_OASIS then
		return true
	end
	return false
end
------------------------------------------------------------------------------
function FairMeasureStart(x, y)
	-- Everything the lifts look at, around (x, y). Rings 1-2 / 1-3, the city tile
	-- itself does not count.
	FairLoadResourceKinds();
	local m = {land = 0, sparse = 0, hills = 0, bonus2 = 0, bonus3 = 0, lux2 = 0, plantLux2 = 0};
	for loop, plot in ipairs(FairPlotsInRings(x, y, 1, 3)) do
		local d = Map.PlotDistance(x, y, plot:GetX(), plot:GetY());
		local res = plot:GetResourceType(-1);
		if fair_foodBonus[res] then
			m.bonus3 = m.bonus3 + 1;
			if d <= 2 then m.bonus2 = m.bonus2 + 1 end
		end
		if d <= 2 then
			if not plot:IsWater() and not plot:IsMountain() then
				m.land = m.land + 1;
				if FairIsSparse(plot) then m.sparse = m.sparse + 1 end
			end
			if plot:GetPlotType() == PlotTypes.PLOT_HILLS then m.hills = m.hills + 1 end
			if fair_luxury[res] then
				m.lux2 = m.lux2 + 1;
				if fair_plantationLux[res] then m.plantLux2 = m.plantLux2 + 1 end
			end
		end
	end
	m.weak = (m.land > 0 and m.sparse * 100 >= m.land * FAIR_WEAK_SHARE_PERCENT);
	m.calendar = (m.lux2 > 0 and m.plantLux2 == m.lux2);
	return m;
end
------------------------------------------------------------------------------
function FairShuffled(list)
	-- A copy of list in a Map.Rand order (deterministic).
	local out = {};
	for n, v in ipairs(list) do out[n] = v end
	for n = table.maxn(out), 2, -1 do
		local k = 1 + Map.Rand(n, "KEK Large Islands - shuffle");
		out[n], out[k] = out[k], out[n];
	end
	return out;
end
------------------------------------------------------------------------------
function FairFreeTile(plot)
	return plot:GetResourceType(-1) == -1 and not plot:IsStartingPlot() and plot:GetImprovementType() == -1;
end
------------------------------------------------------------------------------
function FairHillRank(plot)
	-- Which flat tile to raise first: the one that loses least (desert 0/0 and
	-- tundra 1/0 before plains 1/1 before grassland 2/0). nil = not allowed.
	if plot:GetPlotType() ~= PlotTypes.PLOT_LAND or plot:IsWater() or not FairFreeTile(plot) then
		return nil
	end
	local feature = plot:GetFeatureType();
	if feature ~= FeatureTypes.NO_FEATURE and feature ~= FeatureTypes.FEATURE_FOREST
		and feature ~= FeatureTypes.FEATURE_JUNGLE then
		return nil		-- flood plains, oasis, marsh, ice, natural wonders stay
	end
	local terrain = plot:GetTerrainType();
	if terrain == TerrainTypes.TERRAIN_DESERT then return 1 end
	if terrain == TerrainTypes.TERRAIN_TUNDRA then return 1 end
	if terrain == TerrainTypes.TERRAIN_PLAINS then return 2 end
	if terrain == TerrainTypes.TERRAIN_GRASS then return 3 end
	return nil
end
------------------------------------------------------------------------------
function FairAddHill(x, y)
	-- Raises one flat tile 1-2 tiles from (x, y) to hills; keeps forest / jungle.
	local best, bestRank = {}, 99;
	for loop, plot in ipairs(FairPlotsInRings(x, y, 1, 2)) do
		local rank = FairHillRank(plot);
		if rank ~= nil then
			if rank < bestRank then
				best, bestRank = {plot}, rank;
			elseif rank == bestRank then
				table.insert(best, plot);
			end
		end
	end
	if table.maxn(best) == 0 then return false end
	local plot = best[1 + Map.Rand(table.maxn(best), "KEK Large Islands - start hill")];
	plot:SetPlotType(PlotTypes.PLOT_HILLS, false, true);
	return true
end
------------------------------------------------------------------------------
function FairAddBonus(asp, x, y, minRing, maxRing)
	-- One food bonus 1..maxRing tiles from (x, y), through the game's own
	-- AttemptToPlaceBonusResourceAtPlot (Cow / Wheat / Sheep / Deer / Banana / Fish,
	-- whatever the tile allows; no Oasis). Inner rings first.
	for ring = minRing, maxRing do
		local list = {};
		for loop, plot in ipairs(FairPlotsInRings(x, y, ring, ring)) do
			if FairFreeTile(plot) then table.insert(list, plot) end
		end
		for loop, plot in ipairs(FairShuffled(list)) do
			local placed = asp:AttemptToPlaceBonusResourceAtPlot(plot:GetX(), plot:GetY(), false);
			if placed then
				asp:PlaceResourceImpact(plot:GetX(), plot:GetY(), 3, 0);
				return true
			end
		end
	end
	return false
end
------------------------------------------------------------------------------
function FairLiftStart(asp, region_number)
	local data = asp.startingPlots[region_number];
	if data == nil then return end
	local x, y = data[1], data[2];
	local m = FairMeasureStart(x, y);
	local log = {region = region_number, x = x, y = y, weak = m.weak, land = m.land, sparse = m.sparse,
		hillsBefore = m.hills, bonusBefore = m.bonus3, calendar = m.calendar,
		snow = 0, hills = 0, bonus = 0, calendarBonus = 0};
	local hillsWanted = m.weak and 2 or 1;
	local bonusWanted = m.weak and 3 or 2;

	-- Weak start: up to 2 snow tiles within 2 tiles become tundra.
	if m.weak then
		local snow = {};
		for loop, plot in ipairs(FairPlotsInRings(x, y, 1, 2)) do
			if plot:GetTerrainType() == TerrainTypes.TERRAIN_SNOW and not plot:IsWater() and not plot:IsMountain()
				and FairFreeTile(plot) and plot:GetFeatureType() == FeatureTypes.NO_FEATURE then
				table.insert(snow, plot);
			end
		end
		for loop, plot in ipairs(FairShuffled(snow)) do
			if log.snow >= 2 then break end
			plot:SetTerrainType(TerrainTypes.TERRAIN_TUNDRA, false, true);
			log.snow = log.snow + 1;
		end
	end

	-- Hills within 2 tiles.
	local hills = m.hills;
	while hills < hillsWanted do
		if not FairAddHill(x, y) then break end
		hills = hills + 1;
		log.hills = log.hills + 1;
	end

	-- Food bonus within 3 tiles (rings 1-2 first).
	local bonus = m.bonus3;
	local bonus2 = m.bonus2;
	while bonus < bonusWanted do
		local placed = FairAddBonus(asp, x, y, 1, 2) or FairAddBonus(asp, x, y, 3, 3);
		if not placed then break end
		bonus = bonus + 1;
		log.bonus = log.bonus + 1;
	end

	-- Calendar luxuries and no food bonus within 2 tiles: one food bonus within 2.
	if m.calendar then
		bonus2 = FairMeasureStart(x, y).bonus2;
		if bonus2 == 0 and FairAddBonus(asp, x, y, 1, 2) then
			log.calendarBonus = 1;
		end
	end

	table.insert(fair_liftLog, log);
	if log.snow + log.hills + log.bonus + log.calendarBonus > 0 then
		print("KEK Large Islands: start", region_number, "at", x, y, m.weak and "(weak," or "(", m.sparse .. "/" .. m.land, "sparse)",
			"hills", m.hills, "+", log.hills, "food bonus", m.bonus3, "+", log.bonus,
			"calendar bonus +", log.calendarBonus, "snow->tundra", log.snow);
	else
		print("KEK Large Islands: start", region_number, "at", x, y, "passes, not touched");
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:PlaceResourcesAndCityStates()
	-- The core game's order of operations; then, when Strategic Balance is on,
	-- the capital strategics once more; then the start lifts, which see the
	-- final tiles.
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

	-- Strategic balance once more, now that everything else is placed.
	if self.resource_setting == 5 then
		for region_number = 1, self.iNumCivs do
			FairEnsureCapitalStrategics(self, region_number);
		end
	end

	-- Lift the weak starts (a start that passes every check is not touched).
	fair_liftLog = {};
	for region_number = 1, self.iNumCivs do
		FairLiftStart(self, region_number);
	end

	-- Necessary to implement placement of Natural Wonders, and possibly other plot-type changes.
	-- This operation must be saved for last, as it invalidates all regional data by resetting Area IDs.
	Map.RecalculateAreas();

	self:PrintFinalResourceTotalsToLog()
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- KEK LARGE ISLANDS: keep the start islands even after the start code
------------------------------------------------------------------------------
KekBase_AttemptToPlaceHillsAtPlot = AssignStartingPlots.AttemptToPlaceHillsAtPlot;
function AssignStartingPlots:AttemptToPlaceHillsAtPlot(x, y)
	-- The game's "weak capital gets a hill" also turns mountains into hills;
	-- every start island has the same lone peaks, so a peak stays a peak.
	local plot = Map.GetPlot(x, y);
	if plot ~= nil and plot:IsMountain() then
		return false
	end
	return KekBase_AttemptToPlaceHillsAtPlot(self, x, y);
end
------------------------------------------------------------------------------
KekBase_AssignCityStatesToRegionsOrToUninhabited = AssignStartingPlots.AssignCityStatesToRegionsOrToUninhabited;
function AssignStartingPlots:AssignCityStatesToRegionsOrToUninhabited(args)
	-- City states never on an expansion island or next to a start island: the
	-- game's lists of free land for them leave those tiles out.
	KekBase_AssignCityStatesToRegionsOrToUninhabited(self, args);
	for _, name in ipairs({"uninhabited_areas_coastal_plots", "uninhabited_areas_inland_plots"}) do
		local kept = {};
		for _, plotIndex in ipairs(self[name] or {}) do
			if not kek_nearStart[plotIndex] then
				table.insert(kept, plotIndex);
			end
		end
		self[name] = kept;
	end
end
------------------------------------------------------------------------------
KekBase_CanPlaceCityStateAt = AssignStartingPlots.CanPlaceCityStateAt;
function AssignStartingPlots:CanPlaceCityStateAt(x, y, area_ID, force_it, ignore_collisions)
	-- Every way the game places a city state asks here: never on an expansion
	-- island, never on small land within 2 tiles of a start island. (City states
	-- the game puts on start islands themselves stay: the same number on each.)
	local iW, iH = Map.GetGridSize();
	local i = y * iW + x + 1;
	if kek_expansionTile[i] ~= nil or kek_treasureTile[i] ~= nil or (kek_nearStart[i] and kek_startTile[i] == nil) then
		return false
	end
	return KekBase_CanPlaceCityStateAt(self, x, y, area_ID, force_it, ignore_collisions);
end
------------------------------------------------------------------------------
function KekSmallIslandFish(asp)
	-- Islands of KEK_SMALL_ISLAND_TILES tiles or less (chains, expansion islands)
	-- get about one Fish per KEK_COAST_PER_FISH coast tiles, at least one; sea
	-- resources already there count. A new Fish is never next to another sea
	-- resource and never within 3 tiles of a start island (no extra capital food).
	local fish = GameInfo.Resources["RESOURCE_FISH"];
	if fish == nil then return end
	local fishID = fish.ID;
	FairLoadResourceRules();	-- the game's rules: which water terrain Fish may sit on
	local iW, iH = Map.GetGridSize();
	local N = iW * iH;
	local adj = KekBuildAdjacency();
	local startSrc = {};
	for i = 1, N do
		if kek_startTile[i] then table.insert(startSrc, i); end
	end
	local nearStart = KekDistances(adj, startSrc, 3);
	-- small land areas, in map order
	local areaOrder, areaWater, areaSeen = {}, {}, {};
	for i = 1, N do
		local plot = Map.GetPlotByIndex(i - 1);
		if not plot:IsWater() and not plot:IsMountain() and kek_startTile[i] == nil then
			local a = plot:GetArea();
			local area = Map.GetArea(a);
			if area ~= nil and area:GetNumTiles() <= KEK_SMALL_ISLAND_TILES then
				if areaWater[a] == nil then
					areaWater[a] = {};
					areaSeen[a] = {};
					table.insert(areaOrder, a);
				end
				for _, j in ipairs(adj[i]) do
					if j > 0 and not areaSeen[a][j] then
						local w = Map.GetPlotByIndex(j - 1);
						if w:IsWater() and not w:IsLake() then
							areaSeen[a][j] = true;
							table.insert(areaWater[a], j);
						end
					end
				end
			end
		end
	end
	local function SeaResourceNextTo(j)
		for _, m in ipairs(adj[j]) do
			if m > 0 then
				local p = Map.GetPlotByIndex(m - 1);
				if p:IsWater() and p:GetResourceType(-1) ~= -1 then return true end
			end
		end
		return false
	end
	local log = {islands = 0, added = 0};
	for _, a in ipairs(areaOrder) do
		local have, free = 0, {};
		for _, j in ipairs(areaWater[a]) do
			local p = Map.GetPlotByIndex(j - 1);
			if p:GetResourceType(-1) ~= -1 then
				have = have + 1;
			elseif nearStart[j] == nil and p:GetFeatureType() == FeatureTypes.NO_FEATURE
				and fair_resourceRules[fishID].terrain[p:GetTerrainType()] == true then
				table.insert(free, j);
			end
		end
		local want = math.max(1, math.floor(#areaWater[a] / KEK_COAST_PER_FISH + 0.5));
		log.islands = log.islands + 1;
		while have < want and #free > 0 do
			local j = table.remove(free, 1 + Map.Rand(#free, "KEK Large Islands - small island fish"));
			if not SeaResourceNextTo(j) then
				Map.GetPlotByIndex(j - 1):SetResourceType(fishID, 1);
				have = have + 1;
				log.added = log.added + 1;
			end
		end
	end
	kek_fishLog = log;
	print("KEK Large Islands: small islands", log.islands, "Fish added", log.added);
end
------------------------------------------------------------------------------
function KekLandBonus(asp)
	-- "Land resources (bonus)" option, as KEK Archipelago:
	-- 1. every capital gets at least KEK_CAPITAL_BONUS land bonus within 3 tiles;
	-- 2. every start island gets the SAME number of extra bonus (the option's share
	--    of the smallest island's free land beyond the capital's 3 tiles);
	-- 3. all other land: that share by chance.
	local opt = KekOption(9, #KEK_LAND_BONUS, 4);
	local share, capitalBonus = KEK_LAND_BONUS[opt], KEK_CAPITAL_BONUS[opt];
	local iW, iH = Map.GetGridSize();
	local N = iW * iH;
	local capitals = {};
	for region = 1, asp.iNumCivs do
		local d = asp.startingPlots[region];
		if d ~= nil then table.insert(capitals, {d[1], d[2]}); end
	end
	local function CapitalDist(x, y)
		local best = 99;
		for _, c in ipairs(capitals) do best = math.min(best, Map.PlotDistance(x, y, c[1], c[2])); end
		return best;
	end
	local function IsLandBonus(plot)
		local r = plot:GetResourceType(-1);
		return r ~= -1 and GameInfo.Resources[r] ~= nil and GameInfo.Resources[r].ResourceUsage == 0;
	end
	local function Free(plot)
		return not plot:IsWater() and not plot:IsMountain() and plot:GetResourceType(-1) == -1
			and not plot:IsStartingPlot() and plot:GetImprovementType() == -1;
	end
	local log = {capital = 0, island = 0, other = 0};
	-- 1. capitals
	for _, c in ipairs(capitals) do
		local have, free = 0, {};
		for loop, plot in ipairs(FairPlotsInRings(c[1], c[2], 1, 3)) do
			if not plot:IsWater() then
				if IsLandBonus(plot) then have = have + 1; elseif Free(plot) then table.insert(free, plot); end
			end
		end
		while have < capitalBonus and #free > 0 do
			local plot = table.remove(free, 1 + Map.Rand(#free, "KEK Large Islands - capital bonus"));
			if asp:AttemptToPlaceBonusResourceAtPlot(plot:GetX(), plot:GetY(), false) then
				have = have + 1;
				log.capital = log.capital + 1;
			end
		end
	end
	-- 2. start islands: the same count each
	local lists, fewest = {}, nil;
	for k = 1, #kek_startIslands do
		lists[k] = {};
	end
	for i = 1, N do
		local k = kek_startTile[i];
		if k ~= nil and lists[k] ~= nil then
			local plot = Map.GetPlotByIndex(i - 1);
			if Free(plot) and CapitalDist(plot:GetX(), plot:GetY()) > 3 then
				table.insert(lists[k], plot);
			end
		end
	end
	for k = 1, #kek_startIslands do
		if fewest == nil or #lists[k] < fewest then fewest = #lists[k]; end
	end
	local perIsland = math.floor((fewest or 0) * share + 0.5);
	for k = 1, #kek_startIslands do
		local placed, list = 0, lists[k];
		while placed < perIsland and #list > 0 do
			local plot = table.remove(list, 1 + Map.Rand(#list, "KEK Large Islands - start island bonus"));
			if asp:AttemptToPlaceBonusResourceAtPlot(plot:GetX(), plot:GetY(), false) then
				placed = placed + 1;
				log.island = log.island + 1;
			end
		end
	end
	-- 3. other land, by chance (expansion islands included)
	for i = 1, N do
		if kek_startTile[i] == nil then
			local plot = Map.GetPlotByIndex(i - 1);
			if Free(plot) and CapitalDist(plot:GetX(), plot:GetY()) > 3
				and Map.Rand(1000, "KEK Large Islands - land bonus") < share * 1000 then
				if asp:AttemptToPlaceBonusResourceAtPlot(plot:GetX(), plot:GetY(), false) then
					log.other = log.other + 1;
				end
			end
		end
	end
	log.perIsland = perIsland;
	kek_bonusLog = log;
	print("KEK Large Islands: land bonus capitals +", log.capital, "start islands +", perIsland, "each, other +", log.other);
end
------------------------------------------------------------------------------
function KekSeaResources(asp)
	-- "Sea resources (Fish)" option:
	-- 1. every capital gets exactly KEK_SEA_CAPITAL_FISH Fish within 3 tiles
	--    (new ones within 2 tiles when there is room, so they are worked early);
	-- 2. every start island gets the SAME number of extra Fish on its coast beyond
	--    the capital's 3 tiles; 3. other big islands: Fish by chance.
	-- (Small islands: KekSmallIslandFish, with KEK_COAST_PER_FISH from the option.)
	local fish = GameInfo.Resources["RESOURCE_FISH"];
	if fish == nil then return end
	local fishID = fish.ID;
	FairLoadResourceRules();
	local opt = KekOption(10, #KEK_SEA_CAPITAL_FISH, 3);
	local capFish, bigCoast = KEK_SEA_CAPITAL_FISH[opt], KEK_SEA_BIG_COAST[opt];
	local iW, iH = Map.GetGridSize();
	local N = iW * iH;
	local adj = KekBuildAdjacency();
	local capitals = {};
	for region = 1, asp.iNumCivs do
		local d = asp.startingPlots[region];
		if d ~= nil then table.insert(capitals, {d[1], d[2]}); end
	end
	local function CapitalDist(x, y)
		local best = 99;
		for _, c in ipairs(capitals) do best = math.min(best, Map.PlotDistance(x, y, c[1], c[2])); end
		return best;
	end
	local function FreeSea(plot)
		return plot:IsWater() and not plot:IsLake() and plot:GetResourceType(-1) == -1
			and plot:GetFeatureType() == FeatureTypes.NO_FEATURE and plot:IsAdjacentToLand()
			and fair_resourceRules[fishID].terrain[plot:GetTerrainType()] == true;
	end
	local function SeaResourceNextTo(j)
		for _, m in ipairs(adj[j]) do
			if m > 0 then
				local p = Map.GetPlotByIndex(m - 1);
				if p:IsWater() and p:GetResourceType(-1) ~= -1 then return true end
			end
		end
		return false
	end
	local log = {capitalAdded = 0, capitalRemoved = 0, perIsland = 0, island = 0, other = 0};
	-- 1. capitals
	for _, c in ipairs(capitals) do
		local have, near, far = {}, {}, {};
		for loop, plot in ipairs(FairPlotsInRings(c[1], c[2], 1, 3)) do
			if plot:IsWater() then
				if plot:GetResourceType(-1) == fishID then
					table.insert(have, plot);
				elseif FreeSea(plot) then
					if Map.PlotDistance(c[1], c[2], plot:GetX(), plot:GetY()) <= 2 then table.insert(near, plot) else table.insert(far, plot) end
				end
			end
		end
		while #have > capFish do
			local plot = table.remove(have, 1 + Map.Rand(#have, "KEK Large Islands - capital fish trim"));
			plot:SetResourceType(-1, 0);
			log.capitalRemoved = log.capitalRemoved + 1;
		end
		local n = #have;
		while n < capFish and (#near > 0 or #far > 0) do
			local list = (#near > 0) and near or far;
			local plot = table.remove(list, 1 + Map.Rand(#list, "KEK Large Islands - capital fish"));
			plot:SetResourceType(fishID, 1);
			n = n + 1;
			log.capitalAdded = log.capitalAdded + 1;
		end
	end
	if bigCoast > 0 then
		-- coast of the start islands (beyond the capital) and of the other big islands
		local startCoast, otherCoast, seen = {}, {}, {};
		for k = 1, #kek_startIslands do startCoast[k] = {}; end
		for i = 1, N do
			local plot = Map.GetPlotByIndex(i - 1);
			if not plot:IsWater() then
				local area = Map.GetArea(plot:GetArea());
				local big = area ~= nil and area:GetNumTiles() > KEK_SMALL_ISLAND_TILES;
				local k = kek_startTile[i];
				if (big or k ~= nil) and kek_treasureTile[i] == nil then
					for _, j in ipairs(adj[i]) do
						if j > 0 and not seen[j] then
							local w = Map.GetPlotByIndex(j - 1);
							if FreeSea(w) and CapitalDist(w:GetX(), w:GetY()) > 3 then
								seen[j] = true;
								if k ~= nil and startCoast[k] ~= nil then table.insert(startCoast[k], j) else table.insert(otherCoast, j) end
							end
						end
					end
				end
			end
		end
		-- 2. start islands: the same count each
		local fewest = nil;
		for k = 1, #kek_startIslands do
			if fewest == nil or #startCoast[k] < fewest then fewest = #startCoast[k]; end
		end
		local perIsland = math.floor((fewest or 0) / bigCoast + 0.5);
		log.perIsland = perIsland;
		for k = 1, #kek_startIslands do
			local list, placed = startCoast[k], 0;
			while placed < perIsland and #list > 0 do
				local j = table.remove(list, 1 + Map.Rand(#list, "KEK Large Islands - start island fish"));
				if not SeaResourceNextTo(j) then
					Map.GetPlotByIndex(j - 1):SetResourceType(fishID, 1);
					placed = placed + 1;
					log.island = log.island + 1;
				end
			end
		end
		-- 3. other big islands, by chance
		for _, j in ipairs(otherCoast) do
			if Map.Rand(1000, "KEK Large Islands - big island fish") < math.floor(1000 / bigCoast)
				and not SeaResourceNextTo(j) then
				Map.GetPlotByIndex(j - 1):SetResourceType(fishID, 1);
				log.other = log.other + 1;
			end
		end
	end
	kek_seaLog = log;
	print("KEK Large Islands: sea resources capitals +", log.capitalAdded, "-", log.capitalRemoved,
		"start islands +", log.perIsland, "each, other big islands +", log.other);
end
------------------------------------------------------------------------------
function KekTreasureIslandResources(asp)
	-- Every treasure island: one land luxury on it (a sea luxury if no land
	-- luxury fits), one sea luxury and 1-2 Fish next to it.
	if #kek_treasureIslands == 0 then return end
	FairLoadResourceRules();
	local fish = GameInfo.Resources["RESOURCE_FISH"];
	local landLux, seaLux = {}, {};
	for row in GameInfo.Resources() do
		if row.ResourceClassType == "RESOURCECLASS_LUXURY" and row.OnlyMinorCivs ~= true and row.OnlyMinorCivs ~= 1 then
			local rules = fair_resourceRules[row.ID];
			local water = false;
			if rules ~= nil then
				for t, ok in pairs(rules.terrain) do
					if ok and (t == TerrainTypes.TERRAIN_COAST or t == TerrainTypes.TERRAIN_OCEAN) then water = true end
				end
			end
			if water then table.insert(seaLux, row.ID) else table.insert(landLux, row.ID) end
		end
	end
	-- prefer luxuries already on the map (the game's choice for this map)
	local onMap = {};
	local iW, iH = Map.GetGridSize();
	for i = 0, iW * iH - 1 do
		local r = Map.GetPlotByIndex(i):GetResourceType(-1);
		if r ~= -1 then onMap[r] = true end
	end
	local function Pool(list)
		local pool = {};
		for _, id in ipairs(list) do if onMap[id] then table.insert(pool, id) end end
		if #pool == 0 then pool = list end
		return pool;
	end
	local landPool, seaPool = Pool(landLux), Pool(seaLux);
	local adj = KekBuildAdjacency();
	local log = {islands = 0, landLux = 0, seaLux = 0, fish = 0};
	for n, tiles in ipairs(kek_treasureIslands) do
		log.islands = log.islands + 1;
		-- land luxury
		local done = false;
		local order = {};
		for _, t in ipairs(tiles) do table.insert(order, t) end
		for tries = 1, 12 do
			if done or #landPool == 0 then break end
			local resID = landPool[1 + Map.Rand(#landPool, "KEK Large Islands - treasure luxury")];
			for _, t in ipairs(order) do
				local plot = Map.GetPlotByIndex(t - 1);
				if plot:GetResourceType(-1) == -1 and FairResourceFits(plot, resID, false) then
					plot:SetResourceType(resID, 1);
					log.landLux = log.landLux + 1;
					done = true;
					break
				end
			end
		end
		-- free water around it
		local water, seen = {}, {};
		for _, t in ipairs(tiles) do
			for _, j in ipairs(adj[t]) do
				if j > 0 and not seen[j] then
					seen[j] = true;
					local w = Map.GetPlotByIndex(j - 1);
					if w:IsWater() and not w:IsLake() and w:GetResourceType(-1) == -1 and w:GetFeatureType() == FeatureTypes.NO_FEATURE then
						table.insert(water, w);
					end
				end
			end
		end
		local function TakeFor(resID)
			local rules = fair_resourceRules[resID];
			for tries = 1, #water do
				local k = 1 + Map.Rand(#water, "KEK Large Islands - treasure sea spot");
				local w = water[k];
				if rules ~= nil and rules.terrain[w:GetTerrainType()] == true then
					table.remove(water, k);
					w:SetResourceType(resID, 1);
					return true
				end
			end
			return false
		end
		-- sea luxury (two if no land luxury fitted)
		for m = 1, (done and 1 or 2) do
			if #seaPool > 0 and TakeFor(seaPool[1 + Map.Rand(#seaPool, "KEK Large Islands - treasure sea luxury")]) then
				log.seaLux = log.seaLux + 1;
			end
		end
		-- Fish
		if fish ~= nil then
			local want = 1 + Map.Rand(2, "KEK Large Islands - treasure fish");
			for m = 1, want do
				if TakeFor(fish.ID) then log.fish = log.fish + 1 end
			end
		end
	end
	kek_treasureLog = log;
	print("KEK Large Islands: treasure islands", log.islands, "land luxuries", log.landLux, "sea luxuries", log.seaLux, "Fish", log.fish);
end
------------------------------------------------------------------------------
KekBase_PlaceResourcesAndCityStates = AssignStartingPlots.PlaceResourcesAndCityStates;
function AssignStartingPlots:PlaceResourcesAndCityStates()
	KekBase_PlaceResourcesAndCityStates(self);
	KekLandBonus(self);
	KEK_COAST_PER_FISH = KEK_SEA_COAST_PER_FISH[KekOption(10, #KEK_SEA_COAST_PER_FISH, 3)];
	KekTreasureIslandResources(self);
	KekSeaResources(self);
	KekSmallIslandFish(self);
	-- 3-5 bonus resources at every capital, not more (user).
	KekCapitalBonusCap(self, self.iNumCivs);
	KekCapitalLuxuries(self, self.iNumCivs);
	-- No city site with more than a handful of Fish (user).
	KekFishCityCap(self, self.iNumCivs, ({3, 4, 5, 5, 6, 7})[KekOption(10, 6, 3)] or 5);
	FairCityStateBoost(self);
end
------------------------------------------------------------------------------
KekBase_FairAddHill = FairAddHill;
function FairAddHill(x, y)
	-- As KEK BitMoreFairPangea; when every flat tile within 2 tiles has a
	-- resource or flood plains (small islands, crowded coasts), an empty flood
	-- plains tile becomes a hill as the last resort (it loses the flood plains).
	if KekBase_FairAddHill(x, y) then
		return true
	end
	local list = {};
	for loop, plot in ipairs(FairPlotsInRings(x, y, 1, 2)) do
		if plot:GetPlotType() == PlotTypes.PLOT_LAND and FairFreeTile(plot)
			and plot:GetFeatureType() == FeatureTypes.FEATURE_FLOOD_PLAINS then
			table.insert(list, plot);
		end
	end
	if table.maxn(list) == 0 then return false end
	local plot = list[1 + Map.Rand(table.maxn(list), "KEK Large Islands - start hill on flood plains")];
	plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
	plot:SetPlotType(PlotTypes.PLOT_HILLS, false, true);
	return true
end
------------------------------------------------------------------------------
------------------------------------------------------------------------------
function FairCityStateBoost(asp)
	-- City states worth taking (user, 11-14): within 2 tiles every city state
	-- gets at least 3 food bonus (land bonus or Fish) and within 3 tiles at
	-- least 2 luxuries (land, or Whales/Pearls/Crab on the coast).
	if asp.cityStatePlots == nil then return end
	FairLoadResourceRules();
	local iW, iH = Map.GetGridSize();
	local fish = GameInfo.Resources["RESOURCE_FISH"];
	local landLux, seaLux, onMap = {}, {}, {};
	for i = 0, iW * iH - 1 do
		local r = Map.GetPlotByIndex(i):GetResourceType(-1);
		if r ~= -1 then onMap[r] = true end
	end
	for row in GameInfo.Resources() do
		if row.ResourceClassType == "RESOURCECLASS_LUXURY" and onMap[row.ID] then
			local rules = fair_resourceRules[row.ID];
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
			for loop, plot in ipairs(FairPlotsInRings(x, y, 1, 3)) do
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
					local p = Take(freeSea2, function(p) return fair_resourceRules[fish.ID].terrain[p:GetTerrainType()] == true end);
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
					local p = Take(freeLand3, function(p) return FairResourceFits(p, id, false) end);
					if p ~= nil then p:SetResourceType(id, 1); placed = true end
				end
				if not placed and table.maxn(seaLux) > 0 and table.maxn(freeSea3) > 0 then
					local id = seaLux[1 + Map.Rand(table.maxn(seaLux), "City state boost - sea luxury")];
					local p = Take(freeSea3, function(p) return fair_resourceRules[id].terrain[p:GetTerrainType()] == true end);
					if p ~= nil then p:SetResourceType(id, 1); placed = true end
				end
				if placed then lux = lux + 1; log.lux = log.lux + 1 end
			end
		end
	end
	print("City state boost: city states", log.cs, "food bonus +", log.food, "luxuries +", log.lux);
end
------------------------------------------------------------------------------
function KekCapitalBonusCap(asp, nRegions)
	-- Good, not crazy (user, 11-14): within 3 tiles of every capital exactly
	-- 3-5 bonus resources, Fish and land bonus together (one number per game,
	-- the same for everybody). Strategic balance and luxuries are not counted.
	-- Too many: the more common kind (sea or land) loses one first. Too few:
	-- a land bonus or a Fish is added.
	FairLoadResourceRules();
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
			for loop, plot in ipairs(FairPlotsInRings(x, y, 1, 3)) do
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
					if fair_resourceRules[fish.ID].terrain[plot:GetTerrainType()] == true then
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
		for loop2, plot in ipairs(FairPlotsInRings(site:GetX(), site:GetY(), 1, 3)) do
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
function KekCapitalLuxuries(asp, nRegions)
	-- Capitals as the user wants them (11-14): within 3 tiles exactly 2 copies
	-- of the capital's regional luxury and exactly 1 other luxury (land or sea).
	-- Missing ones are added on fitting free tiles, extras go (farthest first).
	FairLoadResourceRules();
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
			for loop, plot in ipairs(FairPlotsInRings(x, y, 1, 3)) do
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
					if FairResourceFits(plot, resID, false) then
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
