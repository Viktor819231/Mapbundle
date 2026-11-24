-- >>> CITY STATE QUALITY (shared by every KEK map; source: mirror-map/CityStateQuality.lua,
-- pasted into each script by tools/sync_csq.py - edit there, then run it) <<<
-- User 11-16: a city state has at most 1 luxury within 3 tiles (Mercantile ones
-- 2), and a "City states" map option: Poor / Normal / Rich. Runs last, on the
-- finished map. No dice: on mirror maps twins get exactly the same treatment
-- (choices are ordered by distance, then by the smaller of a plot and its twin).
CSQ_VALUES = {
	{"Poor", "City states get little: at most 1 food resource within 2 tiles. Always at most 1 luxury (Mercantile 2)."},
	{"Normal", "The map's own city states. Always at most 1 luxury within 3 tiles (Mercantile 2)."},
	{"Rich", "City states worth taking: at least 4 food resources within 2 tiles. Always at most 1 luxury (Mercantile 2)."},
};
function CSQ_OptionDef()
	return {Name = "City states", Values = CSQ_VALUES, DefaultValue = 2, SortPriority = 99};
end

function CSQ_Level()
	-- the option is always the LAST one in the map's list
	local ok, n = pcall(function() return #GetMapScriptInfo().CustomOptions end);
	if not ok or n == nil or n < 1 then return 2 end
	local v = Map.GetCustomOption(n);
	if v == nil or v < 1 or v > 3 then return 2 end
	return v;
end

function CSQ_Trait(id)
	local ok, t = pcall(function() return Players[id]:GetMinorCivTrait() end);
	if ok and t ~= nil and t >= 0 then return t end
	local ok2, t2 = pcall(function()
		local row = GameInfo.MinorCivilizations[PreGame.GetMinorCivType(id)];
		if row == nil then return -1 end
		local tr = GameInfo.MinorCivTraits[row.MinorCivTrait];
		return tr and tr.ID or -1;
	end);
	if ok2 and t2 ~= nil then return t2 end
	return -1;
end

function CSQ_Run(level, twinOf)
	-- level 1 poor / 2 normal / 3 rich; twinOf(plotIndex) -> mirror twin index or nil
	local iW, iH = Map.GetGridSize();
	local function Idx(p) return p:GetY() * iW + p:GetX() end
	local function Key(i)
		if twinOf ~= nil then
			local t = twinOf(i);
			if t ~= nil and t >= 0 and t < i then return t end
		end
		return i;
	end
	local mercantile = GameInfo.MinorCivTraits and GameInfo.MinorCivTraits["MINOR_TRAIT_MERCANTILE"];
	local mercID = mercantile and mercantile.ID or -99;
	local majors = {};
	for id = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
		local p = Players[id];
		local ok, sp = pcall(function() return p ~= nil and p:IsEverAlive() and p:GetStartingPlot() end);
		if ok and sp then table.insert(majors, sp) end
	end
	local function NearMajor(p)
		for _, m in ipairs(majors) do
			if Map.PlotDistance(m:GetX(), m:GetY(), p:GetX(), p:GetY()) <= 3 then return true end
		end
		return false;
	end
	local function Ring(x, y, r1, r2)
		local out = {};
		for dy = -r2, r2 do
			for dx = -r2 - 1, r2 + 1 do
				local p = Map.GetPlot(x + dx, y + dy);
				if p ~= nil then
					local d = Map.PlotDistance(x, y, p:GetX(), p:GetY());
					if d >= r1 and d <= r2 then table.insert(out, {p, d}) end
				end
			end
		end
		table.sort(out, function(a, b)
			if a[2] ~= b[2] then return a[2] < b[2] end
			return Key(Idx(a[1])) < Key(Idx(b[1]));
		end);
		return out;
	end
	local function Usage(r)
		if r == -1 or GameInfo.Resources[r] == nil then return nil end
		return GameInfo.Resources[r].ResourceUsage;
	end
	local function IsFood(r)
		local row = r ~= -1 and GameInfo.Resources[r] or nil;
		return row ~= nil and row.ResourceUsage == 0 and row.Type ~= "RESOURCE_STONE" and row.Type ~= "RESOURCE_MARBLE";
	end
	local function Res(t) local row = GameInfo.Resources[t]; return row and row.ID or nil end
	local function FoodFor(p)
		-- a food resource that suits the plot (no dice), or nil
		if p:IsMountain() or p:GetImprovementType() ~= -1 or p:GetResourceType(-1) ~= -1 then return nil end
		local T, F = TerrainTypes, FeatureTypes;
		local t, f = p:GetTerrainType(), p:GetFeatureType();
		if p:IsWater() then
			if not p:IsLake() and t == T.TERRAIN_COAST and f == F.NO_FEATURE then return Res("RESOURCE_FISH") end
			return nil;
		end
		if f == F.FEATURE_FOREST and (t == T.TERRAIN_TUNDRA or t == T.TERRAIN_PLAINS or t == T.TERRAIN_GRASS) then return Res("RESOURCE_DEER") end
		if f == F.FEATURE_JUNGLE then return Res("RESOURCE_BANANA") end
		if f ~= F.NO_FEATURE then return nil end
		if p:IsHills() then
			if t == T.TERRAIN_GRASS or t == T.TERRAIN_PLAINS or t == T.TERRAIN_DESERT or t == T.TERRAIN_TUNDRA then return Res("RESOURCE_SHEEP") end
			return nil;
		end
		if t == T.TERRAIN_PLAINS then return Res("RESOURCE_WHEAT") end
		if t == T.TERRAIN_GRASS then return Res("RESOURCE_COW") end
		if t == T.TERRAIN_TUNDRA then return Res("RESOURCE_DEER") end
		return nil;
	end
	local function Set(p, r, amt)
		-- on mirror maps the twin plot gets the same
		p:SetResourceType(r, amt or 0);
		if twinOf ~= nil then
			local t = twinOf(Idx(p));
			if t ~= nil and t >= 0 and t ~= Idx(p) then Map.GetPlotByIndex(t):SetResourceType(r, amt or 0) end
		end
	end
	local log = {cs = 0, luxOff = 0, foodOff = 0, foodOn = 0};
	-- the city states to treat: on mirror maps only one of each twin pair (the
	-- one with the smaller plot index); its changes are copied to the twin
	local list = {};
	for id = GameDefines.MAX_MAJOR_CIVS, GameDefines.MAX_CIV_PLAYERS - 1 do
		local pl = Players[id];
		local ok, sp = pcall(function() return pl ~= nil and pl:IsEverAlive() and pl:GetStartingPlot() end);
		if ok and sp then
			local i = Idx(sp);
			local t = twinOf and twinOf(i) or nil;
			if t == nil or t < 0 or t >= i then table.insert(list, {id, sp}) end
		end
	end
	-- pass 1: every city state's own nearest luxury (Mercantile: 2) is protected
	local protected = {};
	for _, c in ipairs(list) do
		local maxLux = (CSQ_Trait(c[1]) == mercID) and 2 or 1;
		local n = 0;
		for _, e in ipairs(Ring(c[2]:GetX(), c[2]:GetY(), 1, 3)) do
			if n < maxLux and Usage(e[1]:GetResourceType(-1)) == 2 then protected[Idx(e[1])] = true; n = n + 1 end
		end
	end
	for _, c in ipairs(list) do
		local id, sp = c[1], c[2];
		do
			log.cs = log.cs + 1;
			local x, y = sp:GetX(), sp:GetY();
			local around = Ring(x, y, 1, 3);
			-- luxuries: keep the nearest 1 (Mercantile 2), and any other city state's own one
			local maxLux = (CSQ_Trait(id) == mercID) and 2 or 1;
			local kept = 0;
			for _, e in ipairs(around) do
				local p = e[1];
				if Usage(p:GetResourceType(-1)) == 2 then
					if kept < maxLux or NearMajor(p) or protected[Idx(p)] then
						kept = kept + 1;
					else
						Set(p, -1); log.luxOff = log.luxOff + 1;
					end
				end
			end
			if level == 1 then
				local food = 0;
				for _, e in ipairs(around) do
					local p = e[1];
					if e[2] <= 2 and IsFood(p:GetResourceType(-1)) then
						food = food + 1;
						if food > 1 and not NearMajor(p) then Set(p, -1); log.foodOff = log.foodOff + 1 end
					end
				end
			elseif level == 3 then
				local food = 0;
				for _, e in ipairs(around) do
					if e[2] <= 2 and IsFood(e[1]:GetResourceType(-1)) then food = food + 1 end
				end
				for _, e in ipairs(around) do
					if food >= 4 then break end
					if e[2] <= 2 and not NearMajor(e[1]) then
						local r = FoodFor(e[1]);
						if r ~= nil then Set(e[1], r, 1); food = food + 1; log.foodOn = log.foodOn + 1 end
					end
				end
			end
		end
	end
	print("City states (level " .. level .. "):", log.cs, "city states, luxuries removed", log.luxOff,
		"food removed", log.foodOff, "food added", log.foodOn);
end
-- <<< CITY STATE QUALITY END >>>
------------------------------------------------------------------------------
--	FILE:	 BitMoreFairPangea.lua
--	AUTHOR:  KEK multiplayer community (2026), built on Firaxis' Pangaea.lua
--	         (Bob Thomas)
--	PURPOSE: The game's own Pangaea (same land, options, sizes, wrap), with
--	         fewer hopeless starts. NOT mirrored.
--	         1. Terrain, whole map, light: a few extra hills on tundra and non-jungle grassland.
--	            Thin dry open plains by about 5%; thinning river systems is optional.
--	         2. Start lifts, only for starts that fail a check (a start that
--	            passes is not touched; luxuries are never added):
--	            - majority grassland or tundra: 2 hills within 2 tiles; jungle: 1; plains: 0.
--	              Coastal capitals get an adjacent hill, preferably on the shoreline;
--	            - at least 2 food bonus resources within 3 tiles (weak start: 3);
--	            - a start whose luxuries within 2 tiles are all plantation
--	              ("calendar") luxuries and has no food bonus within 2 tiles
--	              gets one food bonus within 2 tiles;
--	            - weak start (40%+ of the land within 2 tiles is flat tundra,
--	              snow or flat desert without flood plains): also up to 2 snow
--	              tiles within 2 tiles become tundra.
--	         0. Continent shape: a snaky continent (thin arms all over the map,
--	            big inland seas) is rolled again on Normal; Broader favors fuller continents.
--	         3. Strategic Balance (the default resource setting here): every
--	            capital gets Horses, Iron, Coal (7) and Aluminium (3) within
--	            3 tiles.
--	         Deterministic: only Map.Rand is used (multiplayer safe).
------------------------------------------------------------------------------
--	Copyright (c) 2010 Firaxis Games, Inc. All rights reserved.
--	KEK additions (2026) are free to use and change.
------------------------------------------------------------------------------

include("MapGenerator");
include("FractalWorld");
include("FeatureGenerator");
include("TerrainGenerator");

------------------------------------------------------------------------------
-- Continent shape: how snaky the biggest landmass may be (see FairCoastShape).
FAIR_MAX_STRINGY = 4.5;	-- standard size (80 wide): round about 1-2, ordinary Pangaea 2.5-3.5, snaky 4.5+ (1.2: was 3.6 = too many round blobs, crowded)
FAIR_SHAPE_TRIES = 6;	-- snaky continents rolled again at most this often
FAIR_LAND_PERCENT = {0, 5, 7.5, 10, -5, -10};	-- option "Land": Normal (default) / +5% / +7.5% / +10% / -5% / -10% land tiles
FAIR_MOUNTAIN_CUT_PERCENT = 0;	-- (user 11-16: 0, keep the game's chains) share of mountains (inside the thickest chains) that become passes (hills)
FAIR_CAPITAL_MOUNTAINS_MAX = 8;	-- at most this many mountains within 4 tiles of a capital
------------------------------------------------------------------------------
local function FairCoastShape(areaID, measureFill)
	-- Coast tiles of the continent compared with the coast of a round continent
	-- of the same size (a hex disk of N tiles has about sqrt(12 N) coast tiles):
	-- about 1 = round, higher = long thin arms, inland seas, many inlets.
	local iW, iH = Map.GetGridSize();
	local land, coast = 0, 0;
	local columns, minY, maxY = {}, iH, -1;
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local plot = Map.GetPlot(x, y);
			if plot:GetArea() == areaID and not plot:IsWater() then
				land = land + 1;
				if measureFill then
					columns[x] = true;
					minY, maxY = math.min(minY, y), math.max(maxY, y);
				end
				for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
					local adj = Map.PlotDirection(x, y, direction);
					if adj ~= nil and adj:IsWater() then
						coast = coast + 1;
						break
					end
				end
			end
		end
	end
	local stringiness = coast / math.sqrt(12 * math.max(1, land));
	if not measureFill then return stringiness end
	-- Ignore the widest gap of empty columns, even when it crosses the map seam.
	local gap, longest = 0, 0;
	for x = 0, 2 * iW - 1 do
		gap = columns[x % iW] and 0 or gap + 1;
		longest = math.max(longest, gap);
	end
	return stringiness, land / ((iW - longest) * (maxY - minY + 1));
end
------------------------------------------------------------------------------
function GetMapScriptInfo()
	local world_age, temperature, rainfall, sea_level, resources = GetCoreMapOptions()
	-- Same lists as Pangaea. Defaults (user, 11-16): 3 Billion Years, midway between Temperate and Cool,
	-- Normal rainfall, Low sea level, Strategic Balance, Normal land.
	world_age.DefaultValue = 1;
	temperature.Values = {temperature.Values[1], "Normal (between Temperate and Cool)",
		temperature.Values[2], temperature.Values[3], temperature.Values[4]};
	temperature.DefaultValue = 3;	-- 1.6: Temperate
	rainfall.DefaultValue = 2;
	sea_level.DefaultValue = 1;
	resources.DefaultValue = 5;
	local land = {
		Name = "Land",
		Values = {"Normal (the game's Pangaea)", "+5% land", "+7.5% land", "+10% land", "-5% land", "-10% land"},
		DefaultValue = 5,	-- 1.7: -5% land
		SortPriority = 1,
	};
	local shape = {
		Name = "Continent shape",
		Values = {
			{"Normal", "Use the usual Pangaea shape and reroll unusually snaky continents."},
			{"Unfiltered", "Keep the first Pangaea, even if it has long, thin arms."},
			{"Broader", "Favor a fuller main continent with natural bays and peninsulas."},
			{"Broader / no inland lakes", "A broad continent free of enclosed lakes and seas. Bays remain open to the ocean."},
			{"Large inland seas", "A broad continent with a substantial enclosed sea. Its size scales with the map."},
			{"Compact Pangaea / no lakes", "The most Pangaea-like: one round, solid main continent with few long arms, no enclosed lakes or seas."},
		},
		DefaultValue = 4,
		SortPriority = 3,
	};
	local rivers = {
		Name = "Rivers",
		Values = {
			{"Normal", "Keep all rivers generated by this map."},
			{"5% fewer", "Remove about one in twenty whole river systems."},
		},
		DefaultValue = 1,
		SortPriority = 4,
	};
	local mountainCap = {
		Name = "Mountain clumps",
		Values = {
			{"Game's own", "Keep every mountain the map makes."},
			{"Thinner clumps", "Break up thick mountain blocks: no mountain keeps more than 3 mountain neighbours. Chains stay."},
			{"No clumps", "Mountains only as chains and single peaks: no mountain keeps more than 2 mountain neighbours."},
		},
		DefaultValue = 2,	-- 1.7: Thinner clumps
		SortPriority = 5,
	};
	local forests = {
		Name = "Forest and jungle",
		Values = {
			{"Game's own", "As many forests and jungles as the map makes."},
			{"5% fewer", "5% of forest and jungle tiles removed, from the thickest woods first."},
			{"10% fewer", "10% of forest and jungle tiles removed, from the thickest woods first."},
		},
		DefaultValue = 1,
		SortPriority = 6,
	};
	return {
		Name = "KEK BitMoreFairPangea 1.7",
		Description = "The game's Pangaea with fewer hopeless starts: less or more land (option), slightly fewer open plains, adjustable river count and continent shape, no mountain walls around capitals, richer tundra and grassland, coastal capitals get an adjacent hill; nearby hill targets depend on terrain, Strategic Balance adds Coal and Aluminium near every capital.",
		IsAdvancedMap = false,
		IconIndex = 0,
		SortIndex = 2,
		CustomOptions = {world_age, temperature, rainfall, sea_level, resources, land, shape, rivers, mountainCap, forests, CSQ_OptionDef()},
	}
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
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
	
	local sea_level = Map.GetCustomOption(4)
	if sea_level == 4 then
		sea_level = 1 + Map.Rand(3, "Random Sea Level - Lua");
	end
	local world_age = Map.GetCustomOption(1)
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
	-- BitMoreFair: option "Land" adjusts the land target relative to this sea level.
	local landExtra = FAIR_LAND_PERCENT[Map.GetCustomOption(6)] or 0;
	local water_percent_normal = water_percent;
	water_percent = 100 - (100 - water_percent) * (100 + landExtra) / 100;

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
	local shape = Map.GetCustomOption(7) or 1;
	local coastLimit = FAIR_MAX_STRINGY * math.pow(self.iNumPlotsX / 80, 0.7);
	local broader = shape >= 3;
	local compact = shape == 6;	-- "Compact Pangaea": stricter shape test, more tries, coarse grain
	local shapeTries = compact and 10 or (broader and 3 or FAIR_SHAPE_TRIES);
	fair_shapeLog, fair_shapeRejects, fair_bestShape = "", 0, nil;
	local iWaterThreshold, biggest_area, iNumTotalLandTiles, iNumBiggestAreaTiles, iBiggestID;
	while done == false do
		local grain_dice = Map.Rand(7, "Continental Grain roll - LUA Pangaea");
		if grain_dice < 4 or compact then
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
		-- BitMoreFair: the fractal has only 256 heights, so nearby Land options
		-- (+5% / +7.5%) would fall on the same coast. A finer height (own height,
		-- then the neighbours' sum, which keeps the coast smooth) and an exact
		-- percentile give every option its own land amount.
		self.fairFine, iWaterThreshold = FairFineHeights(self.continentsFrac, self.iNumPlotsX, self.iNumPlotsY, water_percent, water_percent_normal);

		iNumTotalLandTiles = 0;
		for x = 0, self.iNumPlotsX - 1 do
			for y = 0, self.iNumPlotsY - 1 do
				local i = y * self.iNumPlotsX + x;
				local val = self.fairFine[i];
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
			-- BitMoreFair: a snaky continent (long thin arms, a big inland sea) is
			-- rolled again, up to FAIR_SHAPE_TRIES times; then the least snaky one
			-- seen is used. Ordinary peninsulas pass, so maps still differ.
			local stringy, fill = FairCoastShape(biggest_area:GetID(), broader);
			local score = stringy / coastLimit;
			if broader then
				-- Prefer land occupying at least half its bounding rectangle.
				-- Compare at most three natural Pangaeas; never straighten the coast.
				if compact then
					score = math.max(stringy / (coastLimit * 0.70), 0.62 / fill);
				else
					score = math.max(score, 0.50 / fill);
				end
			end
			fair_shapeLog = (fair_shapeLog or "") .. string.format("%.2f ", stringy);
			if shape == 2 or score <= 1 then
				done = true;
				iBiggestID = biggest_area:GetID();
			else
				fair_shapeRejects = (fair_shapeRejects or 0) + 1;
				if fair_bestShape == nil or score < fair_bestShape.score then
					local copy = {};
					for i = 0, self.iNumPlotsX * self.iNumPlotsY - 1 do copy[i] = self.plotTypes[i] end
					fair_bestShape = {score = score, frac = self.continentsFrac, fine = self.fairFine, threshold = iWaterThreshold, plots = copy};
				end
				if fair_shapeRejects >= shapeTries then
					local b = fair_bestShape;
					self.continentsFrac, self.fairFine, iWaterThreshold = b.frac, b.fine, b.threshold;
					for i = 0, self.iNumPlotsX * self.iNumPlotsY - 1 do self.plotTypes[i] = b.plots[i] end
					SetPlotTypes(self.plotTypes);
					Map.RecalculateAreas();
					iBiggestID = Map.FindBiggestArea(false):GetID();
					done = true;
				end
			end
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
			local val = self.fairFine[i];
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

	FairThinMountains(self.plotTypes, self.iNumPlotsX, self.iNumPlotsY);

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

	-- BitMoreFair: open sea lanes near the poles, so ships can usually sail around.
	-- User 11-17: no sea lanes any more, the poles are the game's own.
	fair_seaLanes, fair_laneIce = {}, {};
	for loop, south in ipairs({}) do
		if Map.Rand(100, "BitMoreFairPangea - sea lane") < FAIR_SEA_LANE_PERCENT then
			table.insert(fair_seaLanes, (south and "south " or "north ") .. FairSeaLane(self.plotTypes, self.iNumPlotsX, self.iNumPlotsY, south));
		end
	end

	return self.plotTypes;
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
function FairHexNeighbours(i, W, H)
	-- Plot indexes next to plot i (wraps east-west).
	local x, y = i % W, math.floor(i / W);
	local even = { {0, 1}, {1, 0}, {0, -1}, {-1, -1}, {-1, 0}, {-1, 1} };
	local odd  = { {1, 1}, {1, 0}, {1, -1}, {0, -1}, {-1, 0}, {0, 1} };
	local out = {};
	for d = 1, 6 do
		local o = (y % 2 == 0) and even[d] or odd[d];
		local ny = y + o[2];
		if ny >= 0 and ny < H then out[#out + 1] = ny * W + (x + o[1]) % W end
	end
	return out;
end
------------------------------------------------------------------------------
FAIR_POLAR_LATITUDE = 0.65;	-- rows this far (0 = equator, 1 = pole) or more get no extra land
function FairFineHeights(frac, W, H, water_percent, water_percent_normal)
	-- fine[i] = height * 2000 + the 6 neighbours' heights (at most 1530), and one
	-- water threshold: a plot is land when fine > threshold.
	-- The Land option's extra land goes only to the warm middle rows: the cold
	-- rows keep the land the normal sea level gives them (not more ice and tundra).
	local N = W * H;
	local raw, fine, sorted = {}, {}, {};
	for i = 0, N - 1 do raw[i] = frac:GetHeight(i % W, math.floor(i / W)) end
	if (Map.GetCustomOption(7) or 1) >= 3 then
		-- Find the land-richest quarter of the world, including across the wrap.
		local columns = {};
		for x = 0, W - 1 do
			local sum = 0;
			for y = 0, H - 1 do sum = sum + raw[y * W + x] end
			columns[x] = sum;
		end
		local radius, center, best = math.floor(W / 8), 0, -1;
		for x = 0, W - 1 do
			local sum = 0;
			for dx = -radius, radius do sum = sum + columns[(x + dx) % W] end
			if sum > best then center, best = x, sum end
		end
		-- A shallow rise under the mainland makes marginal bays likelier to join
		-- the interior. The existing fractal still draws the coast at the land quota.
		for i = 0, N - 1 do
			local dx = math.abs(i % W - center);
			dx = math.min(dx, W - dx) / (W / 2);
			local dy = math.abs(2 * math.floor(i / W) / (H - 1) - 1);
			local distance = (3 * math.max(dx, dy) + math.min(dx, dy)) / 4;
			raw[i] = raw[i] + math.floor(((Map.GetCustomOption(7) == 6) and 60 or 24) * (1 - distance));
		end
	end
	for i = 0, N - 1 do
		local s = 0;
		for _, j in ipairs(FairHexNeighbours(i, W, H)) do s = s + raw[j] end
		fine[i] = raw[i] * 2000 + s;
		sorted[i + 1] = fine[i];
	end
	table.sort(sorted);
	local function Percentile(pct)
		local k = math.floor(pct / 100 * N + 0.5);
		if k < 1 then k = 1 end
		return sorted[k];
	end
	local thrNew = Percentile(water_percent);
	if water_percent_normal == nil or water_percent_normal <= water_percent + 0.001 then
		return fine, thrNew;
	end
	local thrNormal = Percentile(water_percent_normal);
	local function Polar(i)
		local y = math.floor(i / W);
		return math.abs(y - (H - 1) / 2) / ((H - 1) / 2) >= FAIR_POLAR_LATITUDE;
	end
	local polarLand, mid = 0, {};
	for i = 0, N - 1 do
		if Polar(i) then
			if fine[i] > thrNormal then polarLand = polarLand + 1 end
		else
			mid[#mid + 1] = fine[i];
		end
	end
	table.sort(mid, function(a, b) return a > b end);
	local wantMid = (N - math.floor(water_percent / 100 * N + 0.5)) - polarLand;
	if wantMid < 1 then wantMid = 1 end
	if wantMid >= #mid then wantMid = #mid - 1 end
	local thrMid = mid[wantMid + 1];
	-- shift the cold rows so the one threshold thrMid keeps their normal coast
	for i = 0, N - 1 do
		if Polar(i) then fine[i] = fine[i] + (thrMid - thrNormal) end
	end
	return fine, thrMid;
end
------------------------------------------------------------------------------
FAIR_SEA_LANE_PERCENT = 55;		-- chance per pole of an open sea lane (both: about 4 games in 5 can sail around)
FAIR_SEA_LANE_MAX_CUT = 60;		-- a lane that would cut more land (mostly snow out here) than this is left out (that pole stays iced)
FAIR_SEA_LANE_LAT = {0.80, 0.88};	-- the lane's rows: out in the snow / ice zone (the tundra stays whole); its ice is cleared
fair_laneIce = {};				-- GLOBAL plot indexes of the lanes (no ice there)
function FairSeaLane(plotTypes, W, H, south)
	-- The cheapest east-west ring of plots in the lane rows (land costs 1, a
	-- mountain 3, water 0) becomes ocean. Returns how many land plots it cut.
	-- Latitude as FeatureGenerator measures it.
	local rows = {};
	for y = 0, H - 1 do
		local lat = math.abs(H / 2 - y) / (H / 2);
		if lat >= FAIR_SEA_LANE_LAT[1] and lat <= FAIR_SEA_LANE_LAT[2] and ((y < H / 2) == south) then
			rows[y] = true;
		end
	end
	local function Cost(i)
		local pt = plotTypes[i];
		if pt == PlotTypes.PLOT_OCEAN then return 0 end
		if pt == PlotTypes.PLOT_MOUNTAIN then return 3 end
		return 1;
	end
	local even = { {0, 1}, {1, 0}, {0, -1}, {-1, -1}, {-1, 0}, {-1, 1} };
	local odd  = { {1, 1}, {1, 0}, {1, -1}, {0, -1}, {-1, 0}, {0, 1} };
	-- states: (y, unwrapped x in 0..W); a ring goes from (y0, 0) to (y0, W)
	local function Key(y, xu) return y * (W + 1) + xu end
	local best, bestPath = nil, nil;
	local starts = {};
	for y in pairs(rows) do starts[#starts + 1] = y end
	table.sort(starts);
	for _, y0 in ipairs(starts) do
		local dist, prev, done = {}, {}, {};
		local k0, goal = Key(y0, 0), Key(y0, W);
		dist[k0] = Cost(y0 * W);
		while true do
			local k, kd = nil, nil;
			for kk, d in pairs(dist) do
				if not done[kk] and (kd == nil or d < kd or (d == kd and kk < k)) then k, kd = kk, d end
			end
			if k == nil or k == goal then break end
			done[k] = true;
			local y, xu = math.floor(k / (W + 1)), k % (W + 1);
			for d = 1, 6 do
				local o = (y % 2 == 0) and even[d] or odd[d];
				local ny, nxu = y + o[2], xu + o[1];
				if rows[ny] and nxu >= 0 and nxu <= W then
					local nk = Key(ny, nxu);
					local nd = kd + ((nxu == W) and 0 or Cost(ny * W + nxu));
					if nxu == W and ny ~= y0 then nd = kd + Cost(ny * W) end
					if not done[nk] and (dist[nk] == nil or nd < dist[nk]) then dist[nk], prev[nk] = nd, k end
				end
			end
		end
		if dist[goal] ~= nil and (best == nil or dist[goal] < best) then
			best = dist[goal];
			bestPath = {};
			local k = goal;
			while k ~= nil do
				local y, xu = math.floor(k / (W + 1)), k % (W + 1);
				bestPath[#bestPath + 1] = y * W + xu % W;
				k = prev[k];
			end
		end
	end
	if bestPath == nil then return 0 end
	-- 2 plots wide: each lane plot and the plot next to it on the pole side
	local lane, inLane = {}, {};
	for _, i in ipairs(bestPath) do
		local x, y = i % W, math.floor(i / W);
		local y2 = south and (y - 1) or (y + 1);
		for _, j in ipairs({i, (y2 >= 0 and y2 < H) and (y2 * W + x) or nil}) do
			if j ~= nil and not inLane[j] then inLane[j] = true; lane[#lane + 1] = j end
		end
	end
	local cut = 0;
	for _, i in ipairs(lane) do
		if plotTypes[i] ~= PlotTypes.PLOT_OCEAN then cut = cut + 1 end
	end
	if cut > FAIR_SEA_LANE_MAX_CUT then return "skipped(" .. cut .. ")" end	-- would cut the continent: this pole stays iced
	for _, i in ipairs(lane) do
		plotTypes[i] = PlotTypes.PLOT_OCEAN;
		table.insert(fair_laneIce, i);	-- AddFeatures keeps these free of ice
	end
	-- The land beyond the lane is now an island off the main continent (where
	-- the starts go): give that back too, so the continent keeps its size.
	local beyond = 0;
	for i = 0, W * H - 1 do
		local y = math.floor(i / W);
		local lat = math.abs(H / 2 - y) / (H / 2);
		if plotTypes[i] ~= PlotTypes.PLOT_OCEAN and lat > FAIR_SEA_LANE_LAT[2] and ((y < H / 2) == south) then beyond = beyond + 1 end
	end
	FairFillBays(plotTypes, W, H, cut + beyond);
	return cut;
end
------------------------------------------------------------------------------
function FairFillBays(plotTypes, W, H, count)
	-- Gives back land a sea lane cut: ocean plots in the warm middle rows with the
	-- most land around them (bays, inlets) become flat land.
	local even = { {0, 1}, {1, 0}, {0, -1}, {-1, -1}, {-1, 0}, {-1, 1} };
	local odd  = { {1, 1}, {1, 0}, {1, -1}, {0, -1}, {-1, 0}, {0, 1} };
	local added = 0;
	for need = 6, 3, -1 do
		local list = {};
		for i = 0, W * H - 1 do
			local y = math.floor(i / W);
			local lat = math.abs(H / 2 - y) / (H / 2);
			if plotTypes[i] == PlotTypes.PLOT_OCEAN and lat < FAIR_SEA_LANE_LAT[1] - 0.05 then
				local n = 0;
				for d = 1, 6 do
					local o = (y % 2 == 0) and even[d] or odd[d];
					local ny = y + o[2];
					if ny >= 0 and ny < H and plotTypes[ny * W + (i % W + o[1]) % W] ~= PlotTypes.PLOT_OCEAN then n = n + 1 end
				end
				if n >= need then list[#list + 1] = i end
			end
		end
		for n = #list, 2, -1 do
			local k = 1 + Map.Rand(n, "BitMoreFairPangea - fill bays");
			list[n], list[k] = list[k], list[n];
		end
		for _, i in ipairs(list) do
			if added >= count then return end
			plotTypes[i] = PlotTypes.PLOT_LAND;
			added = added + 1;
		end
	end
end
------------------------------------------------------------------------------
function FairThinMountains(plotTypes, W, H)
	-- Fewer endless chains: FAIR_MOUNTAIN_CUT_PERCENT of the mountains become
	-- passes (hills), always the ones deepest inside a chain (most mountain
	-- neighbours); single peaks and chain ends stay.
	local function MountainNeighbours(i)
		local n = 0;
		for _, j in ipairs(FairHexNeighbours(i, W, H)) do
			if plotTypes[j] == PlotTypes.PLOT_MOUNTAIN then n = n + 1 end
		end
		return n;
	end
	local list, total = {}, 0;
	for i = 0, W * H - 1 do
		if plotTypes[i] == PlotTypes.PLOT_MOUNTAIN then
			total = total + 1;
			local n = MountainNeighbours(i);
			if n >= 3 then list[#list + 1] = {i = i, n = n, r = Map.Rand(1000, "BitMoreFairPangea - thin mountains")} end
		end
	end
	table.sort(list, function(a, b)
		if a.n ~= b.n then return a.n > b.n end
		if a.r ~= b.r then return a.r < b.r end
		return a.i < b.i
	end);
	local cut = math.floor(total * FAIR_MOUNTAIN_CUT_PERCENT / 100 + 0.5);
	local done = 0;
	for _, c in ipairs(list) do
		if done >= cut then break end
		if MountainNeighbours(c.i) >= 3 then	-- still inside a chain (an earlier pass may sit next to it)
			plotTypes[c.i] = PlotTypes.PLOT_HILLS;
			done = done + 1;
		end
	end
	fair_mountainCut = done;	-- GLOBAL, for logs and tests
	print("BitMoreFairPangea: mountains -> passes", done, "of", total);
end
------------------------------------------------------------------------------
FAIR_CLUMP_MAX_NEIGHBOURS = {nil, 3, 2};	-- option "Mountain clumps": most mountain neighbours a mountain may keep
function FairMountainCap()
	-- Break up clumps, keep chains: while a mountain has more mountain neighbours
	-- than allowed, the one with the most becomes ordinary land (flat or hills, at
	-- the map's own hill share). A chain (2 neighbours each) is never touched.
	local maxN = FAIR_CLUMP_MAX_NEIGHBOURS[Map.GetCustomOption(9) or 1];
	fair_mountainCapCut = 0;	-- GLOBAL, for logs and tests
	if maxN == nil then return end
	local W, H = Map.GetGridSize();
	local hills, flat, list = 0, 0, {};
	local function Count(i)
		local n = 0;
		for _, j in ipairs(FairHexNeighbours(i, W, H)) do
			if Map.GetPlotByIndex(j):IsMountain() then n = n + 1 end
		end
		return n;
	end
	for i = 0, W * H - 1 do
		local p = Map.GetPlotByIndex(i);
		if p:IsMountain() then list[#list + 1] = i
		elseif p:IsHills() then hills = hills + 1
		elseif not p:IsWater() then flat = flat + 1 end
	end
	local hillPermille = math.floor(1000 * hills / math.max(1, hills + flat));
	local function Edge(i)
		for _, j in ipairs(FairHexNeighbours(i, W, H)) do
			if not Map.GetPlotByIndex(j):IsMountain() then return true end
		end
		return false;
	end
	while true do
		-- 1.7 (user): peel a clump from its edge inward, never punch holes in its middle.
		-- Candidates: mountains on the clump's rim that touch an over-full mountain
		-- (or are over-full themselves); the one with the most mountain neighbours goes first.
		local over, any = {}, false;
		for _, i in ipairs(list) do if Count(i) > maxN then over[i] = true; any = true end end
		if not any then break end
		local bestN, ties = -1, {};
		for k, i in ipairs(list) do
			local touches = over[i];
			if not touches then
				for _, j in ipairs(FairHexNeighbours(i, W, H)) do if over[j] then touches = true; break end end
			end
			if touches and Edge(i) then
				local n = Count(i);
				if n > bestN then bestN, ties = n, {k} elseif n == bestN then ties[#ties + 1] = k end
			end
		end
		if #ties == 0 then
			for k, i in ipairs(list) do if over[i] then ties[#ties + 1] = k end end
		end
		local k = ties[1 + Map.Rand(#ties, "BitMoreFairPangea - mountain clumps")];
		local hill = Map.Rand(1000, "BitMoreFairPangea - mountain clumps land") < hillPermille;
		Map.GetPlotByIndex(list[k]):SetPlotType(hill and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND, false, false);
		table.remove(list, k);
		fair_mountainCapCut = fair_mountainCapCut + 1;
	end
	print("BitMoreFairPangea: mountain clumps -> land", fair_mountainCapCut);
end
------------------------------------------------------------------------------
-- Work on the actual installed hex grid after the stock plot-index conversions.
-- Polar waters and the largest ocean are exterior, including across the x seam.
local function FairWaterComponents(tiles, value, neighbors)
	local seen, groups = {}, {};
	for i = 0, #neighbors do
		if tiles[i] == value and not seen[i] then
			local group = {i};
			seen[i] = true;
			for _, j in ipairs(group) do
				for _, k in ipairs(neighbors[j]) do
					if tiles[k] == value and not seen[k] then
						seen[k] = true;
						group[#group + 1] = k;
					end
				end
			end
			groups[#groups + 1] = group;
		end
	end
	return groups;
end

local function FairInlandWaters(shape)
	local W, H = Map.GetGridSize();
	local N = W * H;
	local water, neighbors, land = {}, {}, 0;
	for i = 0, N - 1 do
		water[i] = Map.GetPlotByIndex(i):IsWater();
		if not water[i] then land = land + 1 end
		neighbors[i] = FairHexNeighbours(i, W, H);
	end
	local bodies = FairWaterComponents(water, true, neighbors);
	local ocean;
	for _, body in ipairs(bodies) do
		if not ocean or #body > #ocean then ocean = body end
	end
	local exterior, enclosed, biggestSea = {}, {}, 0;
	for _, body in ipairs(bodies) do
		local outside = body == ocean;
		for _, i in ipairs(body) do
			if i < W or i >= N - W then outside = true; break end
		end
		if outside then
			for _, i in ipairs(body) do exterior[i] = true end
		else
			biggestSea = math.max(biggestSea, #body);
			for _, i in ipairs(body) do enclosed[#enclosed + 1] = i end
		end
	end
	local target = math.max(12, math.floor(land * 0.03 + 0.5));
	if shape == 5 and biggestSea >= target then return end

	-- Fill enclosed basins first. For the sea preset, find a basin with a
	-- continuous land rim, far enough from both the ocean and the polar edges.
	local delta = #enclosed;
	for _, i in ipairs(enclosed) do water[i] = false end
	if shape == 5 then
		local distance, queue, core = {}, {}, {};
		for i = 0, N - 1 do
			if exterior[i] or i < W or i >= N-W then
				distance[i] = 0;
				queue[#queue + 1] = i;
			end
		end
		for _, i in ipairs(queue) do
			for _, j in ipairs(neighbors[i]) do
				if distance[j] == nil then
					distance[j] = distance[i] + 1;
					queue[#queue + 1] = j;
				end
			end
		end
		local basin;
		for buffer = 3, 2, -1 do
			for i = 0, N - 1 do core[i] = distance[i] >= buffer end
			basin = nil;
			for _, region in ipairs(FairWaterComponents(core, true, neighbors)) do
				if not basin or #region > #basin then basin = region end
			end
			if basin and #basin >= target then break end
		end
		if basin then
			local center = basin[1];
			for _, i in ipairs(basin) do
				if distance[i] > distance[center] then center = i end
			end
			local sea, visited = {center}, {[center] = true};
			for _, i in ipairs(sea) do
				if #sea >= target then break end
				for _, j in ipairs(FairShuffled(neighbors[i])) do
					if core[j] and not visited[j] then
						visited[j] = true;
						sea[#sea + 1] = j;
						if #sea >= target then break end
					end
				end
			end
			for _, i in ipairs(sea) do water[i] = true end
			delta = delta - #sea;
		end
	end

	-- Offset the change on the ocean shore. A single consecutive arc of wet
	-- neighbors keeps channels open, land bridges intact and the sea enclosed.
	while delta ~= 0 do
		local previous = delta;
		local coast = {};
		for i = W, N - W - 1 do
			local wet = 0;
			for _, j in ipairs(neighbors[i]) do if exterior[j] then wet = wet + 1 end end
			if wet > 0 and wet < 6 then coast[#coast + 1] = i end
		end
		for _, i in ipairs(FairShuffled(coast)) do
			if delta == 0 then break end
			local erode = delta > 0;
			if (erode and not water[i]) or (not erode and exterior[i]) then
				local transitions, inlandNeighbor = 0, false;
				for d, j in ipairs(neighbors[i]) do
					local k = neighbors[i][d % 6 + 1];
					if water[j] ~= water[k] then transitions = transitions + 1 end
					if water[j] and not exterior[j] then inlandNeighbor = true end
				end
				if transitions == 2 and not inlandNeighbor then
					water[i], exterior[i] = erode, erode;
					delta = delta + (erode and -1 or 1);
				end
			end
		end
		if delta == previous then break end
	end
	for i = 0, N - 1 do
		local p = Map.GetPlotByIndex(i);
		if p:IsWater() ~= water[i] then
			p:SetPlotType(water[i] and PlotTypes.PLOT_OCEAN or PlotTypes.PLOT_LAND, false, false);
		end
	end
	Map.RecalculateAreas();
end

function FairNoLakes()
	local shape = Map.GetCustomOption(7);
	return shape == 4 or shape == 6;
end
local FairGameAddLakes = AddLakes;
function AddLakes()
	if not FairNoLakes() then FairGameAddLakes() end
end

function GeneratePlotTypes()
	-- Plot generation customized to ensure enough land belongs to the Pangaea.
	print("Generating Plot Types (Lua Pangaea) ...");
	
	local fractal_world = PangaeaFractalWorld.Create();
	local plotTypes = fractal_world:GeneratePlotTypes();
	
	SetPlotTypes(plotTypes);
	local shape = Map.GetCustomOption(7);
	if shape == 4 or shape == 6 then FairInlandWaters(4) elseif shape == 5 then FairInlandWaters(5) end
	FairMountainCap();
	GenerateCoasts();
end
------------------------------------------------------------------------------
-- Remove a random sample without replacement. All clients use the map RNG.
local function FairTakeSample(items, target, visit)
	local n = math.floor(target);
	if Map.Rand(100, "Fair sample rounding") < (target - n) * 100 then n = n + 1 end
	n = math.min(n, #items);
	for i = 1, n do
		local pick = i + Map.Rand(#items - i + 1, "Fair sample");
		items[i], items[pick] = items[pick], items[i];
		visit(items[i]);
	end
	return n;
end

local function FairReduceOpenPlains()
	local candidates, open = {}, 0;
	local W, H = Map.GetGridSize();
	for i = 0, W * H - 1 do
		local p = Map.GetPlotByIndex(i);
		if p:GetPlotType() == PlotTypes.PLOT_LAND and p:GetTerrainType() == TerrainTypes.TERRAIN_PLAINS
			and p:GetFeatureType() == FeatureTypes.NO_FEATURE then
			open = open + 1;
			if not p:IsFreshWater() then
				local desert, tundra = 0, 0;
				for _, j in ipairs(FairHexNeighbours(i, W, H)) do
					local terrain = Map.GetPlotByIndex(j):GetTerrainType();
					if terrain == TerrainTypes.TERRAIN_DESERT then desert = desert + 1 end
					if terrain == TerrainTypes.TERRAIN_TUNDRA then tundra = tundra + 1 end
				end
				if desert + tundra > 0 then
					candidates[#candidates + 1] = {p, desert > tundra and TerrainTypes.TERRAIN_DESERT or TerrainTypes.TERRAIN_TUNDRA};
				end
			end
		end
	end
	local removed = FairTakeSample(candidates, open * 0.05, function(entry)
		entry[1]:SetTerrainType(entry[2], false, true);
	end);
	print("BitMoreFairPangea: open plains, converted", open, removed);
end

-- An edge joins two hex corners. Group edges sharing a corner before sampling
-- so a river and its tributaries are either kept intact or removed together.
local function FairReduceRivers()
	local W, H = Map.GetGridSize();
	local endsAt, edges = {}, {};
	local function corner(x, y)
		return (y + 2) * (2 * W) + x % (2 * W);
	end
	local function add(p, setter, a, b)
		local edge = {plot = p, clear = setter, a = a, b = b};
		edges[#edges + 1] = edge;
		for _, key in ipairs({a, b}) do
			endsAt[key] = endsAt[key] or {};
			table.insert(endsAt[key], edge);
		end
	end
	for i = 0, W * H - 1 do
		local p = Map.GetPlotByIndex(i);
		local x, y = 2 * p:GetX() + p:GetY() % 2, 3 * p:GetY();
		local se, south, sw = corner(x + 1, y - 1), corner(x, y - 2), corner(x - 1, y - 1);
		if p:IsWOfRiver() then add(p, p.SetWOfRiver, corner(x + 1, y + 1), se) end
		if p:IsNWOfRiver() then add(p, p.SetNWOfRiver, se, south) end
		if p:IsNEOfRiver() then add(p, p.SetNEOfRiver, south, sw) end
	end
	local systems = {};
	for _, first in ipairs(edges) do
		if not first.seen then
			local system = {first};
			systems[#systems + 1] = system;
			first.seen = true;
			for _, edge in ipairs(system) do
				for _, key in ipairs({edge.a, edge.b}) do
					for _, neighbor in ipairs(endsAt[key]) do
						if not neighbor.seen then
							neighbor.seen = true;
							system[#system + 1] = neighbor;
						end
					end
				end
			end
		end
	end
	local removed = FairTakeSample(systems, #systems * 0.05, function(system)
		for _, edge in ipairs(system) do
			local p = edge.plot;
			edge.clear(p, false, FlowDirectionTypes.NO_FLOWDIRECTION);
			if not (p:IsWOfRiver() or p:IsNWOfRiver() or p:IsNEOfRiver()) then _rivers[p] = nil end
		end
	end);
	print("BitMoreFairPangea: river systems, removed", #systems, removed);
end

function GenerateTerrain()
	
	-- Get Temperature setting input by user.
	local temp = Map.GetCustomOption(2)
	if temp == 5 then
		temp = 1 + Map.Rand(4, "Random Temperature - Lua");
	end

	-- BitMoreFair (user, 11-16): a wider tundra band (the game: from 0.6), snow as the game has it.
	local gameTemperature = ({1, 2, 2, 3})[temp] or 2;
	local args = {temperature = gameTemperature, fTundraLatitude = FAIR_TUNDRA_LATITUDE};
	-- Use half the game's Cool adjustments for the new Normal. Temperate
	-- and Cool share a snow line; the generator moves the tundra and warm bands.
	if temp == 2 then
		args.temperature = 1;
		args.temperature_shift = 0.05;
		args.desert_shift = 8;
	end
	local terraingen = TerrainGenerator.Create(args);

	terrainTypes = terraingen:GenerateTerrain();
	
	SetTerrainTypes(terrainTypes);
end
------------------------------------------------------------------------------
function AddFeatures()
	print("Adding Features (Lua Pangaea) ...");

	-- Get Rainfall setting input by user.
	local rain = Map.GetCustomOption(3)
	if rain == 4 then
		rain = 1 + Map.Rand(3, "Random Rainfall - Lua");
	end
	
	local args = {rainfall = rain}
	local featuregen = FeatureGenerator.Create(args);

	-- False parameter removes mountains from coastlines.
	featuregen:AddFeatures(false);

	-- BitMoreFairPangea: the sea lanes stay free of ice.
	local iceCleared = 0;
	for _, i in ipairs(fair_laneIce or {}) do
		local plot = Map.GetPlotByIndex(i);
		if plot:GetFeatureType() == FeatureTypes.FEATURE_ICE then
			plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
			iceCleared = iceCleared + 1;
		end
	end
	print("BitMoreFairPangea: ice cleared on the sea lanes", iceCleared);

	-- BitMoreFairPangea: a few more hills, mostly in the tundra; tundra lakes.
	FairTerrainTweak();
	if not FairNoLakes() then FairTundraLakes() end
	FairReduceOpenPlains();
	FairThinForests();
end
------------------------------------------------------------------------------
FAIR_FOREST_CUT_PERCENT = {0, 5, 10};	-- option "Forest and jungle"
function FairThinForests()
	-- The thickest woods first (most wooded neighbours), so open spots appear
	-- inside big forest blankets and single forests stay.
	local pct = FAIR_FOREST_CUT_PERCENT[Map.GetCustomOption(10) or 1] or 0;
	fair_forestCut = 0;
	if pct == 0 then return end
	local W, H = Map.GetGridSize();
	local function Wood(p)
		local f = p:GetFeatureType();
		return f == FeatureTypes.FEATURE_FOREST or f == FeatureTypes.FEATURE_JUNGLE;
	end
	local list = {};
	for i = 0, W * H - 1 do
		local p = Map.GetPlotByIndex(i);
		if Wood(p) then
			local n = 0;
			for _, j in ipairs(FairHexNeighbours(i, W, H)) do if Wood(Map.GetPlotByIndex(j)) then n = n + 1 end end
			list[#list + 1] = {i = i, n = n, r = Map.Rand(1000, "BitMoreFairPangea - thin forests")};
		end
	end
	table.sort(list, function(a, b)
		if a.n ~= b.n then return a.n > b.n end
		if a.r ~= b.r then return a.r < b.r end
		return a.i < b.i;
	end);
	local cut = math.floor(#list * pct / 100 + 0.5);
	for k = 1, cut do
		Map.GetPlotByIndex(list[k].i):SetFeatureType(FeatureTypes.NO_FEATURE, -1);
	end
	fair_forestCut = cut;
	print("BitMoreFairPangea: forest/jungle removed", cut, "of", #list);
end
------------------------------------------------------------------------------
FAIR_TUNDRA_LATITUDE = 0.55;	-- tundra starts at this latitude (the game: 0.6)
FAIR_TUNDRA_LAKE_PERCENT = 8;	-- share of inland flat tundra (no water or river next to it, 2+ hills next to it) that becomes a 1-tile lake
FAIR_TUNDRA_RIVER_PERCENT = 20;	-- share of inland tundra plots far from water and rivers that start an extra river
------------------------------------------------------------------------------
-- Rivers: the game's own, then extra ones starting in the tundra (fresh water there).
local FairGameAddRivers = AddRivers;
function AddRivers()
	FairGameAddRivers();
	local iW, iH = Map.GetGridSize();
	local made = 0;
	for i = 0, iW * iH - 1 do
		local plot = Map.GetPlotByIndex(i);
		if plot:GetTerrainType() == TerrainTypes.TERRAIN_TUNDRA and not plot:IsWater() and not plot:IsCoastalLand()
			and not plot:IsRiver() and not Map.FindWater(plot, 2, true)
			and Map.Rand(100, "BitMoreFairPangea - tundra river") < FAIR_TUNDRA_RIVER_PERCENT then
			local corner = plot:GetInlandCorner();
			if corner then
				DoRiver(corner);
				made = made + 1;
			end
		end
	end
	if Map.GetCustomOption(8) == 2 then FairReduceRivers() end
	fair_tundraRivers = made;	-- GLOBAL, for logs and tests
	print("BitMoreFairPangea: extra tundra rivers", made);
end
function FairTundraLakes()
	-- Fresh water in the tundra: small lakes on inland flat tundra, never next
	-- to other water or a river, never on a start (none exist yet).
	local iW, iH = Map.GetGridSize();
	local made = 0;
	for i = 0, iW * iH - 1 do
		local plot = Map.GetPlotByIndex(i);
		if plot:GetTerrainType() == TerrainTypes.TERRAIN_TUNDRA and plot:GetPlotType() == PlotTypes.PLOT_LAND
			and plot:GetResourceType(-1) == -1 and not plot:IsRiver() then
			local dry, hills = true, 0;
			for loop, p in ipairs(FairPlotsInRings(plot:GetX(), plot:GetY(), 1, 1)) do
				if p:IsWater() or p:IsRiver() then dry = false; break end
				if p:IsHills() or p:IsMountain() then hills = hills + 1 end
			end
			dry = dry and hills >= 2;	-- lakes in hilly tundra only (user, 11-16); the flat tundra gets rivers
			if dry and Map.Rand(100, "BitMoreFairPangea - tundra lake") < FAIR_TUNDRA_LAKE_PERCENT then
				-- as the game's AddLakes does it (areas are recalculated after AddFeatures)
				plot:SetFeatureType(FeatureTypes.NO_FEATURE, -1);
				plot:SetArea(-1);
				plot:SetPlotType(PlotTypes.PLOT_OCEAN);
				plot:SetTerrainType(TerrainTypes.TERRAIN_COAST, false, false);
				made = made + 1;
			end
		end
	end
	fair_tundraLakes = made;	-- GLOBAL, for logs and tests
	print("BitMoreFairPangea: tundra lakes", made);
end
------------------------------------------------------------------------------
-- Region IDs and terrain-count columns are the BNW starting-plot database's.
local FairBiasColumn = {14, 17, 16, 13, 5, 12, 11};
local function FairBiasTiles(x, y)
	local counts = {0, 0, 0, 0, 0, 0, 0};
	for _, p in ipairs(FairPlotsInRings(x, y, 1, 2)) do
		if not p:IsWater() and not p:IsMountain() then
			local terrain, feature = p:GetTerrainType(), p:GetFeatureType();
			if terrain == TerrainTypes.TERRAIN_TUNDRA then counts[1] = counts[1] + 1 end
			if feature == FeatureTypes.FEATURE_JUNGLE then counts[2] = counts[2] + 1 end
			if feature == FeatureTypes.FEATURE_FOREST then counts[3] = counts[3] + 1 end
			if terrain == TerrainTypes.TERRAIN_DESERT then counts[4] = counts[4] + 1 end
			if p:IsHills() then counts[5] = counts[5] + 1 end
			if terrain == TerrainTypes.TERRAIN_PLAINS then counts[6] = counts[6] + 1 end
			if terrain == TerrainTypes.TERRAIN_GRASS then counts[7] = counts[7] + 1 end
		end
	end
	return counts;
end

local function FairLobbyBiases(asp)
	if Game.GetCustomOption("GAMEOPTION_DISABLE_START_BIAS") == 1 then return {} end
	local biases = {};
	for _, id in ipairs(asp.player_ID_list) do
		local player = Players[id];
		local civ = GameInfo.Civilizations[player:GetCivilizationType()].Type;
		biases[#biases+1] = {id=id, team=player:GetTeam(), coast=CivNeedsCoastalStart(civ),
			river=CivNeedsRiverStart(civ), prefer=GetStartRegionPriorityListForCiv_GetIDs(civ),
			avoid=GetStartRegionAvoidListForCiv_GetIDs(civ)};
	end
	return biases;
end

-- Reserve coastal sites before the game starts placing its spacing and resource
-- buffers. Favor regions with plenty of shore and let inland civs retain scarce biomes.
local function FairChooseMajorStarts(asp, biases)
	if #biases == 0 then return asp:ChooseLocations() end
	local shores, preferred = 0, {};
	for _, bias in ipairs(biases) do
		if bias.coast then shores = shores + 1 end
		for _, kind in ipairs(bias.prefer) do preferred[kind] = true end
	end
	local targets, pending = {}, {};
	local findNormal, evaluate = asp.FindStart, asp.EvaluateCandidatePlot;
	local W = Map.GetGridSize();
	for i = 1, asp.iNumCivs do pending[i] = true end

	-- Pick distinct regions with the best supply of each requested biome. The
	-- site's normal fertility and spacing checks still decide which tiles qualify.
	local function plan()
		local ranked = {};
		for i, counts in ipairs(asp.regionTerrainCounts) do
			if counts[22] >= 3 then ranked[#ranked+1] = i end
		end
		table.sort(ranked, function(a,b)
			local pa, pb = preferred[asp.regionTypes[a]], preferred[asp.regionTypes[b]];
			if pa ~= pb then return not pa end
			local ca, cb = asp.regionTerrainCounts[a][22], asp.regionTerrainCounts[b][22];
			if ca ~= cb then return ca > cb end
			return a < b;
		end);
		for i = 1, math.min(shores,#ranked) do targets[ranked[i]] = "coast" end
		for _, bias in ipairs(biases) do
			if not bias.coast then
				local best, kind, score = nil, nil, 0;
				for i, counts in ipairs(asp.regionTerrainCounts) do
					if not targets[i] then
						for _, k in ipairs(bias.prefer) do
							local column = FairBiasColumn[k];
							if column and counts[column] > 0 then
								local fit = counts[column] / math.max(1, counts[2]);
								if asp.regionTypes[i] == k then fit = fit + 1 end
								if fit > score then best, kind, score = i, k, fit end
							end
						end
					end
				end
				if best then targets[best] = kind end
			end
		end
	end

	local planned = false;
	local function choose(self, region)
		if not planned then plan(); planned = true end
		pending[region] = nil;
		local reserved = 0;
		for i = 1, self.iNumCivs do
			if pending[i] and targets[i] == "coast" then reserved = reserved + 1 end
		end
		local wantCoast = shores > 0 and self.regionTerrainCounts[region][22] >= 3
			and (targets[region] == "coast" or reserved < shores);
		local kind = targets[region];
		if type(kind) == "number" and not wantCoast then
			self.EvaluateCandidatePlot = function(db, index, regionType)
				local score, eligible = evaluate(db, index, regionType);
				local x, y = (index-1) % W, math.floor((index-1)/W);
				local n = FairBiasTiles(x,y)[kind];
				return score + 4 * math.min(3,n), eligible;
			end
		end
		-- The native coastal finder can itself fall back to FindStart.
		self.FindStart = findNormal;
		local find = wantCoast and self.FindCoastalStart or findNormal;
		local success, forced = find(self, region);
		self.FindStart, self.EvaluateCandidatePlot = choose, evaluate;
		local start = self.startingPlots[region];
		if start and self.plotDataIsCoastal[start[2]*W+start[1]+1] then
			shores = math.max(0, shores-1);
		end
		return success, forced;
	end
	asp.FindStart = choose;
	asp:ChooseLocations();
	asp.FindStart = findNormal;
	if shores > 0 then print("BitMoreFairPangea: coastal seats unavailable", shores) end
end

-- Resolve mismatches between the region label and the capital's actual tiles.
-- An exchange must improve one civ without worsening the other's bias. Keep team
-- locations and all normalized starting sites. Stop rewarding terrain at three tiles.
local function FairRefineBiasAssignment(asp, biases)
	if #biases == 0 then return end
	local sites, scores, assigned = {}, {}, {};
	for i, start in ipairs(asp.startingPlots) do
		local x,y = start[1],start[2];
		sites[i] = {plot=Map.GetPlot(x,y), coast=AdjacentToSaltWater(x,y), tiles=FairBiasTiles(x,y)};
	end
	for i, bias in ipairs(biases) do
		scores[i] = {};
		local current = Players[bias.id]:GetStartingPlot();
		for j, site in ipairs(sites) do
			local plot, value = site.plot, 0;
			if plot:GetX()==current:GetX() and plot:GetY()==current:GetY() then assigned[i]=j end
			if bias.coast then value = site.coast and 100 or 0
			elseif bias.river then value = plot:IsRiver() and 100 or 0
			elseif #bias.prefer > 0 then
				for _, k in ipairs(bias.prefer) do
					local n = math.min(3,site.tiles[k] or 0);
					value = math.max(value, 3*n + (asp.regionTypes[j]==k and 2 or 0));
				end
			else
				for _, k in ipairs(bias.avoid) do
					value = value - math.min(3,site.tiles[k] or 0) - (asp.regionTypes[j]==k and 4 or 0);
				end
			end
			scores[i][j] = value;
		end
		if not assigned[i] then return end
	end
	local changed;
	repeat
		changed = false;
		for i = 1,#biases-1 do
			for j = i+1,#biases do
				if not asp.bTeamGame or biases[i].team==biases[j].team then
					local a,b = assigned[i],assigned[j];
					local da = scores[i][b]-scores[i][a];
					local db = scores[j][a]-scores[j][b];
					if da>=0 and db>=0 and da+db>0 then
						assigned[i],assigned[j] = b,a;
						changed = true;
					end
				end
			end
		end
	until not changed
	for i,bias in ipairs(biases) do
		local player,plot = Players[bias.id],sites[assigned[i]].plot;
		local current = player:GetStartingPlot();
		if current:GetX()~=plot:GetX() or current:GetY()~=plot:GetY() then player:SetStartingPlot(plot) end
	end
end

function StartPlotSystem()
	-- Get Resources setting input by user.
	local res = Map.GetCustomOption(5)
	if res == 6 then
		res = 1 + Map.Rand(3, "Random Resources Option - Lua");
	end

	print("Creating start plot database.");
	local start_plot_database = AssignStartingPlots.Create()
	fair_startPlotDatabase = start_plot_database;
	
	print("Dividing the map in to Regions.");
	-- Regional Division Method 1: Biggest Landmass
	local args = {
		method = 1,
		resources = res,
		};
	start_plot_database:GenerateRegions(args)

	print("Choosing start locations for civilizations.");
	local biases = FairLobbyBiases(start_plot_database);
	FairChooseMajorStarts(start_plot_database, biases);
	
	print("Normalizing start locations and assigning them to Players.");
	start_plot_database:BalanceAndAssign()
	FairRefineBiasAssignment(start_plot_database, biases);

	print("Placing Natural Wonders.");
	start_plot_database:PlaceNaturalWonders()

	print("Placing Resources and City States.");
	start_plot_database:PlaceResourcesAndCityStates()
	CSQ_Run(CSQ_Level(), nil);	-- city states: max 1 luxury + quality option
	-- 1.7: the best starts capped (after everything else is placed).
	fair_capLog = {};
	for region_number = 1, start_plot_database.iNumCivs do
		FairCapStart(start_plot_database, region_number);
	end
end
------------------------------------------------------------------------------
-- 1.7 (user): city states spread more evenly. The game always takes a coastal
-- site when its search section has one, and searches each region from the rim
-- inward. Here half the time an inland site is tried first, and a city state
-- often skips the outer 1-2 sections, so more of them sit inland and nearer the middle.
local FairGamePlaceCityState = AssignStartingPlots.PlaceCityState;
function AssignStartingPlots:PlaceCityState(coastal, inland, check_proximity, check_collision)
	if Map.Rand(100, "BitMoreFairPangea - CS inland first") < 50 then
		local x, y, ok = FairGamePlaceCityState(self, {}, inland, check_proximity, check_collision);
		if ok then return x, y, ok end
		return FairGamePlaceCityState(self, coastal, {}, check_proximity, check_collision);
	end
	return FairGamePlaceCityState(self, coastal, inland, check_proximity, check_collision);
end
local FairGameNextSection = AssignStartingPlots.ObtainNextSectionInRegion;
function AssignStartingPlots:ObtainNextSectionInRegion(...)
	local a, b, c, d, e, f, middle = FairGameNextSection(self, ...);
	if (fair_csSkip or 0) > 0 and not middle then
		fair_csSkip = fair_csSkip - 1;
		return {}, {}, c, d, e, f, middle;
	end
	return a, b, c, d, e, f, middle;
end
local FairGamePlaceCSInRegion = AssignStartingPlots.PlaceCityStateInRegion;
function AssignStartingPlots:PlaceCityStateInRegion(cs, region)
	local roll = Map.Rand(100, "BitMoreFairPangea - CS depth");
	fair_csSkip = (roll < 35) and 0 or ((roll < 70) and 1 or 2);
	local skipped = fair_csSkip > 0;
	local discarded = self.iNumCityStatesDiscarded;
	FairGamePlaceCSInRegion(self, cs, region);
	if skipped and self.iNumCityStatesDiscarded > discarded then
		-- nowhere deeper in: the game's own search from the rim
		self.iNumCityStatesDiscarded = discarded;
		fair_csSkip = 0;
		FairGamePlaceCSInRegion(self, cs, region);
	end
	fair_csSkip = 0;
end
------------------------------------------------------------------------------
-- 1.7 (user): cap the best starts, keep the variety. Within 3 tiles of a capital:
-- food bonus at most 4 (a capital on fresh water counts that as 1.5 of them; no
-- fresh water within 2 tiles allows 1 more); Wheat / Bananas / Deer (granary)
-- at most 3 within 4 tiles; at most 2 of the region's luxury + 1 other luxury.
-- Only removes, never adds; the furthest go first.
FAIR_CAP_FOOD = 4;
FAIR_CAP_FRESH_COST = 1.5;
FAIR_CAP_GRANARY = 3;
FAIR_CAP_REGIONAL_LUX = 2;
FAIR_CAP_OTHER_LUX = 1;
FAIR_GRANARY_RES = {"RESOURCE_WHEAT", "RESOURCE_BANANA", "RESOURCE_DEER"};
function FairCapStart(asp, region)
	local data = asp.startingPlots[region];
	if data == nil then return end
	FairLoadResourceKinds();
	local x, y = data[1], data[2];
	local capital = Map.GetPlot(x, y);
	local granary = {};
	for _, t in ipairs(FAIR_GRANARY_RES) do
		local row = GameInfo.Resources[t];
		if row ~= nil then granary[row.ID] = true end
	end
	local function Trim(list, keep)
		-- list of {plot, d}; remove the furthest beyond `keep`
		if #list <= keep then return 0 end
		for _, e in ipairs(list) do e.r = Map.Rand(1000, "BitMoreFairPangea - cap start") end
		table.sort(list, function(a, b) if a.d ~= b.d then return a.d < b.d end return a.r < b.r end);
		for k = keep + 1, #list do list[k].plot:SetResourceType(-1) end
		return #list - keep;
	end
	local function Collect(maxRing, test)
		local list = {};
		for ring = 1, maxRing do
			for _, plot in ipairs(FairPlotsInRings(x, y, ring, ring)) do
				local res = plot:GetResourceType(-1);
				if res ~= -1 and test(res) then list[#list + 1] = {plot = plot, d = ring} end
			end
		end
		return list;
	end
	local log = {region = region, x = x, y = y};
	log.granary = Trim(Collect(4, function(res) return granary[res] end), FAIR_CAP_GRANARY);
	local freshNear = capital:IsFreshWater();
	if not freshNear then
		for _, plot in ipairs(FairPlotsInRings(x, y, 1, 2)) do
			if plot:IsRiver() or plot:IsLake() or plot:GetFeatureType() == FeatureTypes.FEATURE_OASIS then freshNear = true; break end
		end
	end
	local budget = FAIR_CAP_FOOD + (freshNear and 0 or 1) - (capital:IsFreshWater() and FAIR_CAP_FRESH_COST or 0);
	log.foodMax = math.floor(budget);
	log.food = Trim(Collect(3, function(res) return fair_foodBonus[res] end), log.foodMax);
	local regional = asp.region_luxury_assignment and asp.region_luxury_assignment[region];
	log.regional = Trim(Collect(3, function(res) return fair_luxury[res] and res == regional end), FAIR_CAP_REGIONAL_LUX);
	log.otherLux = Trim(Collect(3, function(res) return fair_luxury[res] and res ~= regional end), FAIR_CAP_OTHER_LUX);
	table.insert(fair_capLog, log);
	print("BitMoreFairPangea: cap start", region, "food max", log.foodMax, "removed food", log.food,
		"granary", log.granary, "regional lux", log.regional, "other lux", log.otherLux);
end
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
		chosen = fits[1 + Map.Rand(table.maxn(fits), "BitMoreFairPangea - strategic spot")];
	elseif table.maxn(fixable) > 0 then
		local cheapest = {};
		for n, plot in ipairs(fixable) do
			if fixCost[n] == bestCost then table.insert(cheapest, plot) end
		end
		chosen = cheapest[1 + Map.Rand(table.maxn(cheapest), "BitMoreFairPangea - strategic spot")];
	elseif table.maxn(riverOnly) > 0 then
		chosen = riverOnly[1 + Map.Rand(table.maxn(riverOnly), "BitMoreFairPangea - strategic spot")];
	end
	if chosen == nil then
		print("BitMoreFairPangea WARNING: no room for resource", resID, "near start", x, y);
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
	FairEnsureResourceNear(asp, x, y, asp.iron_ID, iron_amt, 1, 3);
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
-- BitMoreFairPangea ADDITIONS
------------------------------------------------------------------------------
fair_startPlotDatabase = nil;	-- GLOBAL the AssignStartingPlots instance
fair_liftLog = {};				-- GLOBAL what the start lifts did, one entry per major start
fair_tweakCounts = nil;			-- GLOBAL what the terrain tweak did

FAIR_TUNDRA_HILLS_PERCENT = 6.5;	-- trial 6: user "tundra a tiny bit more hills and forest" (was 5)
--	-- share of flat tundra that becomes hills (user 11-16: hillier tundra; 11-17 toned down from 15)
FAIR_TUNDRA_SHEEP_PERCENT = 8;	-- share of free bare tundra hills that get Sheep (none next to another Sheep)
FAIR_TUNDRA_EMPTY_FOREST_PERCENT = 20;	-- trial 6: was 15
--	-- 11-17: toned down from 45	-- empty flat tundra (nothing on it or next to it): forest
FAIR_TUNDRA_FOREST_PERCENT = 8;	-- trial 6: was 6
--	-- 11-17: toned down from 20; share of bare tundra (flat or hills) that gets a forest
FAIR_TUNDRA_DEER_PERCENT = 5;	-- 11-17 "land about 10% worse": extras trimmed (hills 8->5, sheep 15->8, forest 10->6/25->15, deer 8->5, grass hills 1.5->0.5, cattle 12->4)	-- share of free tundra tiles that get Deer (none next to another Deer)
FAIR_GREEN_HILLS_PERCENT = 0.5;	-- share of flat grassland that becomes hills (1.2: grassland only, no jungle; user 11-16: halved from 3)
FAIR_GRASS_CATTLE_PERCENT = 4;	-- empty flat grassland (nothing on it or next to it, no river): Cattle
FAIR_WEAK_SHARE_PERCENT = 40;	-- weak start: this share (or more) of the land within 2 tiles is sparse
------------------------------------------------------------------------------
-- WHOLE MAP: a few more hills (mostly tundra)
------------------------------------------------------------------------------
function FairTundraDeer()
	-- Deer on free tundra tiles (flat, hills or forest), never two side by side,
	-- never on a start or city state tile.
	local deer = GameInfo.Resources["RESOURCE_DEER"];
	if deer == nil then return end
	local iW, iH = Map.GetGridSize();
	local function NextToDeer(plot)
		for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
			local adj = Map.PlotDirection(plot:GetX(), plot:GetY(), direction);
			if adj ~= nil and adj:GetResourceType(-1) == deer.ID then return true end
		end
		return false
	end
	local added = 0;
	for i = 0, iW * iH - 1 do
		local plot = Map.GetPlotByIndex(i);
		if plot:GetTerrainType() == TerrainTypes.TERRAIN_TUNDRA and not plot:IsWater() and not plot:IsMountain()
			and plot:GetResourceType(-1) == -1 and plot:GetImprovementType() == -1 and not plot:IsStartingPlot()
			and FairResourceFits(plot, deer.ID, false) and not NextToDeer(plot)
			and Map.Rand(100, "BitMoreFairPangea - tundra deer") < FAIR_TUNDRA_DEER_PERCENT then
			plot:SetResourceType(deer.ID, 1);
			added = added + 1;
		end
	end
	fair_tundraDeer = added;	-- GLOBAL, for logs and tests
	print("BitMoreFairPangea: Deer added in the tundra", added);

	-- Sheep on bare tundra hills (a hilly tundra city is worth settling).
	local sheep = GameInfo.Resources["RESOURCE_SHEEP"];
	local sheepAdded = 0;
	if sheep ~= nil then
		for i = 0, iW * iH - 1 do
			local plot = Map.GetPlotByIndex(i);
			if plot:GetTerrainType() == TerrainTypes.TERRAIN_TUNDRA and plot:GetPlotType() == PlotTypes.PLOT_HILLS
				and plot:GetFeatureType() == FeatureTypes.NO_FEATURE and FairFreeTile(plot)
				and not FairNextToResource(plot, sheep.ID)	-- the game puts Sheep on any open hill
				and Map.Rand(100, "BitMoreFairPangea - tundra sheep") < FAIR_TUNDRA_SHEEP_PERCENT then
				plot:SetResourceType(sheep.ID, 1);
				sheepAdded = sheepAdded + 1;
			end
		end
	end
	-- Empty flat tundra (no feature, river or resource; nothing next to it but more
	-- bare flat land): forest, so the vast empty tundra plains get production.
	local forest = GameInfo.Features["FEATURE_FOREST"];
	local emptyForest = 0;
	if forest ~= nil then
		for i = 0, iW * iH - 1 do
			local plot = Map.GetPlotByIndex(i);
			if plot:GetTerrainType() == TerrainTypes.TERRAIN_TUNDRA and plot:GetPlotType() == PlotTypes.PLOT_LAND
				and plot:GetFeatureType() == FeatureTypes.NO_FEATURE and FairFreeTile(plot) and not plot:IsRiver() then
				local empty = FairQuietTile(plot);
				if empty and Map.Rand(100, "BitMoreFairPangea - empty tundra forest") < FAIR_TUNDRA_EMPTY_FOREST_PERCENT then
					plot:SetFeatureType(forest.ID, -1);
					emptyForest = emptyForest + 1;
				end
			end
		end
	end
	-- Empty flat grassland (same test, no river): Cattle, never two side by side.
	local cattle = GameInfo.Resources["RESOURCE_COW"];
	local cattleAdded = 0;
	if cattle ~= nil then
		for i = 0, iW * iH - 1 do
			local plot = Map.GetPlotByIndex(i);
			if plot:GetTerrainType() == TerrainTypes.TERRAIN_GRASS and plot:GetPlotType() == PlotTypes.PLOT_LAND
				and plot:GetFeatureType() == FeatureTypes.NO_FEATURE and FairFreeTile(plot) and not plot:IsRiver()
				and FairResourceFits(plot, cattle.ID, false) then
				local empty = FairQuietTile(plot);
				if empty and Map.Rand(100, "BitMoreFairPangea - grassland cattle") < FAIR_GRASS_CATTLE_PERCENT then
					plot:SetResourceType(cattle.ID, 1);
					cattleAdded = cattleAdded + 1;
				end
			end
		end
	end
	fair_tundraSheep, fair_tundraEmptyForest, fair_grassCattle = sheepAdded, emptyForest, cattleAdded;	-- GLOBAL, for logs and tests
	print("BitMoreFairPangea: Sheep on tundra hills", sheepAdded, "; forest on empty tundra", emptyForest, "; Cattle on empty grassland", cattleAdded);
end
------------------------------------------------------------------------------
function FairQuietTile(plot)
	-- "Little around": at most 1 resource on the 6 neighbours, and at most 3
	-- neighbours with a forest / jungle / marsh, a hill, a mountain or water.
	local res, busy = 0, 0;
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
		local adj = Map.PlotDirection(plot:GetX(), plot:GetY(), direction);
		if adj ~= nil then
			if adj:GetResourceType(-1) ~= -1 then res = res + 1 end
			if adj:GetPlotType() ~= PlotTypes.PLOT_LAND or adj:GetFeatureType() ~= FeatureTypes.NO_FEATURE then busy = busy + 1 end
		end
	end
	return res <= 1 and busy <= 3;
end
------------------------------------------------------------------------------
function FairNextToResource(plot, resID)
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
		local adj = Map.PlotDirection(plot:GetX(), plot:GetY(), direction);
		if adj ~= nil and adj:GetResourceType(-1) == resID then return true end
	end
	return false
end
------------------------------------------------------------------------------
function FairExtraResources()
	-- option "Extra resources": Trimmed = the 11-17 trim (default); Full = the values before it.
	if true then	-- 1.6: always the full extras (option removed)
		FAIR_TUNDRA_SHEEP_PERCENT, FAIR_TUNDRA_DEER_PERCENT, FAIR_GRASS_CATTLE_PERCENT = 15, 8, 12;
	end
end
function FairTerrainTweak()
	FairExtraResources();
	-- Runs after terrain and features exist, before starts are chosen (so the
	-- start finder already sees the new hills). Only flat land changes; a forest
	-- or jungle on the tile stays. Never flood plains, oasis, marsh, ice, a natural
	-- wonder or a resource (none exist yet at this point, checked anyway).
	local iW, iH = Map.GetGridSize();
	local flatTundra, tundraHills, flatGreen, greenHills = 0, 0, 0, 0;
	for i = 0, iW * iH - 1 do
		local plot = Map.GetPlotByIndex(i);
		if plot:GetPlotType() == PlotTypes.PLOT_LAND and not plot:IsWater()
			and plot:GetResourceType(-1) == -1 and not plot:IsStartingPlot() then
			local terrain = plot:GetTerrainType();
			local feature = plot:GetFeatureType();
			local featureOK = (feature == FeatureTypes.NO_FEATURE or feature == FeatureTypes.FEATURE_FOREST
				or feature == FeatureTypes.FEATURE_JUNGLE);
			if featureOK then
				local percent = nil;
				if terrain == TerrainTypes.TERRAIN_TUNDRA then
					flatTundra = flatTundra + 1;
					percent = FAIR_TUNDRA_HILLS_PERCENT;
				elseif terrain == TerrainTypes.TERRAIN_GRASS and feature ~= FeatureTypes.FEATURE_JUNGLE then
					flatGreen = flatGreen + 1;
					percent = FAIR_GREEN_HILLS_PERCENT;
				end
				if percent ~= nil and Map.Rand(1000, "BitMoreFairPangea - hills tweak") < percent * 10 then
					plot:SetPlotType(PlotTypes.PLOT_HILLS, false, false);
					if terrain == TerrainTypes.TERRAIN_TUNDRA then
						tundraHills = tundraHills + 1;
					else
						greenHills = greenHills + 1;
					end
				end
			end
		end
	end
	-- Tundra stays tundra, but more of it gets forest (production, Deer can sit in it).
	local forest = GameInfo.Features["FEATURE_FOREST"];
	local tundraForest = 0;
	if forest ~= nil then
		for i = 0, iW * iH - 1 do
			local plot = Map.GetPlotByIndex(i);
			if not plot:IsWater() and not plot:IsMountain() and plot:GetTerrainType() == TerrainTypes.TERRAIN_TUNDRA
				and plot:GetFeatureType() == FeatureTypes.NO_FEATURE and plot:GetResourceType(-1) == -1 and not plot:IsStartingPlot()
				and Map.Rand(100, "BitMoreFairPangea - tundra forest") < FAIR_TUNDRA_FOREST_PERCENT then
				plot:SetFeatureType(forest.ID, -1);
				tundraForest = tundraForest + 1;
			end
		end
	end
	fair_tweakCounts = {flatTundra = flatTundra, tundraHills = tundraHills, flatGreen = flatGreen, greenHills = greenHills, tundraForest = tundraForest};
	print("BitMoreFairPangea: tundra -> forest", tundraForest);
	print("BitMoreFairPangea: flat tundra -> hills", tundraHills, "of", flatTundra,
		"; flat grassland/jungle -> hills", greenHills, "of", flatGreen);
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- START LIFTS
------------------------------------------------------------------------------
fair_foodBonus = nil;		-- resource ID -> true: bonus resources that give food (Stone and artifacts do not)
fair_luxury = nil;			-- resource ID -> true: luxuries
fair_plantationLux = nil;	-- resource ID -> true: luxuries improved by a Plantation ("calendar" luxuries)
FAIR_WEAK_PLANTATION_LUX = {RESOURCE_WINE = true, RESOURCE_COTTON = true, RESOURCE_INCENSE = true};	-- the "calendar" luxuries that count as a weak start
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
				-- only the weak grassland / plains plantation luxuries (user, 11-16):
				-- Citrus, Cocoa and the others are fine starts already
				if res ~= nil and fair_luxury[res.ID] and FAIR_WEAK_PLANTATION_LUX[res.Type] then
					fair_plantationLux[res.ID] = true;
				end
			end
		end
	else
		print("BitMoreFairPangea WARNING: no Improvement_ResourceTypes table, calendar check off");
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
-- Class jungle by its visible feature, so the plains underneath do not
-- turn a jungle capital into a plains capital. Count workable land in rings 1-2.
local function FairStartTerrain(x, y)
	local land, counts = 0, {plains = 0, grassland = 0, tundra = 0, jungle = 0};
	for _, plot in ipairs(FairPlotsInRings(x, y, 1, 2)) do
		if not plot:IsWater() and not plot:IsMountain() then
			land = land + 1;
			local t = plot:GetTerrainType();
			if plot:GetFeatureType() == FeatureTypes.FEATURE_JUNGLE then counts.jungle = counts.jungle + 1
			elseif t == TerrainTypes.TERRAIN_PLAINS then counts.plains = counts.plains + 1
			elseif t == TerrainTypes.TERRAIN_GRASS then counts.grassland = counts.grassland + 1
			elseif t == TerrainTypes.TERRAIN_TUNDRA then counts.tundra = counts.tundra + 1 end
		end
	end
	for _, kind in ipairs({"plains", "grassland", "tundra", "jungle"}) do
		if counts[kind] * 2 > land then return kind end
	end
	return "mixed";
end

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
		local k = 1 + Map.Rand(n, "BitMoreFairPangea - shuffle");
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
	local plot = best[1 + Map.Rand(table.maxn(best), "BitMoreFairPangea - start hill")];
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
function FairCapitalMountains(x, y)
	-- Returns how many mountains became hills.
	local mountains = {};
	for loop, plot in ipairs(FairPlotsInRings(x, y, 1, 4)) do
		if plot:IsMountain() and plot:GetFeatureType() == FeatureTypes.NO_FEATURE then	-- natural wonders stay
			local n = 0;
			for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
				local adj = Map.PlotDirection(plot:GetX(), plot:GetY(), direction);
				if adj ~= nil and adj:IsMountain() then n = n + 1 end
			end
			table.insert(mountains, {plot = plot, n = n, r = Map.Rand(1000, "BitMoreFairPangea - capital mountains")});
		end
	end
	local extra = table.maxn(mountains) - FAIR_CAPITAL_MOUNTAINS_MAX;
	if extra <= 0 then return 0 end
	table.sort(mountains, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.r < b.r end);
	for k = 1, extra do
		local plot = mountains[k].plot;
		-- the land under it: what most of its land neighbours are (tundra / plains / ...)
		local count, best, bestN = {}, TerrainTypes.TERRAIN_PLAINS, 0;
		for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
			local adj = Map.PlotDirection(plot:GetX(), plot:GetY(), direction);
			if adj ~= nil and not adj:IsWater() and not adj:IsMountain() then
				local t = adj:GetTerrainType();
				count[t] = (count[t] or 0) + 1;
				if count[t] > bestN then best, bestN = t, count[t] end
			end
		end
		plot:SetPlotType(PlotTypes.PLOT_HILLS, false, true);
		plot:SetTerrainType(best, false, true);
	end
	return extra;
end
------------------------------------------------------------------------------
-- Coastal capitals need production in the first ring. Prefer a hill on the
-- shoreline, then any adjacent land hill if the shoreline cannot take one.
local function FairCoastalHill(x, y)
	-- 1.7 (user): a coastal capital stands on a hill itself (city states crowd the coast).
	local capital = Map.GetPlot(x, y);
	if not capital:IsCoastalLand() then return false end
	if capital:GetPlotType() == PlotTypes.PLOT_HILLS then return false end
	if capital:GetPlotType() == PlotTypes.PLOT_LAND then
		capital:SetPlotType(PlotTypes.PLOT_HILLS, false, true);
		return true;
	end
	if true then return false end
	local ring = FairPlotsInRings(x, y, 1, 1);
	for _, shoreOnly in ipairs({true, false}) do
		local candidates, bestRank = {}, 99;
		for _, plot in ipairs(ring) do
			if not shoreOnly or plot:IsCoastalLand() then
				if plot:GetPlotType() == PlotTypes.PLOT_HILLS then return false end
				local rank = FairHillRank(plot);
				if rank and rank <= bestRank then
					if rank < bestRank then candidates, bestRank = {}, rank end
					candidates[#candidates + 1] = plot;
				end
			end
		end
		if #candidates > 0 then
			local p = candidates[1 + Map.Rand(#candidates, "Fair coastal hill")];
			p:SetPlotType(PlotTypes.PLOT_HILLS, false, true);
			return true;
		end
	end
	return false;
end

local FairHillFloor = {plains = 0, jungle = 1, grassland = 2, tundra = 2};

-- BNW can also force a first-ring hill during its early production check.
-- Skip just that placement on majority-plains starts; keep other normalization.
local FairGameNormalizeStart = AssignStartingPlots.NormalizeStartLocation;
function AssignStartingPlots:NormalizeStartLocation(region)
	local start = self.startingPlots[region];
	local x, y = start[1], start[2];
	local kind = FairStartTerrain(x, y);
	-- Reserve the minimum before luxuries, strategics or food occupy the last legal tile.
	FairCoastalHill(x, y);
	local target = FairHillFloor[kind] or 0;
	local hills = FairMeasureStart(x, y).hills;
	while hills < target do
		if not FairAddHill(x, y) then break end
		hills = hills + 1;
	end
	if kind ~= "plains" then
		return FairGameNormalizeStart(self, region);
	end
	local placeHill = self.AttemptToPlaceHillsAtPlot;
	self.AttemptToPlaceHillsAtPlot = function() return false end;
	FairGameNormalizeStart(self, region);
	self.AttemptToPlaceHillsAtPlot = placeHill;
end

function FairLiftStart(asp, region_number)
	local data = asp.startingPlots[region_number];
	if data == nil then return end
	local x, y = data[1], data[2];
	local m = FairMeasureStart(x, y);
	local log = {region = region_number, x = x, y = y, weak = m.weak, land = m.land, sparse = m.sparse,
		hillsBefore = m.hills, bonusBefore = m.bonus3, calendar = m.calendar,
		snow = 0, hills = 0, bonus = 0, calendarBonus = 0};
	local kind = FairStartTerrain(x, y);
	local hillsWanted = FairHillFloor[kind] or (m.weak and 2 or 0);
	log.terrain = kind;
	local bonusWanted = m.weak and 3 or 2;

	-- Hopeless start (user, 11-16: the floor, not a rewrite): weak, no fresh water
	-- at the capital and at most 1 hill. 2 flat tundra / desert tiles next to it
	-- become plains, and
	-- it wants 3 hills and 4 food bonus. (No Oasis: user, 11-16.)
	local capital = Map.GetPlot(x, y);
	log.hopeless = m.weak and not capital:IsFreshWater() and m.hills <= 1;
	log.plains = 0;
	if log.hopeless then
		if kind == "mixed" then hillsWanted = 3 end
		bonusWanted = 4;
		for ring = 1, 2 do
			local list = {};
			for loop, plot in ipairs(FairPlotsInRings(x, y, ring, ring)) do
				local t, f = plot:GetTerrainType(), plot:GetFeatureType();
				if plot:GetPlotType() == PlotTypes.PLOT_LAND and FairFreeTile(plot)
					and (t == TerrainTypes.TERRAIN_TUNDRA or (t == TerrainTypes.TERRAIN_DESERT and f ~= FeatureTypes.FEATURE_FLOOD_PLAINS and f ~= FeatureTypes.FEATURE_OASIS)) then
					table.insert(list, plot);
				end
			end
			for loop, plot in ipairs(FairShuffled(list)) do
				if log.plains >= 2 then break end
				plot:SetTerrainType(TerrainTypes.TERRAIN_PLAINS, false, true);
				log.plains = log.plains + 1;
			end
		end
	end

	-- Tundra start (user, 11-16; 11-17: no forced capital hill, 2 forests): the
	-- flat tundra around it is not bare: up to 3 bare flat tundra tiles within 2 get forest.
	local tundraLand, land2 = 0, 0;
	for loop, plot in ipairs(FairPlotsInRings(x, y, 1, 2)) do
		if not plot:IsWater() and not plot:IsMountain() then
			land2 = land2 + 1;
			if plot:GetTerrainType() == TerrainTypes.TERRAIN_TUNDRA then tundraLand = tundraLand + 1 end
		end
	end
	log.tundraStart = capital:GetTerrainType() == TerrainTypes.TERRAIN_TUNDRA or (land2 > 0 and tundraLand * 100 >= land2 * 40);
	log.capitalHill, log.tundraForest = 0, 0;
	if log.tundraStart then
		if false then	-- user 11-17: no guaranteed hill under the capital
			capital:SetPlotType(PlotTypes.PLOT_HILLS, false, true);
			log.capitalHill = 1;
		end
		local forest = GameInfo.Features["FEATURE_FOREST"];
		if forest ~= nil then
			local list = {};
			for loop, plot in ipairs(FairPlotsInRings(x, y, 1, 2)) do
				if plot:GetTerrainType() == TerrainTypes.TERRAIN_TUNDRA and plot:GetPlotType() == PlotTypes.PLOT_LAND
					and plot:GetFeatureType() == FeatureTypes.NO_FEATURE and FairFreeTile(plot) then
					table.insert(list, plot);
				end
			end
			for loop, plot in ipairs(FairShuffled(list)) do
				if log.tundraForest >= 2 then break end
				plot:SetFeatureType(forest.ID, -1);
				log.tundraForest = log.tundraForest + 1;
			end
		end
	end

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

	-- Too many mountains around the capital (no room to settle): the ones deepest
	-- inside a chain become hills, down to FAIR_CAPITAL_MOUNTAINS_MAX within 4 tiles.
	log.mountainsCut = FairCapitalMountains(x, y);

	-- Hills within 2 tiles.
	if FairCoastalHill(x, y) then log.hills = log.hills + 1 end
	log.hillsWanted = hillsWanted;
	local hills = FairMeasureStart(x, y).hills;
	while hills < hillsWanted do
		if not FairAddHill(x, y) then break end
		hills = hills + 1;
		log.hills = log.hills + 1;
	end

	-- Food bonus within 3 tiles (rings 1-2 first). Only with the "Capital food"
	-- option on "Extra food bonus" (user, 11-17: off by default).
	local foodOn = false;	-- 1.6: always the game's own capital food (option removed)
	local bonus = m.bonus3;
	local bonus2 = m.bonus2;
	while foodOn and bonus < bonusWanted do
		local placed = FairAddBonus(asp, x, y, 1, 2) or FairAddBonus(asp, x, y, 3, 3);
		if not placed then break end
		bonus = bonus + 1;
		log.bonus = log.bonus + 1;
	end

	-- Calendar luxuries and no food bonus within 2 tiles: one food bonus within 2.
	if foodOn and m.calendar then
		bonus2 = FairMeasureStart(x, y).bonus2;
		if bonus2 == 0 and FairAddBonus(asp, x, y, 1, 2) then
			log.calendarBonus = 1;
		end
	end

	table.insert(fair_liftLog, log);
	if log.snow + log.hills + log.bonus + log.calendarBonus + log.mountainsCut > 0 then
		print("BitMoreFairPangea: start", region_number, "at", x, y, m.weak and "(weak," or "(", m.sparse .. "/" .. m.land, "sparse)",
			"hills", m.hills, "+", log.hills, "food bonus", m.bonus3, "+", log.bonus,
			"calendar bonus +", log.calendarBonus, "snow->tundra", log.snow);
	else
		print("BitMoreFairPangea: start", region_number, "at", x, y, "passes, not touched");
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

	-- City states richer, so they are worth taking.
	FairCityStateBoost(self);

	-- Strategic balance once more, now that everything else is placed.
	if self.resource_setting == 5 then
		for region_number = 1, self.iNumCivs do
			FairEnsureCapitalStrategics(self, region_number);
		end
	end

	-- More Deer in the tundra (before the start lifts, so they count them).
	FairTundraDeer();

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
function FairCityStateBoost(asp)
	-- City states worth taking (user, 11-17): a city state either has fresh water
	-- or at least 3 resources within 2 tiles; one without fresh water is topped up
	-- to 3 with food bonus (Fish or land bonus). No Stone, luxuries or strategics.
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
	local log = {cs = 0, food = 0};
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
					if k ~= nil and d <= 2 then food = food + 1 end
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
			if csPlot:IsFreshWater() then food = 3 end	-- fresh water: left as the map made it
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
		end
	end
	print("City state boost: city states", log.cs, "food bonus +", log.food);
end
