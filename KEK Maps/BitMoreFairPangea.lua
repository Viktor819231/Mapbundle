------------------------------------------------------------------------------
--	FILE:	 BitMoreFairPangea.lua
--	AUTHOR:  KEK multiplayer community (2026), built on Firaxis' Pangaea.lua
--	         (Bob Thomas)
--	PURPOSE: The game's own Pangaea (same land, options, sizes, wrap), with
--	         fewer hopeless starts. NOT mirrored.
--	         1. Terrain, whole map, light: about 15% of flat tundra and about 4%
--	            of flat grassland / jungle becomes hills.
--	         2. Start lifts, only for starts that fail a check (a start that
--	            passes is not touched; luxuries are never added):
--	            - at least 1 hill within 2 tiles (weak start: 2);
--	            - at least 2 food bonus resources within 3 tiles (weak start: 3);
--	            - a start whose luxuries within 2 tiles are all plantation
--	              ("calendar") luxuries and has no food bonus within 2 tiles
--	              gets one food bonus within 2 tiles;
--	            - weak start (40%+ of the land within 2 tiles is flat tundra,
--	              snow or flat desert without flood plains): also up to 2 snow
--	              tiles within 2 tiles become tundra.
--	         0. Continent shape: a snaky continent (thin arms all over the map,
--	            big inland seas) is rolled again; ordinary peninsulas stay.
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
-- Continent shape: how snaky the biggest landmass may be (see FairStringiness).
FAIR_MAX_STRINGY = 3.6;	-- standard size (80 wide): round about 1-2, ordinary Pangaea 2.5-3.5, snaky 4+
FAIR_SHAPE_TRIES = 6;	-- snaky continents rolled again at most this often
------------------------------------------------------------------------------
function FairStringiness(areaID)
	-- Coast tiles of the continent compared with the coast of a round continent
	-- of the same size (a hex disk of N tiles has about sqrt(12 N) coast tiles):
	-- about 1 = round, higher = long thin arms, inland seas, many inlets.
	local iW, iH = Map.GetGridSize();
	local land, coast = 0, 0;
	for y = 0, iH - 1 do
		for x = 0, iW - 1 do
			local plot = Map.GetPlot(x, y);
			if plot:GetArea() == areaID and not plot:IsWater() then
				land = land + 1;
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
	return coast / math.sqrt(12 * math.max(1, land));
end
------------------------------------------------------------------------------
function GetMapScriptInfo()
	local world_age, temperature, rainfall, sea_level, resources = GetCoreMapOptions()
	-- Same list as Pangaea; Strategic Balance (5) is the default here.
	resources.DefaultValue = 5;
	return {
		Name = "KEK BitMoreFairPangea 1.1",
		Description = "The game's Pangaea with fewer hopeless starts: a few more hills (tundra most), weak capitals get a hill and food bonuses, Strategic Balance adds Coal and Aluminium near every capital.",
		IsAdvancedMap = false,
		IconIndex = 0,
		SortIndex = 2,
		CustomOptions = {world_age, temperature, rainfall, sea_level, resources},
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
	fair_shapeLog, fair_shapeRejects, fair_bestShape = "", 0, nil;
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
			-- BitMoreFair: a snaky continent (long thin arms, a big inland sea) is
			-- rolled again, up to FAIR_SHAPE_TRIES times; then the least snaky one
			-- seen is used. Ordinary peninsulas pass, so maps still differ.
			local stringy = FairStringiness(biggest_area:GetID());
			fair_shapeLog = (fair_shapeLog or "") .. string.format("%.2f ", stringy);
			if stringy <= FAIR_MAX_STRINGY * math.pow(self.iNumPlotsX / 80, 0.7) then	-- bigger maps are naturally more ragged
				done = true;
				iBiggestID = biggest_area:GetID();
			else
				fair_shapeRejects = (fair_shapeRejects or 0) + 1;
				if fair_bestShape == nil or stringy < fair_bestShape.score then
					local copy = {};
					for i = 0, self.iNumPlotsX * self.iNumPlotsY - 1 do copy[i] = self.plotTypes[i] end
					fair_bestShape = {score = stringy, frac = self.continentsFrac, threshold = iWaterThreshold, plots = copy};
				end
				if fair_shapeRejects >= FAIR_SHAPE_TRIES then
					local b = fair_bestShape;
					self.continentsFrac, iWaterThreshold = b.frac, b.threshold;
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

------------------------------------------------------------------------------
function GeneratePlotTypes()
	-- Plot generation customized to ensure enough land belongs to the Pangaea.
	print("Generating Plot Types (Lua Pangaea) ...");
	
	local fractal_world = PangaeaFractalWorld.Create();
	local plotTypes = fractal_world:GeneratePlotTypes();
	
	SetPlotTypes(plotTypes);
	GenerateCoasts();
end
------------------------------------------------------------------------------
function GenerateTerrain()
	
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

	-- BitMoreFairPangea: a few more hills, mostly in the tundra.
	FairTerrainTweak();
end
------------------------------------------------------------------------------
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
	start_plot_database:ChooseLocations()
	
	print("Normalizing start locations and assigning them to Players.");
	start_plot_database:BalanceAndAssign()

	print("Placing Natural Wonders.");
	start_plot_database:PlaceNaturalWonders()

	print("Placing Resources and City States.");
	start_plot_database:PlaceResourcesAndCityStates()
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

FAIR_TUNDRA_HILLS_PERCENT = 20;	-- share of flat tundra that becomes hills
FAIR_TUNDRA_FOREST_PERCENT = 20;	-- share of bare tundra (flat or hills) that gets a forest
FAIR_TUNDRA_DEER_PERCENT = 8;	-- share of free tundra tiles that get Deer (none next to another Deer)
FAIR_GREEN_HILLS_PERCENT = 4;	-- share of flat grassland / jungle that becomes hills
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
end
------------------------------------------------------------------------------
function FairTerrainTweak()
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
				elseif terrain == TerrainTypes.TERRAIN_GRASS or feature == FeatureTypes.FEATURE_JUNGLE then
					flatGreen = flatGreen + 1;
					percent = FAIR_GREEN_HILLS_PERCENT;
				end
				if percent ~= nil and Map.Rand(100, "BitMoreFairPangea - hills tweak") < percent then
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
