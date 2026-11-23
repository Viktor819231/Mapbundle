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
--	FILE:	 MirrorPangaea.lua
--	MAP:	 Mirror Map: Pangaea (KEK multiplayer community, 2026; replaces the
--	         earlier Mirror Pangaea that was built on the game's Pangaea.lua)
--	PURPOSE: One big oval-ish continent, cut in half by a mirror line: the east half is
--	         an exact mirror image of the west half. No divider - the two halves
--	         run into each other across a wide, open middle. The map wraps
--	         east-west; the back ends of the oval face each other across the
--	         ocean, where small islands make a coast path between the players
--	         who start on the coast there.
--	         Written from scratch (no game map script is used).
------------------------------------------------------------------------------
--	HOW THE MIRROR WORKS
--	Civ V rows are offset: odd rows sit half a hex further east. Flipping the
--	map about its vertical centre line is
--	    even rows:  x' = W - 1 - x        odd rows:  x' = W - 2 - x
--	which keeps neighbours neighbours. On a wrapped map the same flip also
--	flips about the seam (east edge = west edge). Odd-row plots at
--	x = (W - 2) / 2 (centre) and x = W - 1 (seam) are their own mirror image.
--	Everything is made on the west half and copied to the east half.
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- OPTIONS
------------------------------------------------------------------------------
OVAL_OPTIONS = {
	{key = "size", Name = "Map size",
		Values = {
			{"Normal", "The continent with a wide ocean around it."},
			{"Compact", "Less ocean around the continent; the back ends are closer across the sea."},
			{"Brawl", "Hardly any ocean: a thin ring of sea and a short crossing at the back ends. With Less land per player, the tightest map."},
		}, DefaultValue = 2},
	{key = "land", Name = "Land per player",
		Values = {
			{"Less (about 75 tiles)", "A tight map with more tension. Enemy capitals still keep 12 tiles apart."},
			{"Normal (about 90 tiles)", "The usual room for a multiplayer game."},
			{"More (about 105 tiles)", "More room to expand before borders meet."},
			{"Lots (about 125 tiles)", "A big continent."},
		}, DefaultValue = 2},
	{key = "symmetry", Name = "Other side",
		Values = {
			{"Rotated", "The other team's half is your half turned round (180 degrees): your north-west is their south-east. No mirror line in the middle."},
			{"Mirrored", "The other team's half is a left-right mirror image of yours."},
		}, DefaultValue = 1},
	{key = "shape", Name = "Coastline",
		Values = {
			{"Smooth oval", "A clean oval with small bays."},
			{"Normal", "An oval with bays, capes and a few peninsulas."},
			{"Rough", "Deep bays and long capes; the oval is still one piece."},
		}, DefaultValue = 2},
	{key = "islands", Name = "Islands across the ocean",
		Values = {
			{"Random", "Rolled each game: about 2 games in 3 a chain with a coast path (early boats can cross), otherwise scattered islands or open ocean. The number of islands and how rich the sea is are rolled too: sometimes the islands are worth a lot, sometimes little."},
			{"Chain (coast path)", "Small islands between the two back ends of the oval, close enough that early boats (coast only) can sail across."},
			{"Scattered", "A few islands in the ocean; crossing needs ocean-going ships."},
			{"None", "Open ocean between the back ends of the oval."},
		}, DefaultValue = 1},
	{key = "hills", Name = "Hills",
		Values = {
			{"Few", "About 12% of the land is hills."},
			{"Normal", "About 20% of the land is hills."},
			{"Many", "About 30% of the land is hills."},
		}, DefaultValue = 2},
	{key = "mountains", Name = "Mountains",
		Values = {
			{"None", "No mountains (natural wonders aside)."},
			{"Few", "About 2.5% of the land; small groups."},
			{"Normal", "About 4.5% of the land; groups of at most 3."},
			{"Many", "About 7% of the land; groups of at most 3."},
		}, DefaultValue = 3},
	{key = "forest", Name = "Forest and jungle",
		Values = {
			{"Little", "About 15% of the land."},
			{"Normal", "About 28% of the land."},
			{"Lots", "About 40% of the land."},
		}, DefaultValue = 2},
	{key = "climate", Name = "Climate",
		Values = {
			{"Temperate", "Mostly grassland and plains; little desert and tundra."},
			{"Mixed", "Grassland and plains, a desert belt and tundra at the far north and south."},
			{"Hot", "More desert and jungle, no tundra."},
		}, DefaultValue = 2},
	{key = "wrap", Name = "World wrap",
		Values = {
			{"Yes", "East and west edges meet. The back ends of the oval face each other across the ocean."},
			{"No", "Flat map: the back ends of the oval face the map edges."},
		}, DefaultValue = 1},
	{key = "middle", Name = "Middle of the map",
		Values = {
			{"Rich", "The middle is worth fighting for: extra luxuries, strategics and food on the centre line, rivers start in the middle."},
			{"Normal", "Bigger maps: as Rich. Duel and tiny: no centre-line extras, fewer rivers and resources in the middle, so nobody has to rush it."},
			{"Barren", "Almost a divider: a bare strip 2-3 tiles wide down the middle (flat, no forest, a few lone mountains, no resources); few resources and no river starts near it."},
		}, DefaultValue = 2},
};
oval_optIndex = {};
for n, def in ipairs(OVAL_OPTIONS) do oval_optIndex[def.key] = n end

function OvalOpt(key)
	local n = oval_optIndex[key];
	local v = nil;
	if Map ~= nil and Map.GetCustomOption ~= nil then v = Map.GetCustomOption(n) end
	if v == nil or v < 1 or v > #OVAL_OPTIONS[n].Values then v = OVAL_OPTIONS[n].DefaultValue end
	return v;
end
-- 11-16 (user): how much the middle holds. 1 rich, 2 a bit less, 3 barren.
-- Normal on big maps = rich; on duel / tiny it is the "less" level.
function OvalMiddleLevel()
	local m = OvalOpt("middle");
	if m == 1 then return 1 end
	if m == 3 then return 3 end
	local ws = (Map ~= nil and Map.GetWorldSize ~= nil) and Map.GetWorldSize() or 3;
	if ws <= 1 then return 2 end
	return 1;
end
------------------------------------------------------------------------------
function GetMapScriptInfo()
	local options = {};
	for n, def in ipairs(OVAL_OPTIONS) do
		table.insert(options, {Name = def.Name, Values = def.Values, DefaultValue = def.DefaultValue, SortPriority = n});
	end
	table.insert(options, CSQ_OptionDef());	-- always last (CSQ_Level reads the last option)
	return {
		Name = "Mirror Map: Pangaea 1.6",
		Description = "One big continent cut in half by a mirror line, one team per half. No divider: the halves run into each other across a wide middle. Resources spread evenly over the whole land. Wraps east-west: small islands across the ocean link the coastal starts at the back ends. Every capital gets Horses, Iron, Coal and Aluminium within 3 tiles.",
		IconAtlas = "WORLDTYPE_ATLAS_2",
		IconIndex = 0,
		SupportsSinglePlayer = true,
		SupportsMultiplayer = true,
		CustomOptions = options,
	};
end
------------------------------------------------------------------------------
function OvalCountMajors()
	local n = 0;
	local ok = pcall(function()
		for i = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
			local st = PreGame.GetSlotStatus(i);
			if st == SlotStatus.SS_TAKEN or st == SlotStatus.SS_COMPUTER then n = n + 1 end
		end
	end);
	if not ok then n = 0 end
	return n;
end
------------------------------------------------------------------------------
OVAL_LAND_PER_PLAYER = {75, 90, 105, 125};
OVAL_ASPECT = 1.45;		-- oval half-width / half-height (in tiles / rows)
OVAL_SPAN = 0.70;		-- share of the map width the oval covers (Map size option changes it)
OVAL_HEIGHT_SPAN = 0.76;	-- share of the map height the oval covers
function OvalSetSpans()
	-- Map size option: the less ocean, the more of the map the continent covers
	local sz = OvalOpt("size");
	OVAL_SPAN = ({0.70, 0.78, 0.86})[sz];
	OVAL_HEIGHT_SPAN = ({0.76, 0.82, 0.87})[sz];
end

function GetMapInitData(worldSize)
	-- The grid is sized from the number of players: the land per player stays
	-- the same whatever world size is picked (the world size gives the number
	-- of players when the lobby count is not known).
	local world = GameInfo.Worlds[worldSize];
	local players = OvalCountMajors();
	if players < 2 then players = (world and world.DefaultPlayers) or 8 end
	if players % 2 == 1 then players = players + 1 end
	local cs = (world and world.DefaultMinorCivs) or players * 2;
	-- free for all (no teams of 2+): every capital needs 12 tiles to every
	-- other, which takes more room than teams (teammates may be 7 apart)
	local perPlayer = OVAL_LAND_PER_PLAYER[OvalOpt("land")];
	local okT, teams = pcall(function()
		local seen, n, biggest = {}, 0, 0;
		local size = {};
		for i = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
			local st = PreGame.GetSlotStatus(i);
			if st == SlotStatus.SS_TAKEN or st == SlotStatus.SS_COMPUTER then
				local t = PreGame.GetTeam(i);
				size[t] = (size[t] or 0) + 1;
				if size[t] > biggest then biggest = size[t] end
			end
		end
		return biggest;
	end);
	if okT and teams ~= nil and teams <= 1 then perPlayer = perPlayer * 1.3 end
	-- the whole map's land: players x the option (city states live inside it)
	local land = players * perPlayer;
	-- 11-16 (user: duel too small, the city states must fit with room to spare):
	-- 2 players get 30% more land each plus about 25 tiles per city state.
	if players <= 2 then land = land * 1.3 + cs * 25 end
	OvalSetSpans();
	local area = land / ({0.92, 0.88, 0.78})[OvalOpt("shape")];	-- bays lose part of the oval (rough coast more)
	local a = math.sqrt(area * OVAL_ASPECT / math.pi);
	local b = a / OVAL_ASPECT;
	local width = math.floor(2 * a / OVAL_SPAN + 0.5);
	local height = math.floor(2 * b / OVAL_HEIGHT_SPAN + 0.5);
	if width < 28 then width = 28 end
	if height < 18 then height = 18 end
	if width % 2 == 1 then width = width + 1 end
	if height % 2 == 1 then height = height + 1 end	-- the 180 degree turn needs an even height
	return {Width = width, Height = height, WrapX = (OvalOpt("wrap") == 1)};
end

------------------------------------------------------------------------------
-- GEOMETRY
------------------------------------------------------------------------------
OVAL_WEST, OVAL_EAST, OVAL_AXIS, OVAL_LONE = 1, 2, 3, 4;
oW, oH, oN = 0, 0, 0;
oWrap = false;
oKind = {};		-- plot index -> kind
oTwin = {};		-- plot index -> twin index (itself on the axis, -1 lone)
oAxisDist = {};	-- distance of the hex centre from the centre line (hex widths)
oSeamDist = {};	-- distance from the seam / map edge (hex widths)
oNb = {};		-- plot index -> {six neighbour indices or -1}, NE E SE SW W NW

local EVEN_OFF = {{0, 1}, {1, 0}, {0, -1}, {-1, -1}, {-1, 0}, {-1, 1}};
local ODD_OFF  = {{1, 1}, {1, 0}, {1, -1}, {0, -1}, {-1, 0}, {0, 1}};

function OvalIdx(x, y)
	if y < 0 or y >= oH then return -1 end
	if x < 0 or x >= oW then
		if not oWrap then return -1 end
		x = x % oW;
	end
	return y * oW + x;
end
function OvalXY(i) return i % oW, math.floor(i / oW) end
function OvalCentre(i)
	-- hex centre in hex widths (x) and rows (y)
	local x, y = OvalXY(i);
	if y % 2 == 1 then return x + 0.5, y end
	return x, y;
end

function OvalInitGeometry()
	oW, oH = Map.GetGridSize();
	oN = oW * oH;
	oWrap = (Map.IsWrapX ~= nil and Map.IsWrapX()) and true or false;
	-- Rotated: the east half is the west half turned 180 degrees about the map
	-- centre: (x, y) -> (W-1-x, H-1-y). With an even height this keeps every
	-- neighbour a neighbour (checked below); no plot is its own twin.
	oRotate = (OvalOpt("symmetry") == 1) and (oH % 2 == 0);
	local axis = (oW - 1) / 2;
	for y = 0, oH - 1 do
		local odd = (y % 2 == 1);
		for x = 0, oW - 1 do
			local i = y * oW + x;
			local c = x; if odd then c = x + 0.5 end
			oAxisDist[i] = math.abs(c - axis);
			oSeamDist[i] = math.min(c + 0.5, (oW - 0.5) - c);
			local tx = oW - 1 - x; if odd then tx = oW - 2 - x end
			if oRotate then
				oTwin[i] = (oH - 1 - y) * oW + (oW - 1 - x);
				if x < oW / 2 then oKind[i] = OVAL_WEST else oKind[i] = OVAL_EAST end
			elseif tx < 0 then
				if oWrap then oTwin[i] = i; oKind[i] = OVAL_AXIS else oTwin[i] = -1; oKind[i] = OVAL_LONE end
			else
				oTwin[i] = y * oW + tx;
				if tx == x then oKind[i] = OVAL_AXIS
				elseif c < axis then oKind[i] = OVAL_WEST
				else oKind[i] = OVAL_EAST end
			end
			local nb = {};
			local off = odd and ODD_OFF or EVEN_OFF;
			for d = 1, 6 do nb[d] = OvalIdx(x + off[d][1], y + off[d][2]) end
			oNb[i] = nb;
		end
	end
	if oRotate then
		-- the turn must keep neighbours neighbours
		local bad = 0;
		for i = 0, oN - 1 do
			for d = 1, 6 do
				local j = oNb[i][d];
				if j >= 0 then
					local ok = false;
					for _, k in ipairs(oNb[oTwin[i]]) do if k == oTwin[j] then ok = true end end
					if not ok then bad = bad + 1 end
				end
			end
		end
		if bad > 0 then print("Mirror Map: Pangaea - rotation broke", bad, "neighbours; using the mirror"); oRotate = false; OvalInitGeometryMirror() end
	end
end
oRotate = false;
function OvalInitGeometryMirror()
	local keep = OvalOpt;
	OvalOpt = function(key) if key == "symmetry" then return 2 end return keep(key) end;
	OvalInitGeometry();
	OvalOpt = keep;
end

function OvalDist(i, j)
	-- hex distance, wrap aware
	local x1, y1 = OvalXY(i);
	local x2, y2 = OvalXY(j);
	local function D(ax, ay, bx, by)
		local q1 = ax - (ay - (ay % 2)) / 2;
		local q2 = bx - (by - (by % 2)) / 2;
		local dq, dr = q2 - q1, by - ay;
		return (math.abs(dq) + math.abs(dr) + math.abs(dq + dr)) / 2;
	end
	local d = D(x1, y1, x2, y2);
	if oWrap then
		d = math.min(d, D(x1, y1, x2 + oW, y2), D(x1, y1, x2 - oW, y2));
	end
	return d;
end

function OvalRing(i, minR, maxR)
	-- plot indices at distance minR..maxR from i
	local list = {};
	local x0, y0 = OvalXY(i);
	for dy = -maxR, maxR do
		for dx = -maxR - 1, maxR + 1 do
			local j = OvalIdx(x0 + dx, y0 + dy);
			if j >= 0 then
				local d = OvalDist(i, j);
				if d >= minR and d <= maxR then table.insert(list, j) end
			end
		end
	end
	-- the same plot can come twice on very small wrapped maps
	local seen, out = {}, {};
	for _, j in ipairs(list) do if not seen[j] then seen[j] = true; table.insert(out, j) end end
	return out;
end

function OvalIsWestOrAxis(i) return oKind[i] == OVAL_WEST or oKind[i] == OVAL_AXIS end

------------------------------------------------------------------------------
-- RANDOM NUMBERS AND NOISE (own value noise, seeded from Map.Rand)
------------------------------------------------------------------------------
function OvalRand(n) if n <= 1 then return 0 end return Map.Rand(n, "Mirror Oval") end
-- The game's Map.Rand takes at most 65535 (an unsigned short): ask for 32768.
function OvalRandF() return Map.Rand(32768, "Mirror Oval") / 32768 end
function OvalShuffle(t)
	for k = #t, 2, -1 do
		local j = OvalRand(k) + 1;
		t[k], t[j] = t[j], t[k];
	end
	return t;
end

function OvalNewNoise(cellsX, cellsY)
	-- Smooth value noise on a lattice of cellsX x cellsY cells over the map.
	-- Wraps in x, so the seam is seamless.
	local lat = {};
	for gy = 0, cellsY + 1 do
		lat[gy] = {};
		for gx = 0, cellsX - 1 do lat[gy][gx] = OvalRandF() end
	end
	return {cx = cellsX, cy = cellsY, lat = lat};
end
function OvalNoiseAt(nz, fx, fy)
	-- fx, fy in 0..1 of the map
	local gx = fx * nz.cx;
	local gy = fy * nz.cy;
	local x0 = math.floor(gx);
	local y0 = math.floor(gy);
	local tx, ty = gx - x0, gy - y0;
	tx = tx * tx * (3 - 2 * tx);
	ty = ty * ty * (3 - 2 * ty);
	local function L(x, y)
		if y < 0 then y = 0 end
		if y > nz.cy + 1 then y = nz.cy + 1 end
		return nz.lat[y][x % nz.cx];
	end
	local a = L(x0, y0) + (L(x0 + 1, y0) - L(x0, y0)) * tx;
	local b = L(x0, y0 + 1) + (L(x0 + 1, y0 + 1) - L(x0, y0 + 1)) * tx;
	return a + (b - a) * ty;
end
function OvalFractal(octaves, baseCells)
	-- a few layers of noise; returns a function(i) -> 0..1
	local layers = {};
	local cells = baseCells;
	for o = 1, octaves do
		local cy = math.max(2, math.floor(cells * oH / oW + 0.5));
		table.insert(layers, {nz = OvalNewNoise(cells, cy), w = 1 / (2 ^ (o - 1))});
		cells = cells * 2;
	end
	local cache = {};
	return function(i)
		local v = cache[i];
		if v ~= nil then return v end
		local cx, cy = OvalCentre(i);
		local fx, fy = cx / oW, cy / oH;
		local sum, wsum = 0, 0;
		for _, l in ipairs(layers) do
			sum = sum + OvalNoiseAt(l.nz, fx, fy) * l.w;
			wsum = wsum + l.w;
		end
		v = sum / wsum;
		cache[i] = v;
		return v;
	end
end
function OvalMirrorField(f)
	-- a field that has the same value on both twins (the west value)
	return function(i)
		if oKind[i] == OVAL_EAST then return f(oTwin[i]) end
		return f(i);
	end
end

------------------------------------------------------------------------------
-- PLOT DATA (kept in Lua tables, written to the map at the end of each step)
------------------------------------------------------------------------------
oPlot = {};		-- PlotTypes
oTerr = {};		-- TerrainTypes
oFeat = {};		-- FeatureTypes or -1
oRes = {};		-- resource id or -1
oResAmt = {};
oImp = {};		-- improvement or -1
oRiver = {};	-- list of {a, b, flow}: edge between neighbour hexes a and b

function OvalIsLand(i) return oPlot[i] ~= PlotTypes.PLOT_OCEAN end
function OvalIsWater(i) return oPlot[i] == PlotTypes.PLOT_OCEAN end
function OvalLandNbrs(i)
	local n = 0;
	for _, j in ipairs(oNb[i]) do if j >= 0 and OvalIsLand(j) then n = n + 1 end end
	return n;
end
function OvalIsCoastLand(i)
	if not OvalIsLand(i) then return false end
	for _, j in ipairs(oNb[i]) do if j >= 0 and OvalIsWater(j) then return true end end
	return false;
end

function OvalMirrorAll()
	-- copy every west plot onto its east twin
	for i = 0, oN - 1 do
		if oKind[i] == OVAL_EAST then
			local s = oTwin[i];
			oPlot[i], oTerr[i], oFeat[i], oRes[i], oResAmt[i], oImp[i] = oPlot[s], oTerr[s], oFeat[s], oRes[s], oResAmt[s], oImp[s];
		elseif oKind[i] == OVAL_LONE then
			oPlot[i], oTerr[i], oFeat[i], oRes[i], oResAmt[i], oImp[i] = PlotTypes.PLOT_OCEAN, TerrainTypes.TERRAIN_OCEAN, -1, -1, 0, -1;
		end
	end
end

------------------------------------------------------------------------------
-- 1. LAND: the oval
------------------------------------------------------------------------------
oCentreX, oCentreY, oA, oB = 0, 0, 0, 0;
oMain = {};		-- plot index -> true for the main continent

function OvalShapeValue(i, wobble, bump)
	-- < 1 inside the oval. Measured from the centre line (only west plots ask).
	local cx, cy = OvalCentre(i);
	local dx = ((oW - 1) / 2 - cx) / oA;
	local dy = (cy - oCentreY) / oB;
	-- slightly egg-shaped: the middle is a bit taller than the back ends
	local taper = 1 + 0.18 * dx * dx;
	local base = dx * dx + dy * dy * taper;
	-- calm in the middle, more and more ragged towards the edges
	local edge = 0.35 + 1.0 * base;
	return base + (wobble(i) + bump(i)) * edge;
end

function OvalGenerateLand()
	OvalSetSpans();
	local land = OVAL_LAND_PER_PLAYER[OvalOpt("land")];
	oA = (oW * OVAL_SPAN) / 2;
	oB = (oH * OVAL_HEIGHT_SPAN) / 2;
	oCentreY = (oH - 1) / 2;
	local shape = OvalOpt("shape");
	local amp = ({0.30, 0.55, 0.80})[shape];
	local bigAmp = ({0.14, 0.30, 0.44})[shape];
	local best, bestScore = nil, -1;
	for try = 1, 8 do
		local fine = OvalFractal(3, 7);
		local coarse = OvalFractal(2, 4);
		local wobble = function(i) return (fine(i) - 0.5) * amp end;
		local bump = function(i) return (coarse(i) - 0.5) * bigAmp * 2 end;
		for i = 0, oN - 1 do
			oPlot[i] = PlotTypes.PLOT_OCEAN;
			if OvalIsWestOrAxis(i) then
				local cx, cy = OvalCentre(i);
				local v = OvalShapeValue(i, wobble, bump);
				-- the open middle: the centre of the oval is always land
				local dxm = oAxisDist[i] / oA;
				local dym = math.abs(cy - oCentreY) / oB;
				if dxm < 0.30 and dym < 0.62 then v = math.min(v, 0.8) end
				if cy < 1.5 or cy > oH - 2.5 then v = 9 end	-- polar rows stay water
				if oSeamDist[i] < 2 then v = 9 end
				if v < 1 then oPlot[i] = PlotTypes.PLOT_LAND end
			end
		end
		OvalMirrorAll();
		OvalKeepMainLand();
		OvalFillHoles(6);
		-- score: a thick middle (land in the middle columns), no thin necks
		local mid, midLand = 0, 0;
		for i = 0, oN - 1 do
			if oAxisDist[i] <= oA * 0.25 then
				local _, cy = OvalCentre(i);
				if math.abs(cy - oCentreY) <= oB * 0.85 then
					mid = mid + 1;
					if OvalIsLand(i) then midLand = midLand + 1 end
				end
			end
		end
		local necks = OvalCountNecks();
		local score = midLand / math.max(1, mid) - necks * 0.03;
		if score > bestScore then
			bestScore = score;
			best = {};
			for i = 0, oN - 1 do best[i] = oPlot[i] end
		end
		if score >= 0.88 then break end
	end
	for i = 0, oN - 1 do oPlot[i] = best[i] end
	OvalCarveBays();
	OvalMirrorAll();
	OvalKeepMainLand();
	OvalTrimSpits();
	OvalMirrorAll();
	OvalKeepMainLand();
	oMain = {};
	for i = 0, oN - 1 do if OvalIsLand(i) then oMain[i] = true end end
end

function OvalRadial(i)
	-- 0 at the centre of the oval, about 1 on its rim
	local cx, cy = OvalCentre(i);
	local dx = oAxisDist[i] / oA;
	local dy = (cy - oCentreY) / oB;
	return math.sqrt(dx * dx + dy * dy);
end

function OvalCarveBays()
	-- Bays cut into the outer part of the oval (never the big centre): a water
	-- blob grows from the coast inwards, 5-14 tiles. West half; mirrored.
	local shape = OvalOpt("shape");
	local n = ({1, 2, 3})[shape] + OvalRand(({2, 3, 3})[shape]);
	local function Inner(i)
		local cx, cy = OvalCentre(i);
		return oAxisDist[i] / oA < 0.30 and math.abs(cy - oCentreY) / oB < 0.62;
	end
	local coast = {};
	for i = 0, oN - 1 do
		if oKind[i] == OVAL_WEST and OvalIsLand(i) and oAxisDist[i] > 3 and oSeamDist[i] > 3 and OvalRadial(i) > 0.7 then
			for _, j in ipairs(oNb[i]) do
				if j >= 0 and OvalIsWater(j) then table.insert(coast, i); break end
			end
		end
	end
	OvalShuffle(coast);
	local made, starts = 0, {};
	for _, s in ipairs(coast) do
		if made >= n then break end
		local far = true;
		for _, o in ipairs(starts) do if OvalDist(s, o) < 7 then far = false end end
		if far and OvalIsLand(s) then
			local size = 5 + OvalRand(10);
			local blob, inBlob = {s}, {[s] = true};
			for step = 1, size * 6 do
				if #blob >= size then break end
				-- pick the most inward of three random edge candidates
				local pick, pr = nil, nil;
				for t = 1, 3 do
					local from = blob[OvalRand(#blob) + 1];
					local j = oNb[from][OvalRand(6) + 1];
					if j >= 0 and not inBlob[j] and oKind[j] == OVAL_WEST and OvalIsLand(j) and oAxisDist[j] > 3
						and OvalRadial(j) > 0.45 and not Inner(j) then
						local r = OvalRadial(j);
						if pr == nil or r < pr then pick, pr = j, r end
					end
				end
				if pick then inBlob[pick] = true; table.insert(blob, pick) end
			end
			for _, j in ipairs(blob) do oPlot[j] = PlotTypes.PLOT_OCEAN end
			table.insert(starts, s);
			made = made + 1;
		end
	end
	oBaysLog = made;
end
oBaysLog = 0;

oCsIslands = {};	-- list of plot lists: islands made for city states
function OvalPlaceCsIslands()
	-- Some city states live on small islands offshore (more on the smaller
	-- land options): 3-5 tiles, 3-4 tiles of water off the oval. West; mirrored.
	oCsIslands = {};
	local cs = 0;
	for id = GameDefines.MAX_MAJOR_CIVS, GameDefines.MAX_CIV_PLAYERS - 1 do
		local p = Players[id];
		if p ~= nil and p:IsEverAlive() then cs = cs + 1 end
	end
	local share = ({0.5, 0.35, 0.25, 0.15})[OvalOpt("land")];
	local want = math.floor(math.floor(cs / 2) * share + 0.5);
	if want <= 0 then return end
	local dist = OvalDistToLandField(6);
	local cands = {};
	for i = 0, oN - 1 do
		if oKind[i] == OVAL_WEST and OvalIsWater(i) and dist[i] ~= nil and dist[i] >= 3 and dist[i] <= 4
			and oSeamDist[i] > 3 and not oForceCoast[i] then
			local _, cy = OvalCentre(i);
			if cy >= 3 and cy <= oH - 4 then table.insert(cands, i) end
		end
	end
	OvalShuffle(cands);
	for _, s in ipairs(cands) do
		if #oCsIslands >= want then break end
		local ok = true;
		for _, isl in ipairs(oCsIslands) do if OvalDist(s, isl[1]) < 7 then ok = false end end
		if ok then
			local blob = OvalGrowIsland(s, 3 + OvalRand(3), function(j)
				if oKind[j] ~= OVAL_WEST or not OvalIsWater(j) or oSeamDist[j] <= 2 then return false end
				for _, k in ipairs(OvalRing(j, 1, 2)) do if OvalIsLand(k) then return false end end
				return true;
			end);
			if blob and #blob >= 2 then
				for _, j in ipairs(blob) do oPlot[j] = PlotTypes.PLOT_LAND; oIsland[j] = true end
				table.insert(oCsIslands, blob);
			end
		end
	end
	OvalMirrorAll();
	for i = 0, oN - 1 do
		if oKind[i] == OVAL_EAST and oIsland[oTwin[i]] then oIsland[i] = true end
	end
end

function OvalComponents(isMember)
	-- connected groups of plots; returns list of {members}
	local seen, groups = {}, {};
	for i = 0, oN - 1 do
		if not seen[i] and isMember(i) then
			local g, stack = {}, {i};
			seen[i] = true;
			while #stack > 0 do
				local k = table.remove(stack);
				table.insert(g, k);
				for _, j in ipairs(oNb[k]) do
					if j >= 0 and not seen[j] and isMember(j) then seen[j] = true; table.insert(stack, j) end
				end
			end
			table.insert(groups, g);
		end
	end
	return groups;
end

function OvalKeepMainLand()
	-- only the biggest land piece stays
	local groups = OvalComponents(OvalIsLand);
	local big = nil;
	for _, g in ipairs(groups) do if big == nil or #g > #big then big = g end end
	for _, g in ipairs(groups) do
		if g ~= big then for _, i in ipairs(g) do oPlot[i] = PlotTypes.PLOT_OCEAN end end
	end
end

function OvalFillHoles(maxLake)
	-- water pieces not linked to the ocean: up to maxLake tiles stay as lakes
	-- (only 1-2 tile lakes are kept, by chance), bigger ones are filled
	local groups = OvalComponents(OvalIsWater);
	local ocean = nil;
	for _, g in ipairs(groups) do if ocean == nil or #g > #ocean then ocean = g end end
	for _, g in ipairs(groups) do
		if g ~= ocean then
			for _, i in ipairs(g) do oPlot[i] = PlotTypes.PLOT_LAND end
		end
	end
end

function OvalCountNecks()
	-- land plots with water on two opposite sides (a neck one tile wide)
	local n = 0;
	for i = 0, oN - 1 do
		if OvalIsLand(i) and oKind[i] ~= OVAL_EAST then
			local nb = oNb[i];
			for d = 1, 3 do
				local a, b = nb[d], nb[d + 3];
				if a >= 0 and b >= 0 and OvalIsWater(a) and OvalIsWater(b) then n = n + 1; break end
			end
		end
	end
	return n;
end

function OvalTrimSpits()
	-- land with only one land neighbour (a spit) becomes water; bays one tile
	-- wide (water with 5+ land neighbours) become land. Two passes.
	for pass = 1, 2 do
		local change = {};
		for i = 0, oN - 1 do
			if OvalIsWestOrAxis(i) then
				local ln = OvalLandNbrs(i);
				if OvalIsLand(i) and ln <= 1 then change[i] = PlotTypes.PLOT_OCEAN end
				if OvalIsWater(i) and ln >= 5 then change[i] = PlotTypes.PLOT_LAND end
			end
		end
		for i, t in pairs(change) do oPlot[i] = t end
		OvalMirrorAll();
	end
end

------------------------------------------------------------------------------
-- 2. ISLANDS in the ocean
------------------------------------------------------------------------------
oIsland = {};	-- plot index -> true for island land

function OvalGrowIsland(seed, size, allowed)
	-- grows a blob of land from seed (west plots); returns the plots or nil
	if not allowed(seed) then return nil end
	local blob, inBlob = {seed}, {[seed] = true};
	local tries = 0;
	while #blob < size and tries < size * 12 do
		tries = tries + 1;
		local from = blob[OvalRand(#blob) + 1];
		local j = oNb[from][OvalRand(6) + 1];
		if j >= 0 and not inBlob[j] and allowed(j) then
			inBlob[j] = true;
			table.insert(blob, j);
		end
	end
	return blob;
end

function OvalDistToLandField(maxD)
	-- distance (in tiles) of each plot from the nearest land, up to maxD
	local dist = {};
	local frontier = {};
	for i = 0, oN - 1 do
		if OvalIsLand(i) then dist[i] = 0; table.insert(frontier, i) end
	end
	for d = 1, maxD do
		local nextF = {};
		for _, k in ipairs(frontier) do
			for _, j in ipairs(oNb[k]) do
				if j >= 0 and dist[j] == nil then dist[j] = d; table.insert(nextF, j) end
			end
		end
		frontier = nextF;
	end
	return dist;
end

oIslandMode, oIslandAmount, oSeaRich = 1, 1.0, 2;
oSeaLog = "";
function OvalRollSea()
	-- The islands option. Random (default): 65% a chain with a coast path,
	-- 25% scattered islands, 10% open ocean; island amount and how rich the sea
	-- is (Fish, sea luxuries, what sits on the islands) are rolled as well.
	local opt = OvalOpt("islands");
	if opt == 1 then
		local r = OvalRand(100);
		if r < 65 then oIslandMode = 1 elseif r < 90 then oIslandMode = 2 else oIslandMode = 3 end
		oIslandAmount = ({0.6, 1.0, 1.5, 2.0})[OvalRand(4) + 1];
		local q = OvalRand(100);
		if q < 25 then oSeaRich = 1 elseif q < 70 then oSeaRich = 2 else oSeaRich = 3 end
	else
		oIslandMode = opt - 1;
		oIslandAmount = 1.0;
		oSeaRich = 2;
	end
	-- 11-16 (user): on a 2-player map no islands link the two sides.
	if OvalCountMajors() <= 2 and oIslandMode ~= 3 then
		oIslandMode = 3;
	end
	oSeaLog = ({"chain", "scattered", "none"})[oIslandMode] .. " x" .. oIslandAmount .. " sea " .. ({"poor", "normal", "rich"})[oSeaRich];
	print("Mirror Map: Pangaea - islands", oSeaLog);
end

function OvalIslandRiches(luxTypes)
	-- Every island (west half; the mirror copies it) may get a luxury, a
	-- strategic and Fish around it. Chances by the sea roll: poor / normal / rich.
	local function ID(t) return (GameInfoTypes and GameInfoTypes[t]) or GameInfo.Resources[t].ID end
	local luxChance = ({10, 35, 70})[oSeaRich];
	local stratChance = ({0, 15, 35})[oSeaRich];
	local fishWant = ({1, 2, 2})[oSeaRich];
	local strat = {{ID("RESOURCE_IRON"), 3, 5}, {ID("RESOURCE_HORSE"), 3, 5}, {ID("RESOURCE_OIL"), 4, 6}, {ID("RESOURCE_COAL"), 4, 6}, {ID("RESOURCE_ALUMINUM"), 3, 5}};
	local groups = OvalComponents(function(i) return oIsland[i] == true and oKind[i] == OVAL_WEST and OvalIsLand(i) end);
	for _, g in ipairs(groups) do
		local free = {};
		for _, i in ipairs(g) do
			if not OvalNoResHere(i) and oRes[i] == -1 and oImp[i] == -1 and not OvalIsWonder(i) then table.insert(free, i) end
		end
		OvalShuffle(free);
		local used = 0;
		if #free > used and #luxTypes > 0 and OvalRand(100) < luxChance then
			local i = free[used + 1];
			local lux = nil;
			for _, l in ipairs(OvalShuffle({unpack(luxTypes)})) do if OvalFits(i, l) then lux = l; break end end
			if lux == nil then
				lux = luxTypes[OvalRand(#luxTypes) + 1];
				if not OvalMakeFit(i, lux) then lux = nil end
			end
			if lux ~= nil then OvalSet(i, lux, 1); used = used + 1 end
		end
		if #free > used and OvalRand(100) < stratChance then
			local i = free[used + 1];
			local st = strat[OvalRand(#strat) + 1];
			if OvalFits(i, st[1]) or OvalMakeFit(i, st[1]) then
				OvalSet(i, st[1], st[2] + OvalRand(st[3] - st[2] + 1));
				used = used + 1;
			end
		end
		-- Fish in the water around the island
		local have = 0;
		local water = {};
		local seen = {};
		for _, i in ipairs(g) do
			for _, j in ipairs(oNb[i]) do
				if j >= 0 and not seen[j] and oKind[j] == OVAL_WEST and not OvalNoResHere(j) then
					seen[j] = true;
					if oRes[j] == OVAL_FISH then have = have + 1
					elseif OvalFits(j, OVAL_FISH) then table.insert(water, j) end
				end
			end
		end
		OvalShuffle(water);
		for _, j in ipairs(water) do
			if have >= fishWant then break end
			OvalSet(j, OVAL_FISH, 1);
			have = have + 1;
		end
	end
end

function OvalPlaceIslands()
	oIsland = {};
	oForceCoast = {};
	local mode = oIslandMode;
	if mode == 3 then return end
	local mainDist = OvalDistToLandField(6);
	local function OceanOK(j, gapToMain)
		if oKind[j] ~= OVAL_WEST then return false end
		local _, cy = OvalCentre(j);
		if cy < 2 or cy > oH - 3 then return false end
		if oSeamDist[j] < 0.9 and not oWrap then return false end
		return mainDist[j] == nil or mainDist[j] >= gapToMain;
	end
	if mode == 1 then
		-- Chain: stepping stones from the west back end of the oval to the seam.
		-- Islands of 2-5 tiles, at most 2 water tiles apart (so the water in
		-- between is all coast), the last one touching the seam, so it meets
		-- its mirror image there. One chain, or two (north and south of the tip).
		-- The back end of the oval: the main land plot nearest the seam
		-- (rows near the middle first).
		local tip, tipKey = nil, nil;
		for i = 0, oN - 1 do
			if oMain[i] and oKind[i] == OVAL_WEST then
				local _, cy = OvalCentre(i);
				local key = oSeamDist[i] + math.abs(cy - oCentreY) * 0.05;
				if tip == nil or key < tipKey then tip, tipKey = i, key end
			end
		end
		if tip == nil then return end
		-- 1-3 chains (more when the island roll is high), fanned out north/south
		local chains = 1 + OvalRand(3);
		if oIslandAmount >= 1.5 and chains < 3 then chains = chains + 1 end
		local _, tipY = OvalCentre(tip);
		local spread = 3 + OvalRand(3);
		for c = 1, chains do
			local rowAim = tipY + math.floor((c - (chains + 1) / 2) * spread + 0.5) + OvalRand(3) - 1;
			OvalBuildChain(tip, rowAim);
		end
	end
	-- a few scattered islets away from the main coast (both modes)
	local count = math.max(1, math.floor(oW * oH / 900));
	if mode == 2 then count = count + 2 end
	count = math.max(1, math.floor(count * oIslandAmount + 0.5));
	local cands = {};
	for i = 0, oN - 1 do
		if oKind[i] == OVAL_WEST and OvalIsWater(i) and (mainDist[i] == nil or mainDist[i] >= 4) then
			local _, cy = OvalCentre(i);
			if cy >= 3 and cy <= oH - 4 then table.insert(cands, i) end
		end
	end
	OvalShuffle(cands);
	local placed = 0;
	for _, s in ipairs(cands) do
		if placed >= count then break end
		local ok = true;
		for _, j in ipairs(OvalRing(s, 0, 3)) do if OvalIsLand(j) then ok = false; break end end
		if ok then
			local blob = OvalGrowIsland(s, 1 + OvalRand(4), function(j) return OceanOK(j, 3) and OvalIsWater(j) end);
			if blob then
				for _, j in ipairs(blob) do oPlot[j] = PlotTypes.PLOT_LAND; oIsland[j] = true end
				placed = placed + 1;
			end
		end
	end
	OvalMirrorAll();
	for i = 0, oN - 1 do
		if oKind[i] == OVAL_EAST and oIsland[oTwin[i]] then oIsland[i] = true end
	end
end

oForceCoast = {};	-- water plots that stay shallow (the coast path across the ocean)
function OvalBuildChain(tip, rowAim)
	-- Walk from the tip towards the seam; every water tile on the way stays
	-- shallow (a coast path for early boats), and an island is dropped every
	-- 3-5 tiles. The path ends on the seam, where it meets its mirror image.
	local cur = tip;
	local stepsMax = oW;
	local lastLand = tip;
	local nextGap = 3 + OvalRand(3);
	for step = 1, stepsMax do
		-- move one tile west (towards the seam), drifting to rowAim
		local x, y = OvalXY(cur);
		local nb = oNb[cur];
		local opts = {nb[5]};	-- W
		if y < rowAim then table.insert(opts, nb[6]) elseif y > rowAim then table.insert(opts, nb[4]) else table.insert(opts, nb[6]); table.insert(opts, nb[4]) end
		local nxt = opts[OvalRand(#opts) + 1];
		if nxt == nil or nxt < 0 then break end
		if oKind[nxt] ~= OVAL_WEST and oKind[nxt] ~= OVAL_AXIS then break end
		cur = nxt;
		if OvalIsWater(cur) then oForceCoast[cur] = true end
		local gap = OvalDist(cur, lastLand);
		local seamClose = oSeamDist[cur] <= 1.5;
		if OvalIsWater(cur) and (gap >= nextGap or seamClose) then
			nextGap = 3 + OvalRand(3);
			-- mostly 2-5 tiles, now and then a bigger one (6-9)
			local size = 2 + OvalRand(4);
			if OvalRand(100) < math.floor(12 * oIslandAmount) then size = 6 + OvalRand(4) end
			local blob = OvalGrowIsland(cur, size, function(j)
				if oKind[j] ~= OVAL_WEST and oKind[j] ~= OVAL_AXIS then return false end
				local _, cy = OvalCentre(j);
				if cy < 2 or cy > oH - 3 then return false end
				if oMain[j] then return false end
				-- keep two water tiles away from the oval (no land bridge)
				for _, k in ipairs(OvalRing(j, 1, 2)) do if oMain[k] then return false end end
				return true;
			end);
			if blob then
				for _, j in ipairs(blob) do
					oPlot[j] = PlotTypes.PLOT_LAND; oIsland[j] = true;
				end
				-- farthest-west tile of the blob is the next "last land"
				local far = blob[1];
				for _, j in ipairs(blob) do if oSeamDist[j] < oSeamDist[far] then far = j end end
				lastLand = far;
				cur = far;
			end
		end
		if oSeamDist[cur] <= 1.0 and OvalIsLand(cur) then break end
		if oSeamDist[cur] <= 0.6 then
			-- reached the seam on water: make this tile land so it meets its twin
			if not oRotate then oPlot[cur] = PlotTypes.PLOT_LAND; oIsland[cur] = true end
			break;
		end
	end
	if oRotate then
		-- turned map: a seam tile meets its copy only in the two middle rows, so
		-- the shallow path finishes along the seam to x = 0 on the even middle row
		local ty = math.floor(oH / 2);
		if ty % 2 == 1 then ty = ty - 1 end
		local target = ty * oW;
		local prev, seen, queue, head = {}, {[cur] = true}, {cur}, 1;
		while head <= #queue do
			local k = queue[head]; head = head + 1;
			if k == target then break end
			for _, j in ipairs(oNb[k]) do
				if j >= 0 and not seen[j] and oKind[j] == OVAL_WEST and not oMain[j] then
					seen[j] = true; prev[j] = k; table.insert(queue, j);
				end
			end
		end
		local k = target;
		while k ~= nil and k ~= cur do
			if OvalIsWater(k) then oForceCoast[k] = true end
			k = prev[k];
		end
		if OvalIsWater(target) then oPlot[target] = PlotTypes.PLOT_LAND; oIsland[target] = true end
	end
end

------------------------------------------------------------------------------
-- 3. HILLS AND MOUNTAINS
------------------------------------------------------------------------------
function OvalRelief()
	local hillShare = ({0.12, 0.20, 0.30})[OvalOpt("hills")];
	local mtnShare = ({0, 0.025, 0.045, 0.07})[OvalOpt("mountains")];
	local f = OvalFractal(3, 8);
	local ridge = OvalFractal(2, 5);
	local west = {};
	for i = 0, oN - 1 do
		if OvalIsWestOrAxis(i) and OvalIsLand(i) then table.insert(west, i) end
	end
	-- score: noise, more relief away from the coast and the middle
	local score = {};
	for _, i in ipairs(west) do
		local r = 1 - math.abs(ridge(i) - 0.5) * 2;	-- ridge lines
		score[i] = f(i) * 0.4 + r * 0.25 + OvalRandF() * 0.35;
	end
	table.sort(west, function(p, q) if score[p] ~= score[q] then return score[p] > score[q] end return p < q end);
	local nMtn = math.floor(#west * mtnShare + 0.5);
	local nHill = math.floor(#west * hillShare + 0.5);
	local placedM = 0;
	for _, i in ipairs(west) do
		if placedM >= nMtn then break end
		-- no mountains in the open middle, on islands or on the coast; groups of at most 3
		if oAxisDist[i] > oA * 0.16 and not oIsland[i] and not OvalIsCoastLand(i) and oKind[i] == OVAL_WEST then
			if OvalMountainGroupSize(i) < 3 then
				oPlot[i] = PlotTypes.PLOT_MOUNTAIN;
				placedM = placedM + 1;
			end
		end
	end
	local placedH = 0;
	for _, i in ipairs(west) do
		if placedH >= nHill then break end
		if oPlot[i] == PlotTypes.PLOT_LAND then
			oPlot[i] = PlotTypes.PLOT_HILLS;
			placedH = placedH + 1;
		end
	end
	-- islands are mostly hilly (about 60%), never mountains
	for i = 0, oN - 1 do
		if oIsland[i] and OvalIsWestOrAxis(i) and OvalIsLand(i) then
			if oPlot[i] == PlotTypes.PLOT_MOUNTAIN then oPlot[i] = PlotTypes.PLOT_HILLS
			elseif oPlot[i] == PlotTypes.PLOT_LAND and OvalRand(100) < 60 then oPlot[i] = PlotTypes.PLOT_HILLS end
		end
	end
	OvalMirrorAll();
end

function OvalMountainGroupSize(i)
	-- size of the mountain group i would join (counting the twins across the axis)
	local seen, stack, n = {[i] = true}, {i}, 0;
	while #stack > 0 do
		local k = table.remove(stack);
		if k ~= i then n = n + 1 end
		for _, j in ipairs(oNb[k]) do
			if j >= 0 and not seen[j] then
				local isM = oPlot[j] == PlotTypes.PLOT_MOUNTAIN;
				if not isM and oKind[j] == OVAL_EAST then isM = oPlot[oTwin[j]] == PlotTypes.PLOT_MOUNTAIN end
				if isM then seen[j] = true; table.insert(stack, j) end
			end
		end
	end
	return n;
end

------------------------------------------------------------------------------
-- 4. TERRAIN
------------------------------------------------------------------------------
function OvalGenerateTerrain()
	-- Patches of every land type, by share of the land (so every game has the
	-- same mix): desert patches where it is dry (warmer rows more), tundra
	-- patches towards the north and south ends (some further in), a little
	-- snow in the coldest tundra, the rest grassland where wet, plains where not.
	local climate = OvalOpt("climate");
	local T = TerrainTypes;
	local shares = ({
		{desert = 0.08, tundra = 0.08, snow = 0.000, grass = 0.55},	-- temperate
		{desert = 0.16, tundra = 0.13, snow = 0.015, grass = 0.48},	-- mixed
		{desert = 0.26, tundra = 0.00, snow = 0.000, grass = 0.40},	-- hot
	})[climate];
	local dry = OvalFractal(3, 6);
	local dryPatch = OvalFractal(2, 9);
	local cold = OvalFractal(2, 7);
	local wet = OvalFractal(3, 8);
	local land = {};
	for i = 0, oN - 1 do
		oTerr[i] = T.TERRAIN_OCEAN;
		if OvalIsWestOrAxis(i) and OvalIsLand(i) then table.insert(land, i) end
	end
	local function Lat(i)
		local _, cy = OvalCentre(i);
		return math.min(1, math.abs(cy - oCentreY) / math.max(1, oB));
	end
	local function TakeTop(list, score, n, terr)
		local sc = {};
		for _, i in ipairs(list) do sc[i] = score(i) end
		table.sort(list, function(p, q) if sc[p] ~= sc[q] then return sc[p] > sc[q] end return p < q end);
		local rest = {};
		for k, i in ipairs(list) do
			if k <= n then oTerr[i] = terr else table.insert(rest, i) end
		end
		return rest;
	end
	local n = #land;
	local rest = land;
	-- tundra first (cold ends), its coldest part snow
	local nT = math.floor(n * shares.tundra + 0.5);
	if nT > 0 then
		local tundraScore = function(i) return Lat(i) * 0.65 + cold(i) * 0.35 end;
		rest = TakeTop(rest, tundraScore, nT, T.TERRAIN_TUNDRA);
		local nS = math.floor(n * shares.snow + 0.5);
		if nS > 0 then
			local tundra = {};
			for _, i in ipairs(land) do
				if oTerr[i] == T.TERRAIN_TUNDRA and Lat(i) > 0.75 then table.insert(tundra, i) end
			end
			TakeTop(tundra, function(i) return Lat(i) + cold(i) * 0.3 end, math.min(nS, #tundra), T.TERRAIN_SNOW);
		end
	end
	-- desert patches
	local nD = math.floor(n * shares.desert + 0.5);
	local desertScore = function(i) return (1 - Lat(i)) * 0.25 + dry(i) * 0.45 + dryPatch(i) * 0.30 end;
	rest = TakeTop(rest, desertScore, nD, T.TERRAIN_DESERT);
	-- grassland where wet, plains elsewhere
	local nG = math.floor(#rest * shares.grass + 0.5);
	rest = TakeTop(rest, function(i) return wet(i) end, nG, T.TERRAIN_GRASS);
	for _, i in ipairs(rest) do oTerr[i] = T.TERRAIN_PLAINS end
	OvalMirrorAll();
end

function OvalWaterTerrain()
	-- coast next to land (and lakes), one random ring of extra shallows, ocean elsewhere
	local T = TerrainTypes;
	local lakes = OvalLakeSet();
	for i = 0, oN - 1 do
		if OvalIsWater(i) then
			local forced = oForceCoast[i] or (oTwin[i] >= 0 and oForceCoast[oTwin[i]]);
			if lakes[i] or forced or OvalLandNbrs(i) > 0 then oTerr[i] = T.TERRAIN_COAST else oTerr[i] = T.TERRAIN_OCEAN end
		end
	end
	local add = {};
	for i = 0, oN - 1 do
		if OvalIsWestOrAxis(i) and OvalIsWater(i) and oTerr[i] == T.TERRAIN_OCEAN then
			for _, j in ipairs(oNb[i]) do
				if j >= 0 and OvalIsWater(j) and oTerr[j] == T.TERRAIN_COAST and OvalLandNbrs(j) > 0 then
					if OvalRand(4) == 0 then add[i] = true end
					break;
				end
			end
		end
	end
	for i in pairs(add) do oTerr[i] = T.TERRAIN_COAST end
	OvalMirrorAll();
end

function OvalLakeSet()
	local set = {};
	local groups = OvalComponents(OvalIsWater);
	for _, g in ipairs(groups) do
		if #g < 10 then for _, i in ipairs(g) do set[i] = true end end
	end
	return set;
end

------------------------------------------------------------------------------
-- 5. LAKES (a few small ones, for fresh water)
------------------------------------------------------------------------------
function OvalAddLakes()
	local west = {};
	for i = 0, oN - 1 do
		local lakeOK = oAxisDist[i] > 2.5;
		if OvalMiddleLevel() >= 2 and oAxisDist[i] <= oA * 0.3 then lakeOK = false end
		if oKind[i] == OVAL_WEST and oMain[i] and oPlot[i] == PlotTypes.PLOT_LAND and lakeOK then
			local inland = true;
			for _, j in ipairs(OvalRing(i, 1, 2)) do if OvalIsWater(j) then inland = false; break end end
			if inland then table.insert(west, i) end
		end
	end
	OvalShuffle(west);
	local want = math.max(1, math.floor(#west / 140));
	local made = {};
	for _, i in ipairs(west) do
		if #made >= want then break end
		local ok = true;
		for _, m in ipairs(made) do if OvalDist(i, m) < 8 then ok = false end end
		if ok then
			oPlot[i] = PlotTypes.PLOT_OCEAN;
			table.insert(made, i);
			if OvalRand(2) == 0 then
				local j = oNb[i][OvalRand(6) + 1];
				if j >= 0 and oKind[j] == OVAL_WEST and oPlot[j] == PlotTypes.PLOT_LAND then oPlot[j] = PlotTypes.PLOT_OCEAN end
			end
		end
	end
	OvalMirrorAll();
end

------------------------------------------------------------------------------
-- 6. RIVERS (edges between two land hexes; west half, mirrored)
------------------------------------------------------------------------------
-- A river runs along hex corners. Each hex owns its north and south corner:
-- vertex id = 2 * plot + 0 (north) / 1 (south).
-- Corner neighbours (pointy-top hexes, nb order NE E SE SW W NW):
--   N corner of A: shared by A, NW(A), NE(A)
--   S corner of A: shared by A, SW(A), SE(A)
function OvalVertexEdges(v)
	-- returns list of {otherVertex, hexA, hexB}: the edge between hexA and hexB
	local i = math.floor(v / 2);
	local nb = oNb[i];
	local out = {};
	if v % 2 == 0 then
		local nw, ne = nb[6], nb[1];
		-- edge A|NW(A): other end = S corner of NW(A)
		if nw >= 0 then table.insert(out, {2 * nw + 1, i, nw}) end
		-- edge A|NE(A): other end = S corner of NE(A)
		if ne >= 0 then table.insert(out, {2 * ne + 1, i, ne}) end
		-- edge NW(A)|NE(A): other end = NE corner of NW(A) = S corner of NE(NW(A))
		if nw >= 0 and ne >= 0 then
			local up = oNb[nw][1];
			if up >= 0 then table.insert(out, {2 * up + 1, nw, ne}) end
		end
	else
		local sw, se = nb[4], nb[3];
		if sw >= 0 then table.insert(out, {2 * sw, i, sw}) end	-- A|SW(A): other end N corner of SW(A)
		if se >= 0 then table.insert(out, {2 * se, i, se}) end	-- A|SE(A): other end N corner of SE(A)
		if sw >= 0 and se >= 0 then
			local down = oNb[sw][3];	-- SE(SW(A))
			if down >= 0 then table.insert(out, {2 * down, sw, se}) end
		end
	end
	return out;
end

function OvalVertexHexes(v)
	local i = math.floor(v / 2);
	local nb = oNb[i];
	if v % 2 == 0 then return {i, nb[6], nb[1]} end
	return {i, nb[4], nb[3]};
end

function OvalDirOf(a, b)
	for d = 1, 6 do if oNb[a][d] == b then return d end end
	return nil;
end

function OvalEdgeFlow(a, b, fromV, toV)
	-- flow direction of a river on edge a|b moving from corner fromV to toV
	local F = FlowDirectionTypes;
	local d = OvalDirOf(a, b);
	-- normalise so 'p' owns the edge: E (2), SE (3) or SW (4) side of p
	local p, dir;
	if d == 2 or d == 3 or d == 4 then p, dir = a, d else p, dir = b, ((d + 2) % 6) + 1 end
	-- corners of p's own edges:
	--   E edge: NE corner (= S corner of NE(p)) .. SE corner (= N corner of SE(p))
	--   SE edge: SE corner (= N of SE(p)) .. S corner of p
	--   SW edge: S corner of p .. SW corner (= N of SW(p))
	local nb = oNb[p];
	if dir == 2 then
		local top = 2 * nb[1] + 1;
		if fromV == top then return F.FLOWDIRECTION_SOUTH end
		return F.FLOWDIRECTION_NORTH;
	elseif dir == 3 then
		local se = 2 * nb[3];
		if fromV == se then return F.FLOWDIRECTION_SOUTHWEST end
		return F.FLOWDIRECTION_NORTHEAST;
	else
		local s = 2 * p + 1;
		if fromV == s then return F.FLOWDIRECTION_NORTHWEST end
		return F.FLOWDIRECTION_SOUTHEAST;
	end
end

function OvalAddRivers()
	oRiver = {};
	local usedEdge = {};
	local usedVertex = {};
	local function EdgeKey(a, b) if a < b then return a .. ":" .. b end return b .. ":" .. a end
	local function VertexOK(v)
		local hs = OvalVertexHexes(v);
		for _, h in ipairs(hs) do if h < 0 then return false end end
		return true;
	end
	local function VertexWater(v)
		for _, h in ipairs(OvalVertexHexes(v)) do if h >= 0 and OvalIsWater(h) then return true end end
		return false;
	end
	local function VertexWest(v)
		-- all three hexes west, off the centre-line plots
		for _, h in ipairs(OvalVertexHexes(v)) do
			if h < 0 or oKind[h] ~= OVAL_WEST or oAxisDist[h] < 0.9 then return false end
		end
		return true;
	end
	-- distance of every hex from water, used to run rivers downhill
	local dW = {};
	local frontier = {};
	for i = 0, oN - 1 do if OvalIsWater(i) then dW[i] = 0; table.insert(frontier, i) end end
	local d = 0;
	while #frontier > 0 do
		d = d + 1;
		local nf = {};
		for _, k in ipairs(frontier) do
			for _, j in ipairs(oNb[k]) do if j >= 0 and dW[j] == nil then dW[j] = d; table.insert(nf, j) end end
		end
		frontier = nf;
	end
	local function VH(v)
		local s = 0;
		for _, h in ipairs(OvalVertexHexes(v)) do
			s = s + (dW[h] or 0);
			if oPlot[h] == PlotTypes.PLOT_HILLS then s = s + 0.6 end
			if oPlot[h] == PlotTypes.PLOT_MOUNTAIN then s = s + 1.2 end
		end
		return s;
	end
	-- sources: inland corners, far from water. Two rounds: first the middle of
	-- the oval (where the land is open and flat), then the rest, hills first.
	local westLand = 0;
	for i = 0, oN - 1 do if oKind[i] == OVAL_WEST and OvalIsLand(i) then westLand = westLand + 1 end end
	local midBand = oA * 0.45;
	local midSources, otherSources = {}, {};
	for i = 0, oN - 1 do
		if oKind[i] == OVAL_WEST and oMain[i] and OvalIsLand(i) and (dW[i] or 0) >= 3 then
			if oAxisDist[i] <= midBand then
				table.insert(midSources, 2 * i + OvalRand(2));
			elseif oPlot[i] ~= PlotTypes.PLOT_LAND or OvalRand(3) == 0 then
				table.insert(otherSources, 2 * i + OvalRand(2));
			end
		end
	end
	OvalShuffle(midSources);
	OvalShuffle(otherSources);
	local midWant = math.max(3, math.floor(westLand / 50));
	local lvl = OvalMiddleLevel();
	if lvl == 2 then midWant = 1 end
	if lvl == 3 then
		midWant = 0;
		-- other rivers may not start in the middle either
		local keep = {};
		for _, v in ipairs(otherSources) do if oAxisDist[math.floor(v / 2)] > oA * 0.3 then table.insert(keep, v) end end
		otherSources = keep;
	end
	local rounds = {
		{midSources, midWant},
		{otherSources, math.max(2, math.floor(westLand / 40))},
	};
	local made = 0;
	local riverHexes = {};
	-- Rivers across both sides: a river starts at a corner on the centre line
	-- (the top or bottom corner of a plot that is its own mirror image) and
	-- runs west to the coast; its mirror image runs east. Seen together it is
	-- one river crossing the continent from coast to coast, flowing outwards.
	-- One, two when there are 3+ players a side.
	local nCross = (math.max(#oWestPlayers, #oEastPlayers) >= 3) and 2 or 1;
	if OvalMiddleLevel() >= 2 then nCross = 0 end	-- 11-16: no river across the middle
	local axisTiles = {};
	for i = 0, oN - 1 do
		if oKind[i] == OVAL_AXIS and oMain[i] and OvalIsLand(i) and oSeamDist[i] > 2 then
			local _, cy = OvalCentre(i);
			if math.abs(cy - oCentreY) <= oB * 0.65 then table.insert(axisTiles, i) end
		end
	end
	OvalShuffle(axisTiles);
	if oRotate then
		-- turned map: the river starts at the very centre, on the edge between a
		-- plot and its own turned copy; its copy runs the other way. One river.
		axisTiles = {};
		local bestD = nil;
		for i = 0, oN - 1 do
			if oKind[i] == OVAL_WEST and OvalIsLand(i) and OvalDirOf(i, oTwin[i]) ~= nil then
				local cx, cy = OvalCentre(i);
				local d = math.abs(cx - (oW / 2 - 0.5)) + math.abs(cy - (oH - 1) / 2);
				if bestD == nil or d < bestD - 0.01 then axisTiles, bestD = {i}, d
				elseif math.abs(d - bestD) < 0.01 then table.insert(axisTiles, i) end
			end
		end
		-- then any west plot on the centre line (its copy starts on the line too)
		local more = {};
		for i = 0, oN - 1 do
			if oKind[i] == OVAL_WEST and oMain[i] and OvalIsLand(i) and oAxisDist[i] <= 0.6 then
				local _, cy = OvalCentre(i);
				if math.abs(cy - oCentreY) <= oB * 0.6 then table.insert(more, i) end
			end
		end
		OvalShuffle(more);
		for _, i in ipairs(more) do table.insert(axisTiles, i) end
		nCross = 1;
	end
	if OvalMiddleLevel() >= 2 then nCross = 0 end	-- 11-16: no river across the middle
	local function RotatedStart(A)
		-- the corner of the A | copy edge whose third plot is on the west side
		local tA = oTwin[A];
		local nb = oNb[A];
		local corners = {2 * A, 2 * A + 1};
		if nb[1] >= 0 then table.insert(corners, 2 * nb[1] + 1) end	-- NE corner
		if nb[6] >= 0 then table.insert(corners, 2 * nb[6] + 1) end	-- NW corner
		if nb[3] >= 0 then table.insert(corners, 2 * nb[3]) end		-- SE corner
		if nb[4] >= 0 then table.insert(corners, 2 * nb[4]) end		-- SW corner
		for _, v in ipairs(corners) do
			local hs = OvalVertexHexes(v);
			local hasA, hasT, third = false, false, nil;
			for _, h in ipairs(hs) do
				if h == A then hasA = true
				elseif h >= 0 and oKind[h] == OVAL_EAST and not hasT then hasT = true
				else third = h end
			end
			if hasA and hasT and third ~= nil and third >= 0 and oKind[third] == OVAL_WEST and OvalIsLand(third) and not VertexWater(v) then
				for _, e in ipairs(OvalVertexEdges(v)) do
					if (e[2] == A and e[3] == third) or (e[2] == third and e[3] == A) then return v, e end
				end
			end
		end
		return nil, nil;
	end
	local crossDone = {};
	local function VertexAD(v)
		local s, n = 0, 0;
		for _, h in ipairs(OvalVertexHexes(v)) do if h >= 0 then s = s + oAxisDist[h]; n = n + 1 end end
		return s / math.max(1, n);
	end
	for _, A in ipairs(axisTiles) do
		if #crossDone >= nCross then break end
		local far = true;
		for _, d in ipairs(crossDone) do if OvalDist(A, d) < 5 then far = false end end
		local corner = 2 * A + OvalRand(2);
		local rotFirst = nil;
		if oRotate then corner, rotFirst = RotatedStart(A) end
		if far and corner ~= nil and VertexOK(corner) and not VertexWater(corner) then
			-- first edge: A and its west neighbour at that corner
			local first = rotFirst;
			if not oRotate then
				for _, e in ipairs(OvalVertexEdges(corner)) do
					local a, b = e[2], e[3];
					if (a == A and oKind[b] == OVAL_WEST and OvalIsLand(b)) or (b == A and oKind[a] == OVAL_WEST and OvalIsLand(a)) then first = e end
				end
			end
			if first ~= nil then
				local path, onPath = {corner, first[1]}, {[corner] = true, [first[1]] = true};
				local cur = first[1];
				local reached = VertexWater(cur);
				for step = 1, 90 do
					if reached then break end
					local best, bestH = nil, nil;
					for _, e in ipairs(OvalVertexEdges(cur)) do
						local nv, a, b = e[1], e[2], e[3];
						if not onPath[nv] and VertexOK(nv) and oKind[a] == OVAL_WEST and oKind[b] == OVAL_WEST
							and OvalIsLand(a) and OvalIsLand(b) and not usedEdge[EdgeKey(a, b)] then
							local westOnly = true;
							for _, h in ipairs(OvalVertexHexes(nv)) do if oKind[h] ~= OVAL_WEST then westOnly = false end end
							if westOnly then
								local h = -VertexAD(nv) * 1.0 + VH(nv) * 0.25 + OvalRandF() * 0.9;
								if best == nil or h < bestH then best, bestH = e, h end
							end
						end
					end
					if best == nil then break end
					table.insert(path, best[1]);
					onPath[best[1]] = true;
					cur = best[1];
					if VertexWater(cur) then reached = true end
				end
				if reached and #path >= 5 then
					for k = 1, #path - 1 do
						local fromV, toV = path[k], path[k + 1];
						local edge = nil;
						for _, e in ipairs(OvalVertexEdges(fromV)) do if e[1] == toV then edge = e end end
						local a, b = edge[2], edge[3];
						usedEdge[EdgeKey(a, b)] = true;
						table.insert(oRiver, {a, b, OvalEdgeFlow(a, b, fromV, toV)});
					end
					for _, v in ipairs(path) do
						usedVertex[v] = true;
						for _, h in ipairs(OvalVertexHexes(v)) do if h >= 0 then riverHexes[h] = true end end
					end
					table.insert(crossDone, A);
				end
			end
		end
	end
	oCrossRivers = #crossDone;
	for _, round in ipairs(rounds) do
	local sources, want = round[1], made + round[2];
	for _, src in ipairs(sources) do
		if made >= want then break end
		-- keep sources apart from rivers already made, so they spread out
		local far = true;
		local srcHex = math.floor(src / 2);
		for _, h in ipairs(OvalRing(srcHex, 0, 2)) do if riverHexes[h] then far = false; break end end
		if far and VertexOK(src) and VertexWest(src) and not usedVertex[src] and not VertexWater(src) then
			-- walk downhill to the water
			local path, onPath = {src}, {[src] = true};
			local cur = src;
			local reached = false;
			for step = 1, 60 do
				local best, bestH = nil, nil;
				for _, e in ipairs(OvalVertexEdges(cur)) do
					local nv, a, b = e[1], e[2], e[3];
					if not onPath[nv] and VertexOK(nv) and OvalIsLand(a) and OvalIsLand(b) and not usedEdge[EdgeKey(a, b)]
						and oKind[a] == OVAL_WEST and oKind[b] == OVAL_WEST and oAxisDist[a] >= 0.9 and oAxisDist[b] >= 0.9 then
						local h = VH(nv) + OvalRandF() * 1.2;
						if usedVertex[nv] then h = h - 2 end	-- joining another river is fine
						if best == nil or h < bestH then best, bestH = e, h end
					end
				end
				if best == nil then break end
				table.insert(path, best[1]);
				onPath[best[1]] = true;
				cur = best[1];
				if VertexWater(cur) or usedVertex[cur] then reached = true; break end
			end
			if reached and #path >= 5 then
				for k = 1, #path - 1 do
					local fromV, toV = path[k], path[k + 1];
					local edge = nil;
					for _, e in ipairs(OvalVertexEdges(fromV)) do if e[1] == toV then edge = e end end
					local a, b = edge[2], edge[3];
					usedEdge[EdgeKey(a, b)] = true;
					table.insert(oRiver, {a, b, OvalEdgeFlow(a, b, fromV, toV)});
				end
				for _, v in ipairs(path) do
					usedVertex[v] = true;
					for _, h in ipairs(OvalVertexHexes(v)) do if h >= 0 then riverHexes[h] = true end end
				end
				made = made + 1;
			end
		end
	end
	end
end

function OvalMirrorFlow(flow)
	local F = FlowDirectionTypes;
	if oRotate then
		-- turned 180 degrees: every direction is reversed
		if flow == F.FLOWDIRECTION_NORTH then return F.FLOWDIRECTION_SOUTH end
		if flow == F.FLOWDIRECTION_SOUTH then return F.FLOWDIRECTION_NORTH end
		if flow == F.FLOWDIRECTION_NORTHEAST then return F.FLOWDIRECTION_SOUTHWEST end
		if flow == F.FLOWDIRECTION_SOUTHWEST then return F.FLOWDIRECTION_NORTHEAST end
		if flow == F.FLOWDIRECTION_NORTHWEST then return F.FLOWDIRECTION_SOUTHEAST end
		if flow == F.FLOWDIRECTION_SOUTHEAST then return F.FLOWDIRECTION_NORTHWEST end
		return flow;
	end
	if flow == F.FLOWDIRECTION_NORTHEAST then return F.FLOWDIRECTION_NORTHWEST end
	if flow == F.FLOWDIRECTION_NORTHWEST then return F.FLOWDIRECTION_NORTHEAST end
	if flow == F.FLOWDIRECTION_SOUTHEAST then return F.FLOWDIRECTION_SOUTHWEST end
	if flow == F.FLOWDIRECTION_SOUTHWEST then return F.FLOWDIRECTION_SOUTHEAST end
	return flow;
end

function OvalWriteRivers()
	-- clear every river, then set the west rivers and their mirror images
	for i = 0, oN - 1 do
		local p = Map.GetPlotByIndex(i);
		p:SetWOfRiver(false, FlowDirectionTypes.NO_FLOWDIRECTION);
		p:SetNWOfRiver(false, FlowDirectionTypes.NO_FLOWDIRECTION);
		p:SetNEOfRiver(false, FlowDirectionTypes.NO_FLOWDIRECTION);
	end
	local function SetEdge(a, b, flow)
		local d = OvalDirOf(a, b);
		local p, dir = a, d;
		if d == 1 or d == 5 or d == 6 then p, dir = b, ((d + 2) % 6) + 1 end
		local plot = Map.GetPlotByIndex(p);
		if dir == 2 then plot:SetWOfRiver(true, flow)
		elseif dir == 3 then plot:SetNWOfRiver(true, flow)
		else plot:SetNEOfRiver(true, flow) end
	end
	oRiverSide = {};
	for _, r in ipairs(oRiver) do
		SetEdge(r[1], r[2], r[3]);
		SetEdge(oTwin[r[1]], oTwin[r[2]], OvalMirrorFlow(r[3]));
		oRiverSide[r[1]] = true; oRiverSide[r[2]] = true;
		oRiverSide[oTwin[r[1]]] = true; oRiverSide[oTwin[r[2]]] = true;
	end
end
oRiverSide = {};

------------------------------------------------------------------------------
-- 7. FEATURES
------------------------------------------------------------------------------
function OvalAddFeatures()
	local Fe = FeatureTypes;
	local T = TerrainTypes;
	local share = ({0.15, 0.28, 0.40})[OvalOpt("forest")];
	local f = OvalFractal(3, 9);
	local jung = OvalFractal(2, 6);
	local land = {};
	for i = 0, oN - 1 do
		oFeat[i] = -1;
		if OvalIsWestOrAxis(i) and OvalIsLand(i) and oPlot[i] ~= PlotTypes.PLOT_MOUNTAIN then table.insert(land, i) end
	end
	-- flood plains on desert by rivers, oasis in desert, marsh on wet flat grass
	for _, i in ipairs(land) do
		if oTerr[i] == T.TERRAIN_DESERT and oPlot[i] == PlotTypes.PLOT_LAND and oRiverSide[i] then
			oFeat[i] = Fe.FEATURE_FLOOD_PLAINS;
		end
	end
	local nwood = math.floor(#land * share + 0.5);
	local cand = {};
	for _, i in ipairs(land) do
		if oFeat[i] == -1 and oTerr[i] ~= T.TERRAIN_DESERT and oTerr[i] ~= T.TERRAIN_SNOW then table.insert(cand, i) end
	end
	local sc = {};
	for _, i in ipairs(cand) do sc[i] = f(i) + OvalRandF() * 0.45 end
	table.sort(cand, function(p, q) if sc[p] ~= sc[q] then return sc[p] > sc[q] end return p < q end);
	for n = 1, math.min(nwood, #cand) do
		local i = cand[n];
		local _, cy = OvalCentre(i);
		local lat = math.abs(cy - oCentreY) / math.max(1, oB);
		local hot = lat < 0.38 and jung(i) > 0.52 and oTerr[i] ~= T.TERRAIN_TUNDRA;
		if OvalOpt("climate") == 1 then hot = hot and jung(i) > 0.62 end
		if hot then
			oFeat[i] = Fe.FEATURE_JUNGLE;
			if oTerr[i] == T.TERRAIN_GRASS then oTerr[i] = T.TERRAIN_PLAINS end
		else
			oFeat[i] = Fe.FEATURE_FOREST;
		end
	end
	for _, i in ipairs(land) do
		if oFeat[i] == -1 and oPlot[i] == PlotTypes.PLOT_LAND then
			if oTerr[i] == T.TERRAIN_GRASS and OvalRand(40) == 0 then oFeat[i] = Fe.FEATURE_MARSH end
			if oTerr[i] == T.TERRAIN_DESERT and oFeat[i] == -1 and OvalRand(14) == 0 and not oRiverSide[i] then oFeat[i] = Fe.FEATURE_OASIS end
		end
	end
	-- ice on the polar rows of the ocean
	for i = 0, oN - 1 do
		if OvalIsWestOrAxis(i) and OvalIsWater(i) then
			local _, y = OvalXY(i);
			if (y == 0 or y == oH - 1) and OvalRand(3) > 0 then oFeat[i] = Fe.FEATURE_ICE
			elseif (y == 1 or y == oH - 2) and OvalRand(4) == 0 and oTerr[i] == T.TERRAIN_OCEAN then oFeat[i] = Fe.FEATURE_ICE end
		end
	end
	OvalMirrorAll();
end

------------------------------------------------------------------------------
-- 8. PLAYERS AND SIDES
------------------------------------------------------------------------------
oWestPlayers, oEastPlayers = {}, {};
oStarts = {};		-- west start plot per pair number
oCapitals = {};	-- all capital plots (both sides)

function OvalSplitPlayers()
	local majors = {};
	for id = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
		local p = Players[id];
		if p ~= nil and p:IsEverAlive() then table.insert(majors, id) end
	end
	local teams, order = {}, {};
	for _, id in ipairs(majors) do
		local t = Players[id]:GetTeam();
		if teams[t] == nil then teams[t] = {}; table.insert(order, t) end
		table.insert(teams[t], id);
	end
	oWestPlayers, oEastPlayers = {}, {};
	if #order == 2 then
		-- team vs team: one team per side (which side is random)
		local a, b = teams[order[1]], teams[order[2]];
		if OvalRand(2) == 0 then a, b = b, a end
		oWestPlayers, oEastPlayers = a, b;
	else
		-- teams never split; biggest teams first, to the side with fewer players
		local list = {};
		for _, t in ipairs(order) do table.insert(list, teams[t]) end
		table.sort(list, function(p, q) if #p ~= #q then return #p > #q end return p[1] < q[1] end);
		for _, members in ipairs(list) do
			local side = (#oWestPlayers <= #oEastPlayers) and oWestPlayers or oEastPlayers;
			if #oWestPlayers == #oEastPlayers and OvalRand(2) == 0 then side = oEastPlayers end
			for _, id in ipairs(members) do table.insert(side, id) end
		end
	end
end

function OvalStartScore(i)
	-- how good a city site is (west plots); bad = -1
	if not oMain[i] or not OvalIsLand(i) or oPlot[i] == PlotTypes.PLOT_MOUNTAIN then return -1 end
	if oKind[i] ~= OVAL_WEST or oAxisDist[i] < 3 then return -1 end
	local T = TerrainTypes;
	local s = 0;
	for _, j in ipairs(OvalRing(i, 1, 2)) do
		if OvalIsLand(j) then
			local t = oTerr[j];
			if oPlot[j] == PlotTypes.PLOT_MOUNTAIN then s = s - 0.5
			elseif t == T.TERRAIN_GRASS or t == T.TERRAIN_PLAINS then s = s + 2
			elseif t == T.TERRAIN_TUNDRA then s = s + 0.3
			elseif t == T.TERRAIN_SNOW then s = s - 1.5
			elseif t == T.TERRAIN_DESERT then s = s + (oFeat[j] == FeatureTypes.FEATURE_FLOOD_PLAINS and 2 or 0.3) end
			if oPlot[j] == PlotTypes.PLOT_HILLS then s = s + 0.5 end
		else
			s = s + 0.9;
		end
	end
	if oRiverSide[i] then s = s + 4 end
	if oPlot[i] == PlotTypes.PLOT_HILLS then s = s + 3 end
	-- the cold far north and south ends make poor capitals
	local _, cy = OvalCentre(i);
	local lat = math.abs(cy - oCentreY) / math.max(1, oB);
	if lat > 0.7 then s = s - (lat - 0.7) * 40 end
	return math.max(0, s);
end

------------------------------------------------------------------------------
-- START BIAS (as the game's Pangaea: coast, river, terrain the civ likes / avoids)
------------------------------------------------------------------------------
oPairBias = {};		-- pair number -> {ocean = n, river = n, prio = {region = n}, avoid = {region = n}}
oBiasOff = false;

function OvalCivBias(id)
	local b = {ocean = 0, river = 0, prio = {}, avoid = {}};
	if id == nil or Players[id] == nil then return b end
	pcall(function()
		local civ = GameInfo.Civilizations[Players[id]:GetCivilizationType()];
		if civ == nil then return end
		local t = civ.Type;
		for row in GameInfo.Civilization_Start_Along_Ocean{CivilizationType = t} do if row.StartAlongOcean then b.ocean = 1 end end
		for row in GameInfo.Civilization_Start_Along_River{CivilizationType = t} do if row.StartAlongRiver then b.river = 1 end end
		for row in GameInfo.Civilization_Start_Region_Priority{CivilizationType = t} do b.prio[row.RegionType] = 1 end
		for row in GameInfo.Civilization_Start_Region_Avoid{CivilizationType = t} do b.avoid[row.RegionType] = 1 end
	end);
	return b;
end

function OvalSetupBias()
	-- both civs of a mirror pair count (they get mirror-image starts)
	oPairBias = {};
	oBiasOff = false;
	local ok, v = pcall(function() return Game.GetCustomOption("GAMEOPTION_DISABLE_START_BIAS") end);
	if ok and v ~= nil and v ~= 0 and v ~= false then oBiasOff = true end
	local k = math.max(#oWestPlayers, #oEastPlayers);
	for c = 1, k do
		local a, b = OvalCivBias(oWestPlayers[c]), OvalCivBias(oEastPlayers[c]);
		local m = {ocean = a.ocean + b.ocean, river = a.river + b.river, prio = {}, avoid = {}};
		if oBiasOff then m.ocean, m.river = 0, 0 end
		-- a pair with no coast bias rolls: 55% it must start inland, else anywhere
		-- (so most games have inland players, sometimes several)
		m.inland = (m.ocean == 0) and (OvalRand(100) < 55);
		for r in pairs(a.prio) do m.prio[r] = (m.prio[r] or 0) + 1 end
		for r in pairs(b.prio) do m.prio[r] = (m.prio[r] or 0) + 1 end
		for r in pairs(a.avoid) do m.avoid[r] = (m.avoid[r] or 0) + 1 end
		for r in pairs(b.avoid) do m.avoid[r] = (m.avoid[r] or 0) + 1 end
		oPairBias[c] = m;
		local function CivName(id)
			if id == nil then return "-" end
			local ok, t = pcall(function() return GameInfo.Civilizations[Players[id]:GetCivilizationType()].Type end);
			return (ok and t) and (tostring(t):gsub("CIVILIZATION_", "")) or ("civ?" .. tostring(id));
		end
		print("Mirror Map: Pangaea - pair", c, CivName(oWestPlayers[c]), CivName(oEastPlayers[c]),
			"coast bias", m.ocean, "inland roll", tostring(m.inland), oBiasOff and "(start bias off)" or "");
	end
end

function OvalRegionMatch(region, j)
	local T, Fe = TerrainTypes, FeatureTypes;
	if not OvalIsLand(j) then return false end
	if region == "REGION_TUNDRA" then return oTerr[j] == T.TERRAIN_TUNDRA or oTerr[j] == T.TERRAIN_SNOW end
	if region == "REGION_DESERT" then return oTerr[j] == T.TERRAIN_DESERT end
	if region == "REGION_JUNGLE" then return oFeat[j] == Fe.FEATURE_JUNGLE end
	if region == "REGION_FOREST" then return oFeat[j] == Fe.FEATURE_FOREST end
	if region == "REGION_HILLS" then return oPlot[j] == PlotTypes.PLOT_HILLS end
	if region == "REGION_PLAINS" then return oTerr[j] == T.TERRAIN_PLAINS end
	if region == "REGION_GRASSLAND" then return oTerr[j] == T.TERRAIN_GRASS end
	return false;
end

function OvalOnSea(i)
	for _, j in ipairs(oNb[i]) do
		if j >= 0 and OvalIsWater(j) and not oLakeAtStart[j] then return true end
	end
	return false;
end
oLakeAtStart = {};

function OvalBiasScore(c, i)
	-- extra start score for pair c at plot i
	local b = oPairBias[c];
	if b == nil then return 0 end
	local s = 0;
	if b.inland then
		-- inland pair: never next to the sea, better 2+ tiles from it
		if OvalOnSea(i) then return -30 end
		for _, j in ipairs(OvalRing(i, 2, 2)) do
			if OvalIsWater(j) and not oLakeAtStart[j] then s = s - 3; break end
		end
	end
	if oBiasOff then return s end
	if b.ocean > 0 then s = s + (OvalOnSea(i) and 14 or -6) * b.ocean end
	if b.river > 0 and oRiverSide[i] then s = s + 8 * b.river end
	if next(b.prio) ~= nil or next(b.avoid) ~= nil then
		for _, j in ipairs(OvalRing(i, 1, 3)) do
			for r, n in pairs(b.prio) do if OvalRegionMatch(r, j) then s = s + 1.2 * n end end
			for r, n in pairs(b.avoid) do if OvalRegionMatch(r, j) then s = s - 1.0 * n end end
		end
	end
	return s;
end

function OvalOrderCentresByBias(land, cent)
	-- give each pair the centre that suits it best: pairs with the strongest
	-- bias choose first (coast lovers, then terrain, then river)
	local k = #cent;
	local potential = {};	-- [c][centre] = best bias score near that centre
	for c = 1, k do
		potential[c] = {};
		for e = 1, k do
			local best = -999;
			for _, i in ipairs(land) do
				local cx, cy = OvalCentre(i);
				if math.abs(cx - cent[e][1]) + math.abs(cy - cent[e][2]) <= 7 then
					local v = OvalBiasScore(c, i);
					if v > best then best = v end
				end
			end
			potential[c][e] = best;
		end
	end
	local order = {};
	for c = 1, k do
		local b = oPairBias[c];
		local strength = 0;
		if b then
			strength = b.ocean * 10 + b.river * 3 + (b.inland and 8 or 0);
			for _, n in pairs(b.prio) do strength = strength + 5 * n end
			for _, n in pairs(b.avoid) do strength = strength + 2 * n end
		end
		table.insert(order, {c = c, s = strength});
	end
	table.sort(order, function(p, q) if p.s ~= q.s then return p.s > q.s end return p.c < q.c end);
	local taken, out = {}, {};
	for _, o in ipairs(order) do
		local bestE, bestV = nil, nil;
		for e = 1, k do
			if not taken[e] and (bestV == nil or potential[o.c][e] > bestV) then bestE, bestV = e, potential[o.c][e] end
		end
		taken[bestE] = true;
		out[o.c] = cent[bestE];
	end
	return out;
end

OVAL_START_GAP = 12;	-- capitals at least this many tiles apart (fixed, not scaled with map size)

OVAL_FRIEND_GAP = 7;	-- teammates' capitals may be this close (enemies: OVAL_START_GAP)

function OvalTeamNeed(a, b)
	-- tiles two capitals need between them: enemies 12, teammates 7
	if a == nil or b == nil then return 0 end
	local ta, tb = Players[a]:GetTeam(), Players[b]:GetTeam();
	if ta == tb then return OVAL_FRIEND_GAP end
	return OVAL_START_GAP;
end

function OvalPairNeed(c, d, cross)
	-- pair c and pair d (west starts c, d; east starts are their twins).
	-- cross = false: west c - west d (and east c - east d), same distance;
	-- cross = true: west c - east d (and east c - west d), same distance.
	local wc, ec, wd, ed = oWestPlayers[c], oEastPlayers[c], oWestPlayers[d], oEastPlayers[d];
	if c == d then return OvalTeamNeed(wc, ec) end
	if cross then return math.max(OvalTeamNeed(wc, ed), OvalTeamNeed(ec, wd)) end
	return math.max(OvalTeamNeed(wc, wd), OvalTeamNeed(ec, ed));
end

function OvalStartGapOK(i, chosen, gap)
	-- i as the start of the next pair keeps every distance it needs (less
	-- OVAL_START_GAP - gap when relaxed); distances wrap round the seam
	local c = #chosen + 1;
	local relax = OVAL_START_GAP - gap;
	if OvalDist(i, oTwin[i]) < OvalPairNeed(c, c, true) - relax then return false end
	for d, o in ipairs(chosen) do
		if OvalDist(i, o) < OvalPairNeed(c, d, false) - relax or OvalDist(i, oTwin[o]) < OvalPairNeed(c, d, true) - relax then return false end
	end
	return true;
end

function OvalKMeans(land, k)
	-- k centres spread evenly over the land (equal land shares); the first
	-- seed is random, the others farthest-point, then 30 rounds of k-means
	local cent = {};
	do
		local i = land[OvalRand(#land) + 1];
		local cx, cy = OvalCentre(i);
		cent[1] = {cx, cy};
	end
	for c = 2, k do
		local best, bestD = nil, -1;
		for _, i in ipairs(land) do
			local cx, cy = OvalCentre(i);
			local m = nil;
			for _, e in ipairs(cent) do
				local dx, dy = cx - e[1], (cy - e[2]) * 0.866;
				local d = dx * dx + dy * dy;
				if m == nil or d < m then m = d end
			end
			if m > bestD then best, bestD = {cx, cy}, m end
		end
		cent[c] = best;
	end
	for iter = 1, 30 do
		local sum = {};
		for c = 1, k do sum[c] = {0, 0, 0} end
		for _, i in ipairs(land) do
			local cx, cy = OvalCentre(i);
			local best, bd = 1, nil;
			for c = 1, k do
				local dx, dy = cx - cent[c][1], (cy - cent[c][2]) * 0.866;
				local d = dx * dx + dy * dy;
				if bd == nil or d < bd then best, bd = c, d end
			end
			sum[best][1] = sum[best][1] + cx; sum[best][2] = sum[best][2] + cy; sum[best][3] = sum[best][3] + 1;
		end
		for c = 1, k do
			if sum[c][3] > 0 then cent[c] = {sum[c][1] / sum[c][3], sum[c][2] / sum[c][3]} end
		end
	end
	-- squeeze towards the middle: every centre moves a fifth of the way to
	-- the centre line (enemy capitals still keep their 12 tiles)
	local axisX = (oW - 1) / 2;
	for c = 1, k do cent[c][1] = axisX - (axisX - cent[c][1]) * 0.8 end
	-- pair numbers run north to south (lobby order then decides who is where)
	table.sort(cent, function(p, q) if p[2] ~= q[2] then return p[2] > q[2] end return p[1] < q[1] end);
	return cent;
end

function OvalSnapStarts(land, cent, gap)
	-- each centre moves to the best city site within 6 tiles that keeps the gap;
	-- returns the list, or nil when one centre finds no such site
	local chosen = {};
	for c = 1, #cent do
		local best, bestS = nil, nil;
		for _, i in ipairs(land) do
			local cx, cy = OvalCentre(i);
			local dx, dy = cx - cent[c][1], (cy - cent[c][2]);
			local off = math.abs(dx) + math.abs(dy);
			if off <= 7 then
				local s = OvalStartScore(i);
				if s >= 0 then s = s + OvalBiasScore(c, i) end
				if s >= 0 and OvalStartGapOK(i, chosen, gap) then
					s = s - off * 1.5;
					if bestS == nil or s > bestS then best, bestS = i, s end
				end
			end
		end
		if best == nil then return nil end
		chosen[c] = best;
	end
	return chosen;
end

oCloseMax = nil;	-- Compact / Brawl: some enemy capitals at most this far apart
function OvalSetGaps()
	-- Map size: Normal and Compact keep enemies 12 apart, Brawl 8. Compact and
	-- Brawl also bring at least two enemy capitals within 15 / 12 tiles (not
	-- in a duel, which stays random). Distances count the mirror / turned
	-- copies, so the turn never brings anyone closer than this.
	local sz = OvalOpt("size");
	OVAL_START_GAP = ({12, 12, 8})[sz];
	oCloseMax = ({nil, 15, 12})[sz];
	if #oWestPlayers + #oEastPlayers <= 2 then oCloseMax = nil end
end

function OvalEnemyPairs(list)
	-- every enemy pair as {c, d, cross, distance}; c == d is a start and its copy
	local out = {};
	for c = 1, #list do
		for d = c, #list do
			for _, cross in ipairs(c == d and {true} or {false, true}) do
				if OvalPairNeed(c, d, cross) >= OVAL_START_GAP then
					local dist = cross and OvalDist(list[c], oTwin[list[d]]) or OvalDist(list[c], list[d]);
					table.insert(out, {c, d, cross, dist});
				end
			end
		end
	end
	return out;
end
function OvalClosestEnemy(list)
	local best = nil;
	for _, e in ipairs(OvalEnemyPairs(list)) do if best == nil or e[4] < best[4] then best = e end end
	return best;
end

function OvalPullTogether(land)
	-- Compact / Brawl: move a start of the closest enemy pair towards the other
	-- (never breaking a gap) until they are within oCloseMax
	if oCloseMax == nil then return end
	local isLand = {};
	for _, i in ipairs(land) do isLand[i] = true end
	for round = 1, 40 do
		local e = OvalClosestEnemy(oStarts);
		if e == nil or e[4] <= oCloseMax then return end
		local moved = false;
		for _, who in ipairs({e[1], e[2]}) do
			if not moved then
				local here = oStarts[who];
				local best, bestD, bestS = nil, e[4], nil;
				for _, j in ipairs(OvalRing(here, 1, 2)) do
					if isLand[j] and OvalStartScore(j) >= 0 then
						oStarts[who] = j;
						if OvalStartMinDist(who, oStarts) >= OVAL_START_GAP then
							local ne = OvalClosestEnemy(oStarts);
							local sc = OvalStartScore(j) + OvalBiasScore(who, j);
							if ne and (ne[4] < bestD or (ne[4] == bestD and best ~= nil and sc > bestS)) then best, bestD, bestS = j, ne[4], sc end
						end
						oStarts[who] = here;
					end
				end
				if best ~= nil then oStarts[who] = best; moved = true end
			end
		end
		if not moved then return end
	end
end

function OvalChooseStarts()
	-- k sites spread evenly over the west half of the oval, moved to a good
	-- spot nearby, every capital at least OVAL_START_GAP tiles from every other
	-- (mirror twins and the players across the seam included)
	OvalSetGaps();
	local k = math.max(#oWestPlayers, #oEastPlayers, 1);
	-- land a start can use: 6+ tiles from the centre line (and from the seam
	-- when the map wraps), so it can keep 12 from its own mirror twin
	local half = OVAL_START_GAP / 2;
	local land = {};
	for i = 0, oN - 1 do
		local _, cy = OvalCentre(i);
		local twinOK;
		if oRotate then
			twinOK = OvalDist(i, oTwin[i]) >= OVAL_START_GAP;	-- the turned twin can be anywhere
		else
			twinOK = oAxisDist[i] >= half - 0.5 and (not oWrap or oSeamDist[i] >= half - 0.5);
		end
		if oMain[i] and oKind[i] == OVAL_WEST and OvalIsLand(i) and twinOK and math.abs(cy - oCentreY) <= oB * 0.72 then
			table.insert(land, i);
		end
	end
	if #land < k * 4 then
		land = {};
		for i = 0, oN - 1 do
			if oMain[i] and oKind[i] == OVAL_WEST and OvalIsLand(i) then table.insert(land, i) end
		end
	end
	-- try: k-means centres snapped with the full gap; else the closest gap
	-- that works, then push the starts apart until every one keeps the gap
	oStarts = nil;
	local keep, keepGap = nil, -1;
	for attempt = 1, 14 do
		local cent = OvalOrderCentresByBias(land, OvalKMeans(land, k));
		oStarts = OvalSnapStarts(land, cent, OVAL_START_GAP);
		if oStarts == nil then
			for gap = OVAL_START_GAP - 1, 4, -1 do
				oStarts = OvalSnapStarts(land, cent, gap);
				if oStarts ~= nil then break end
			end
			if oStarts ~= nil then OvalPushStartsApart(land) end
		end
		if oStarts ~= nil then
			local g = OvalStartsMinGap(oStarts);
			if g > keepGap then keep, keepGap = oStarts, g end
			if g >= OVAL_START_GAP then break end
		end
	end
	oStarts = keep;
	if oStarts == nil then
		oStarts = {};
		for c = 1, k do oStarts[c] = land[1 + math.floor((c - 1) * #land / k)] end
		OvalPushStartsApart(land);
	end
	OvalPullTogether(land);
	if OvalStartsMinGap(oStarts) < OVAL_START_GAP then
		print("Mirror Map: Pangaea - starts keep only", OvalStartsMinGap(oStarts), "tiles (land too small)");
	end
end

function OvalStartMinDist(c, list)
	-- how well start c keeps its distances: OVAL_START_GAP or more = all kept
	-- (the smallest "distance minus what is needed", plus OVAL_START_GAP)
	local i = list[c];
	local m = OvalDist(i, oTwin[i]) - OvalPairNeed(c, c, true);
	for d, o in ipairs(list) do
		if d ~= c then
			m = math.min(m, OvalDist(i, o) - OvalPairNeed(c, d, false), OvalDist(i, oTwin[o]) - OvalPairNeed(c, d, true));
		end
	end
	return m + OVAL_START_GAP;
end
function OvalStartsMinGap(list)
	local m = 999;
	for c = 1, #list do m = math.min(m, OvalStartMinDist(c, list)) end
	return m;
end

function OvalPushStartsApart(land)
	-- hill climbing: the start with the smallest distance moves (up to 3 tiles)
	-- to the spot with the largest smallest distance (capped at the gap), site
	-- quality breaking ties; until all keep the gap or nothing improves
	local isLand = {};
	for _, i in ipairs(land) do isLand[i] = true end
	for round = 1, 60 do
		local worst, worstD = nil, nil;
		for c = 1, #oStarts do
			local d = OvalStartMinDist(c, oStarts);
			if worstD == nil or d < worstD then worst, worstD = c, d end
		end
		if worstD >= OVAL_START_GAP then return end
		local here = oStarts[worst];
		local best, bestD, bestS = here, worstD, OvalStartScore(here) + OvalBiasScore(worst, here);
		for _, j in ipairs(OvalRing(here, 1, 4)) do
			if isLand[j] and OvalStartScore(j) >= 0 then
				oStarts[worst] = j;
				local d = math.min(OvalStartMinDist(worst, oStarts), OVAL_START_GAP);
				local sc = OvalStartScore(j) + OvalBiasScore(worst, j);
				if d > bestD or (d == bestD and d >= OVAL_START_GAP and sc > bestS) then best, bestD, bestS = j, d, sc end
			end
		end
		oStarts[worst] = best;
		if best == here then
			-- stuck: let the nearest other start move instead
			local near, nd = nil, nil;
			for c = 1, #oStarts do
				if c ~= worst then
					local d = math.min(OvalDist(here, oStarts[c]), OvalDist(here, oTwin[oStarts[c]]));
					if nd == nil or d < nd then near, nd = c, d end
				end
			end
			if near == nil then return end
			local h2 = oStarts[near];
			local b2, bd2 = h2, OvalStartMinDist(near, oStarts);
			for _, j in ipairs(OvalRing(h2, 1, 3)) do
				if isLand[j] and OvalStartScore(j) >= 0 then
					oStarts[near] = j;
					local d = OvalStartMinDist(near, oStarts);
					local dw = OvalStartMinDist(worst, oStarts);
					if math.min(d, dw) > math.min(bd2, worstD) then b2, bd2 = j, d end
				end
			end
			oStarts[near] = b2;
			if b2 == h2 then return end
		end
	end
end

------------------------------------------------------------------------------
-- 9. RESOURCES
------------------------------------------------------------------------------
-- Where each resource may go (own rules). kinds: "flat", "hill", "any" (land
-- without mountains); terr = allowed terrains; feat = allowed features
-- ("none" = no feature).
function OvalResourceRules()
	local T, Fe = TerrainTypes, FeatureTypes;
	local G, P, D, Tu = T.TERRAIN_GRASS, T.TERRAIN_PLAINS, T.TERRAIN_DESERT, T.TERRAIN_TUNDRA;
	local FO, JU, MA, FP = Fe.FEATURE_FOREST, Fe.FEATURE_JUNGLE, Fe.FEATURE_MARSH, Fe.FEATURE_FLOOD_PLAINS;
	local function R(t) return GameInfoTypes and GameInfoTypes[t] or (GameInfo.Resources[t] and GameInfo.Resources[t].ID) end
	return {
		-- bonus
		{R("RESOURCE_WHEAT"), "bonus", {{"flat", {P}, {"none"}}, {"flat", {D}, {FP}}}},
		{R("RESOURCE_COW"), "bonus", {{"flat", {G}, {"none"}}}},
		{R("RESOURCE_SHEEP"), "bonus", {{"hill", {G, P, D, Tu}, {"none"}}}},
		{R("RESOURCE_DEER"), "bonus", {{"any", {G, P, Tu}, {FO}}, {"flat", {Tu}, {"none"}}}},
		{R("RESOURCE_BANANA"), "bonus", {{"flat", {G, P}, {JU}}}},
		{R("RESOURCE_BISON"), "bonus", {{"flat", {G, P}, {"none"}}}},
		{R("RESOURCE_STONE"), "bonus", {{"any", {G, P, D, Tu}, {"none"}}}},
		-- strategic
		{R("RESOURCE_IRON"), "strat", {{"any", {G, P, D, Tu}, {"none"}}}},
		{R("RESOURCE_HORSE"), "strat", {{"flat", {G, P, Tu}, {"none"}}}},
		{R("RESOURCE_COAL"), "strat", {{"hill", {G, P}, {"none"}}}},
		{R("RESOURCE_ALUMINUM"), "strat", {{"any", {P, D, Tu}, {"none"}}}},
		{R("RESOURCE_OIL"), "strat", {{"flat", {D, Tu}, {"none"}}, {"flat", {G, P}, {MA, JU}}}},
		{R("RESOURCE_URANIUM"), "strat", {{"any", {G, P, D, Tu}, {"none", FO, JU, MA}}}},
		-- luxury
		{R("RESOURCE_GOLD"), "lux", {{"any", {G, P, D}, {"none"}}}},
		{R("RESOURCE_SILVER"), "lux", {{"any", {D, Tu}, {"none"}}}},
		{R("RESOURCE_GEMS"), "lux", {{"hill", {G, P, D, Tu}, {"none"}}, {"flat", {G, P}, {JU}}}},
		{R("RESOURCE_MARBLE"), "lux", {{"any", {G, P, D, Tu}, {"none"}}}},
		{R("RESOURCE_IVORY"), "lux", {{"flat", {P}, {"none"}}}},
		{R("RESOURCE_FUR"), "lux", {{"flat", {Tu}, {"none"}}, {"any", {Tu, G, P}, {FO}}}},
		{R("RESOURCE_DYE"), "lux", {{"flat", {G, P}, {FO, JU}}}},
		{R("RESOURCE_SPICES"), "lux", {{"flat", {G, P}, {JU}}}},
		{R("RESOURCE_SILK"), "lux", {{"flat", {G, P}, {FO}}}},
		{R("RESOURCE_SUGAR"), "lux", {{"flat", {D}, {FP}}, {"flat", {G}, {MA}}}},
		{R("RESOURCE_COTTON"), "lux", {{"flat", {G, P, D}, {"none"}}}},
		{R("RESOURCE_WINE"), "lux", {{"flat", {G, P}, {"none"}}}},
		{R("RESOURCE_INCENSE"), "lux", {{"flat", {P, D}, {"none"}}}},
		{R("RESOURCE_COPPER"), "lux", {{"any", {G, P, D, Tu}, {"none"}}}},
		{R("RESOURCE_SALT"), "lux", {{"flat", {P, D, Tu}, {"none"}}}},
		{R("RESOURCE_TRUFFLES"), "lux", {{"flat", {G, P}, {FO, JU, MA}}}},
		{R("RESOURCE_CITRUS"), "lux", {{"flat", {G, P}, {"none"}}}},
		{R("RESOURCE_COCOA"), "lux", {{"flat", {G, P}, {JU}}}},
		-- sea
		{R("RESOURCE_FISH"), "sea", {}},
		{R("RESOURCE_WHALE"), "sealux", {}},
		{R("RESOURCE_PEARLS"), "sealux", {}},
		{R("RESOURCE_CRAB"), "sealux", {}},
	};
end
oRules = {};		-- resource id -> rule row
oLuxLand, oLuxSea = {}, {};
oResFree = {};		-- plot -> true if a resource may go there (west half / axis)
OVAL_FISH = -1;

function OvalInitResources()
	oRules = {};
	oLuxLand, oLuxSea = {}, {};
	for _, row in ipairs(OvalResourceRules()) do
		if row[1] ~= nil then
			oRules[row[1]] = row;
			if row[2] == "lux" then table.insert(oLuxLand, row[1]) end
			if row[2] == "sealux" then table.insert(oLuxSea, row[1]) end
		end
	end
	OVAL_FISH = GameInfoTypes and GameInfoTypes["RESOURCE_FISH"] or GameInfo.Resources["RESOURCE_FISH"].ID;
	for i = 0, oN - 1 do oRes[i] = -1; oResAmt[i] = 0; oImp[i] = -1 end
end

function OvalOcean(i)
	-- sea tile that belongs to the ocean (not a lake), shallow
	return OvalIsWater(i) and oTerr[i] == TerrainTypes.TERRAIN_COAST and not oLakes[i];
end
oLakes = {};

function OvalFits(i, resID)
	-- can resource resID sit on plot i (as the map is now)?
	if i < 0 or oRes[i] ~= -1 or oImp[i] ~= -1 then return false end
	local row = oRules[resID];
	if row == nil then return false end
	if oFeat[i] ~= -1 and GameInfo.Features[oFeat[i]] and GameInfo.Features[oFeat[i]].NaturalWonder then return false end
	if row[2] == "sea" or row[2] == "sealux" then
		return OvalOcean(i) and oFeat[i] == -1 and OvalLandNbrs(i) > 0;
	end
	if not OvalIsLand(i) or oPlot[i] == PlotTypes.PLOT_MOUNTAIN then return false end
	for _, place in ipairs(row[3]) do
		local kind, terrs, feats = place[1], place[2], place[3];
		local kindOK = kind == "any" or (kind == "flat" and oPlot[i] == PlotTypes.PLOT_LAND) or (kind == "hill" and oPlot[i] == PlotTypes.PLOT_HILLS);
		if kindOK then
			local tOK = false;
			for _, t in ipairs(terrs) do if oTerr[i] == t then tOK = true end end
			local fOK = false;
			for _, f in ipairs(feats) do
				if (f == "none" and oFeat[i] == -1) or f == oFeat[i] then fOK = true end
			end
			if tOK and fOK then return true end
		end
	end
	return false;
end

function OvalMakeFit(i, resID)
	-- change plot i (west, land, no start) so resID fits; returns true if done
	local row = oRules[resID];
	if row == nil or row[2] == "sea" or row[2] == "sealux" then return false end
	if not OvalIsLand(i) or oRes[i] ~= -1 then return false end
	local place = row[3][1];
	local kind, terrs, feats = place[1], place[2], place[3];
	if kind == "flat" then
		if oPlot[i] ~= PlotTypes.PLOT_LAND then oPlot[i] = PlotTypes.PLOT_LAND end
	elseif kind == "hill" then
		oPlot[i] = PlotTypes.PLOT_HILLS;
	elseif oPlot[i] == PlotTypes.PLOT_MOUNTAIN then
		oPlot[i] = PlotTypes.PLOT_HILLS;
	end
	local tOK = false;
	for _, t in ipairs(terrs) do if oTerr[i] == t then tOK = true end end
	if not tOK then oTerr[i] = terrs[1] end
	local f = feats[1];
	if f == "none" then oFeat[i] = -1 else oFeat[i] = f end
	if f == FeatureTypes.FEATURE_JUNGLE and oTerr[i] == TerrainTypes.TERRAIN_GRASS then oTerr[i] = TerrainTypes.TERRAIN_PLAINS end
	return OvalFits(i, resID);
end

function OvalSet(i, resID, amount)
	oRes[i] = resID;
	oResAmt[i] = amount or 1;
end

function OvalNoResHere(i)
	-- resources stay off the centre line pairs and off seam pairs (twins that
	-- touch each other), except the self-mirrored axis plots handled on purpose
	if oKind[i] == OVAL_AXIS then return true end
	if oKind[i] ~= OVAL_WEST then return true end
	if oWrap and oSeamDist[i] <= 0.6 then return true end
	-- a resource and its mirror copy right next to each other looks doubled
	if OvalDist(i, oTwin[i]) < 2 then return true end
	return false;
end

function OvalPlaceCapitalResources()
	-- every capital: Horses 4, Iron 6, Coal 7, Aluminium 3 within 3 tiles,
	-- 2 food bonus within 2, one regional luxury (2 copies within 3), a second
	-- luxury (1 copy within 3)
	local R = GameInfoTypes or {};
	local function ID(t) return R[t] or GameInfo.Resources[t].ID end
	OvalShuffle(oLuxLand);
	-- 11-16 (user: "same amount of luxes for each side no matter map size"):
	-- the whole map uses a pool by world size (OVAL_LUX_LAND_TYPES) and 1 sea
	-- type (each side sees the same ones). With more players than land types,
	-- players share regional types.
	local ws = (Map.GetWorldSize ~= nil) and Map.GetWorldSize() or 3;
	local landTypes = OVAL_LUX_LAND_TYPES[ws] or 9;
	while #oLuxLand > landTypes do table.remove(oLuxLand) end
	OvalShuffle(oLuxSea);
	while #oLuxSea > 1 do table.remove(oLuxSea) end
	oRegionalLux = {};
	local usedLux = {};
	for c, s in ipairs(oStarts) do
		OvalEnsure(s, ID("RESOURCE_HORSE"), 4, 1, 3);
		OvalEnsure(s, ID("RESOURCE_IRON"), 6, 1, 3);
		OvalEnsure(s, ID("RESOURCE_COAL"), 7, 2, 3);
		OvalEnsure(s, ID("RESOURCE_ALUMINUM"), 3, 2, 3);
		-- food
		local food = 0;
		for _, j in ipairs(OvalRing(s, 1, 2)) do
			local r = oRes[j];
			if r ~= -1 and oRules[r] and (oRules[r][2] == "bonus" or oRules[r][2] == "sea") and r ~= ID("RESOURCE_STONE") then food = food + 1 end
		end
		local foods = {ID("RESOURCE_WHEAT"), ID("RESOURCE_COW"), ID("RESOURCE_BISON"), ID("RESOURCE_DEER"), ID("RESOURCE_BANANA"), OVAL_FISH};
		-- start quality, rolled per pair (both twins the same): poor 30% (0-1 food
		-- resources within 2), normal 45% (1-3), rich 25% (2-4)
		local q = OvalRand(100);
		if q < 30 then oStartFood[c] = {0, 1} elseif q < 75 then oStartFood[c] = {1, 3} else oStartFood[c] = {2, 4} end
		local guard = 0;
		while food < oStartFood[c][1] and guard < 4 do
			guard = guard + 1;
			if OvalEnsureAny(s, foods, 1, 2, true) then food = food + 1 end
		end
	end
	-- luxuries as in the game's Pangaea: every capital has its own regional
	-- luxury (1 copy within 3, 2-3 more in its own area 4-7 tiles out, nearer
	-- to it than to any other capital) plus 1 other luxury within 3.
	local capAll = {};
	for _, s in ipairs(oStarts) do table.insert(capAll, s); table.insert(capAll, oTwin[s]) end
	local function Mine(j, s)
		local d = OvalDist(j, s);
		for _, o in ipairs(capAll) do if o ~= s and OvalDist(j, o) <= d then return false end end
		return true;
	end
	for c, s in ipairs(oStarts) do
		-- the unused type with the most room around this capital
		local best, bestN = nil, -1;
		local allUsed = true;
		for _, lux in ipairs(oLuxLand) do if not usedLux[lux] then allUsed = false end end
		for _, lux in ipairs(oLuxLand) do
			if allUsed or not usedLux[lux] then
				local n = 0;
				for _, j in ipairs(OvalRing(s, 2, 7)) do
					if not OvalNoResHere(j) and oRes[j] == -1 and not oStartSet[j] and OvalFits(j, lux) then n = n + 1 end
				end
				n = n + OvalRandF();
				if n > bestN then best, bestN = lux, n end
			end
		end
		if best ~= nil then
			usedLux[best] = true;
			oRegionalLux[c] = best;
			local near = OvalSpotsFor(s, best, 2, 3, false);
			if #near > 0 then OvalSet(near[1], best, 1)
			else
				for _, j in ipairs(OvalSpotsFor(s, best, 2, 3, true)) do if OvalMakeFit(j, best) then OvalSet(j, best, 1); break end end
			end
			local want = 2 + OvalRand(2);
			local got, placedAt = 0, {};
			for _, j in ipairs(OvalShuffle(OvalRing(s, 4, 7))) do
				if got >= want then break end
				if not OvalNoResHere(j) and oRes[j] == -1 and not oStartSet[j] and Mine(j, s) and OvalFits(j, best) then
					local apart = true;
					for _, q in ipairs(placedAt) do if OvalDist(j, q) < 2 then apart = false end end
					if apart then OvalSet(j, best, 1); table.insert(placedAt, j); got = got + 1 end
				end
			end
		end
	end
	-- the extra luxury within 3 (a type that is nobody's regional one)
	for c, s in ipairs(oStarts) do
		local list = {};
		for _, l in ipairs(oLuxLand) do if not usedLux[l] then table.insert(list, l) end end
		if #list == 0 then for _, l in ipairs(oLuxLand) do if l ~= oRegionalLux[c] then table.insert(list, l) end end end
		OvalShuffle(list);
		if not OvalEnsureAny(s, list, 2, 3, true) and not OvalEnsureAny(s, list, 1, 3, true) then
			-- the land round a very coastal capital is full: a sea luxury instead
			OvalEnsureAny(s, OvalShuffle({unpack(oLuxSea)}), 1, 3, false);
		end
	end
	oUsedRegional = usedLux;
end
oRegionalLux, oUsedRegional = {}, {};
-- 11-16 (user): luxury types on the map scale with the size: duel 4, tiny 6,
-- small 8 (land types here, +1 sea type), bigger sizes a few more.
OVAL_LUX_LAND_TYPES = {[0] = 3, [1] = 5, [2] = 7, [3] = 9, [4] = 10, [5] = 11};
oStartFood, oStartFoodLog = {}, {};

function OvalCountNear(s, resID, minR, maxR)
	local n = 0;
	for _, j in ipairs(OvalRing(s, minR, maxR)) do if oRes[j] == resID then n = n + 1 end end
	return n;
end

function OvalSpotsFor(s, resID, minR, maxR, bForce)
	-- plots near s where resID fits (or could be made to fit), shuffled
	local list = {};
	for _, j in ipairs(OvalRing(s, minR, maxR)) do
		if not OvalNoResHere(j) and oRes[j] == -1 and oImp[j] == -1 and not oStartSet[j] and not OvalIsWonder(j) then
			if bForce then
				-- any land tile (a mountain becomes a hill)
				if OvalIsLand(j) then table.insert(list, j) end
			elseif OvalFits(j, resID) then
				table.insert(list, j);
			end
		end
	end
	OvalShuffle(list);
	return list;
end
oStartSet = {};

function OvalEnsure(s, resID, amount, minR, maxR)
	-- make sure resID (with amount) is within maxR of s
	for _, j in ipairs(OvalRing(s, 0, maxR)) do
		if oRes[j] == resID then oResAmt[j] = math.max(oResAmt[j], amount); return true end
	end
	local spots = OvalSpotsFor(s, resID, minR, maxR, false);
	if #spots > 0 then OvalSet(spots[1], resID, amount); return true end
	-- no room: change a tile (prefer ones that are not hills or forest)
	local spots = OvalSpotsFor(s, resID, minR, maxR, true);
	table.sort(spots, function(p, q)
		local a = (oPlot[p] == PlotTypes.PLOT_LAND and 0 or 1) + (oFeat[p] == -1 and 0 or 1);
		local b = (oPlot[q] == PlotTypes.PLOT_LAND and 0 or 1) + (oFeat[q] == -1 and 0 or 1);
		if a ~= b then return a < b end
		return p < q;
	end);
	for _, j in ipairs(spots) do
		if OvalMakeFit(j, resID) then OvalSet(j, resID, amount); return true end
	end
	return false;
end
function OvalIsWonder(i)
	local f = oFeat[i];
	return f ~= nil and f ~= -1 and GameInfo.Features[f] ~= nil and GameInfo.Features[f].NaturalWonder == true;
end

function OvalEnsureAny(s, list, minR, maxR, bForce)
	for _, r in ipairs(list) do
		local spots = OvalSpotsFor(s, r, minR, maxR, false);
		if #spots > 0 then OvalSet(spots[1], r, 1); return true end
	end
	if bForce then
		for _, r in ipairs(list) do
			if oRules[r] and oRules[r][2] ~= "sea" then
				for _, j in ipairs(OvalSpotsFor(s, r, minR, maxR, true)) do
					if oPlot[j] ~= PlotTypes.PLOT_MOUNTAIN and OvalMakeFit(j, r) then OvalSet(j, r, 1); return true end
				end
			end
		end
	end
	return false;
end

function OvalSpread(kindList, perTile, spacing, amountFn, landOnly)
	-- spreads resources of the given ids evenly over the west half:
	-- candidates in random order, each placed at least 'spacing' from any other
	-- resource of the same group and 3 from capitals (bonus 2)
	local cands = {};
	for i = 0, oN - 1 do
		if not OvalNoResHere(i) and oRes[i] == -1 and not oStartSet[i] then table.insert(cands, i) end
	end
	OvalShuffle(cands);
	local landCount = 0;
	for i = 0, oN - 1 do if oKind[i] == OVAL_WEST and OvalIsLand(i) then landCount = landCount + 1 end end
	local want = math.floor(landCount * perTile + 0.5);
	local placed = {};
	-- existing ones count for spacing
	for i = 0, oN - 1 do
		if oKind[i] == OVAL_WEST and oRes[i] ~= -1 then
			for _, r in ipairs(kindList) do if oRes[i] == r then table.insert(placed, i) end end
		end
	end
	local count = 0;
	local idx = OvalRand(#kindList) + 1;
	for _, i in ipairs(cands) do
		if count >= want then break end
		local ok = true;
		for _, s in ipairs(oStarts) do if OvalDist(i, s) < 2 then ok = false end end
		if ok then
			for _, p in ipairs(placed) do if OvalDist(i, p) < spacing then ok = false; break end end
		end
		if ok then
			-- first kind (in rotation) that fits
			for k = 0, #kindList - 1 do
				local r = kindList[(idx + k - 1) % #kindList + 1];
				if OvalFits(i, r) then
					OvalSet(i, r, amountFn and amountFn(r) or 1);
					table.insert(placed, i);
					count = count + 1;
					idx = idx % #kindList + 1;
					break;
				end
			end
		end
	end
	return count;
end

function OvalPlaceResources()
	local function ID(t) return (GameInfoTypes and GameInfoTypes[t]) or GameInfo.Resources[t].ID end
	oLakes = OvalLakeSet();
	-- bonus everywhere, about 1 per 8 land tiles, evenly
	local bonus = {ID("RESOURCE_WHEAT"), ID("RESOURCE_COW"), ID("RESOURCE_SHEEP"), ID("RESOURCE_DEER"), ID("RESOURCE_BANANA"), ID("RESOURCE_BISON"), ID("RESOURCE_STONE")};
	OvalSpread(bonus, 1 / 8, 3, nil);
	-- fish: about 1 per 9 coast tiles
	local coastN, landN = 0, 0;
	for i = 0, oN - 1 do
		if oKind[i] == OVAL_WEST and OvalOcean(i) and OvalLandNbrs(i) > 0 then coastN = coastN + 1 end
		if oKind[i] == OVAL_WEST and OvalIsLand(i) then landN = landN + 1 end
	end
	local seaMult = ({0.65, 1.0, 1.5})[oSeaRich];
	OvalSpread({OVAL_FISH}, (coastN / math.max(1, landN)) / 5 * seaMult, 2, nil);
	-- strategics: each type spread separately
	local stratAmt = {
		[ID("RESOURCE_IRON")] = function() return 2 + OvalRand(3) end,
		[ID("RESOURCE_HORSE")] = function() return 2 + OvalRand(3) end,
		[ID("RESOURCE_COAL")] = function() return 3 + OvalRand(4) end,
		[ID("RESOURCE_ALUMINUM")] = function() return 3 + OvalRand(3) end,
		[ID("RESOURCE_OIL")] = function() return 3 + OvalRand(4) end,
		[ID("RESOURCE_URANIUM")] = function() return 2 + OvalRand(3) end,
	};
	local per = {[ID("RESOURCE_IRON")] = 1 / 60, [ID("RESOURCE_HORSE")] = 1 / 60, [ID("RESOURCE_COAL")] = 1 / 75,
		[ID("RESOURCE_ALUMINUM")] = 1 / 85, [ID("RESOURCE_OIL")] = 1 / 75, [ID("RESOURCE_URANIUM")] = 1 / 110};
	for _, name in ipairs({"RESOURCE_IRON", "RESOURCE_HORSE", "RESOURCE_COAL", "RESOURCE_ALUMINUM", "RESOURCE_OIL", "RESOURCE_URANIUM"}) do
		local r = ID(name);
		OvalSpread({r}, per[r], 6, function() return stratAmt[r]() end);
	end
	-- luxuries over the open land: the types nobody has as regional, in small
	-- groups, evenly spread; about 1 per 14 land tiles
	local free = {};
	for _, l in ipairs(oLuxLand) do if not oUsedRegional[l] then table.insert(free, l) end end
	if #free == 0 then for _, l in ipairs(oLuxLand) do table.insert(free, l) end end
	OvalShuffle(free);
	-- every type that is nobody's regional luxury, mixed (no clusters of one type)
	local use = {};
	local keep = #free;	-- the fixed pool (OVAL_LUX_LAND_TYPES)
	for k = 1, keep do table.insert(use, free[k]) end
	OvalSpreadLux(use, 1 / 14);
	-- sea luxuries: 1 per ~30 coast tiles
	OvalSpread(oLuxSea, (coastN / math.max(1, landN)) / 16 * seaMult, 4, nil);
	-- the shared centre line gets useful things (luxuries, strategics, food)
	-- 11-16 (user): no rich centre line on duel / tiny (both would have to rush it)
	if OvalMiddleLevel() == 1 then OvalCentreStuff(use) end
	OvalThinMiddle();
	-- islands: worth a trip or not, by the sea roll
	OvalIslandRiches(use);
	-- start quality: no more food resources within 2 than the pair's roll allows
	-- (the farthest go first; Fish and land food both count, Stone does not)
	local stone = (GameInfoTypes and GameInfoTypes["RESOURCE_STONE"]) or GameInfo.Resources["RESOURCE_STONE"].ID;
	for c, s in ipairs(oStarts) do
		local foodAt = {};
		for _, j in ipairs(OvalRing(s, 1, 2)) do
			local r = oRes[j];
			if r ~= -1 and r ~= stone and oRules[r] and (oRules[r][2] == "bonus" or oRules[r][2] == "sea") then table.insert(foodAt, j) end
		end
		table.sort(foodAt, function(p, q) local a, b = OvalDist(s, p), OvalDist(s, q); if a ~= b then return a > b end return p < q end);
		local maxFood = (oStartFood[c] or {1, 3})[2];
		for k = 1, #foodAt - maxFood do oRes[foodAt[k]] = -1; oResAmt[foodAt[k]] = 0 end
	end
	oStartFoodLog = {};
	for c = 1, #oStarts do oStartFoodLog[c] = (oStartFood[c] or {1, 3})[2] end
	-- capitals as in the game's Pangaea: at most 3 luxuries within 3 tiles
	-- (the regional one, the extra one, sometimes one more)
	for c, s in ipairs(oStarts) do
		local extra = {};
		local total = 0;
		for _, j in ipairs(OvalRing(s, 1, 3)) do
			local r = oRes[j];
			if r ~= -1 and oRules[r] and (oRules[r][2] == "lux" or oRules[r][2] == "sealux") then
				total = total + 1;
				if r ~= oRegionalLux[c] then table.insert(extra, j) end
			end
		end
		-- drop the farthest extras first, never the last one
		table.sort(extra, function(p, q) local a, b = OvalDist(s, p), OvalDist(s, q); if a ~= b then return a > b end return p < q end);
		local k = 1;
		while total > 3 and k < #extra do
			oRes[extra[k]] = -1; oResAmt[extra[k]] = 0;
			total = total - 1;
			k = k + 1;
		end
	end
end

function OvalBarrenStrip()
	-- 11-16 (user: Barren = "a divider almost", then "2-3 tiles wide, can be
	-- plains, grassland, mostly flat, some few mountains"): a thin bare strip on
	-- the centre line - the land keeps its terrain, hills go flat, forest /
	-- jungle / marsh go, about 1 tile in 8 becomes a lone mountain.
	if OvalMiddleLevel() ~= 3 then return end
	local core = OVAL_BARREN_CORE;
	for i = 0, oN - 1 do
		if OvalIsWestOrAxis(i) and OvalIsLand(i) and oAxisDist[i] <= core and not OvalIsWonder(i) then
			if oPlot[i] == PlotTypes.PLOT_HILLS then oPlot[i] = PlotTypes.PLOT_LAND end
			oFeat[i] = -1;
			if oPlot[i] == PlotTypes.PLOT_LAND and not oRiverSide[i] and OvalRand(8) == 0 then
				local lone = true;
				for _, j in ipairs(oNb[i]) do if j >= 0 and oPlot[j] == PlotTypes.PLOT_MOUNTAIN then lone = false end end
				if lone then oPlot[i] = PlotTypes.PLOT_MOUNTAIN end
			end
		end
	end
	OvalMirrorAll();
end
OVAL_BARREN_CORE = 1.25;	-- hex widths from the centre line: a strip 2-3 tiles wide

function OvalThinMiddle()
	-- 11-16 (user): fewer resources in the middle band on "less" (a third left
	-- out) and "barren" (two thirds, strategics too). Never near a capital.
	local lvl = OvalMiddleLevel();
	if lvl == 1 then return end
	local drop = (lvl == 2) and 33 or 67;
	local band = oA * 0.3;
	local core = OVAL_BARREN_CORE;
	local removed = 0;
	for i = 0, oN - 1 do
		local r = oRes[i];
		if r ~= -1 and OvalIsWestOrAxis(i) and OvalIsLand(i) and oAxisDist[i] <= band and oRules[r] then
			local kind = oRules[r][2];
			local near = false;
			for _, s in ipairs(oStarts) do if OvalDist(i, s) <= 3 or OvalDist(i, oTwin[s]) <= 3 then near = true end end
			local can = kind == "bonus" or kind == "lux" or (lvl == 3 and kind ~= "sea" and kind ~= "sealux");
			local d = drop;
			if lvl == 3 and oAxisDist[i] <= core then d = 100 end
			if not near and can and OvalRand(100) < d then
				oRes[i] = -1; oResAmt[i] = 0;
				local t = oTwin[i];
				if t ~= nil and t >= 0 then oRes[t] = -1; oResAmt[t] = 0 end
				removed = removed + 1;
			end
		end
	end
	print("Mirror Map: Pangaea - middle level", lvl, "resources left out", removed);
end

function OvalSpreadLux(types, perTile)
	local landN = 0;
	for i = 0, oN - 1 do if oKind[i] == OVAL_WEST and OvalIsLand(i) then landN = landN + 1 end end
	local want = math.floor(landN * perTile + 0.5);
	local cands = {};
	for i = 0, oN - 1 do
		if not OvalNoResHere(i) and oRes[i] == -1 and OvalIsLand(i) and not oStartSet[i] then table.insert(cands, i) end
	end
	OvalShuffle(cands);
	local centres = {};
	local count = 0;
	local byType = {};	-- type -> west plots that have it
	for i = 0, oN - 1 do
		if oKind[i] == OVAL_WEST and oRes[i] ~= -1 then
			byType[oRes[i]] = byType[oRes[i]] or {};
			table.insert(byType[oRes[i]], i);
		end
	end
	local function Clashes(i, r)
		-- the same type within 6 tiles of i, or its mirror copy within 6
		for _, p in ipairs(byType[r] or {}) do
			if OvalDist(i, p) < 6 or OvalDist(i, oTwin[p]) < 6 then return true end
		end
		return false;
	end
	local used = {};	-- how often each type was placed: least used first
	for _, i in ipairs(cands) do
		if count >= want then break end
		-- no luxuries within 2 tiles of the centre line (the shared line has its own)
		local ok = oAxisDist[i] >= 2.4;
		for _, s in ipairs(oStarts) do if OvalDist(i, s) < 4 then ok = false end end
		if ok then for _, c in ipairs(centres) do if OvalDist(i, c) < 4 then ok = false; break end end end
		if ok then
			local order = {};
			for _, r in ipairs(types) do table.insert(order, r) end
			OvalShuffle(order);
			table.sort(order, function(p, q) return (used[p] or 0) < (used[q] or 0) end);
			local lux = nil;
			for _, r in ipairs(order) do
				if OvalFits(i, r) and not Clashes(i, r) then lux = r; break end
			end
			if lux then
				OvalSet(i, lux, 1);
				used[lux] = (used[lux] or 0) + 1;
				byType[lux] = byType[lux] or {};
				table.insert(byType[lux], i);
				table.insert(centres, i);
				count = count + 1;
			end
		end
	end
end

function OvalPutOnAxis(i, res, amount)
	-- an axis plot is its own mirror image: change it so res fits and place it
	local row = oRules[res];
	local place = row[3][1];
	if place[1] == "hill" then oPlot[i] = PlotTypes.PLOT_HILLS
	elseif place[1] == "flat" then oPlot[i] = PlotTypes.PLOT_LAND
	elseif oPlot[i] == PlotTypes.PLOT_MOUNTAIN then oPlot[i] = PlotTypes.PLOT_HILLS end
	local tOK = false;
	for _, tt in ipairs(place[2]) do if oTerr[i] == tt then tOK = true end end
	if not tOK then oTerr[i] = place[2][1] end
	if place[3][1] == "none" then oFeat[i] = -1 else oFeat[i] = place[3][1] end
	if oFeat[i] == FeatureTypes.FEATURE_JUNGLE and oTerr[i] == TerrainTypes.TERRAIN_GRASS then oTerr[i] = TerrainTypes.TERRAIN_PLAINS end
	oRes[i] = res; oResAmt[i] = amount;
end

function OvalCentreStuff(luxTypes)
	-- The shared land on the centre line: the plots that are their own mirror
	-- image hold one copy that both sides can reach. Every 2-4 plots along the
	-- line something useful: a luxury, a strategic (bigger amounts), or food.
	local function ID(t) return (GameInfoTypes and GameInfoTypes[t]) or GameInfo.Resources[t].ID end
	local axis = {};
	for i = 0, oN - 1 do
		local onLine = oKind[i] == OVAL_AXIS;
		if oRotate then
			-- turned map: the west plots on the centre line (their copies sit on
			-- the line too, at the other end); not next to their own copy
			onLine = oKind[i] == OVAL_WEST and oAxisDist[i] <= 0.6 and OvalDist(i, oTwin[i]) >= 3;
		end
		if onLine and OvalIsLand(i) and oMain[i] and oRes[i] == -1 and not OvalIsWonder(i) then
			local ok = true;
			for _, s in ipairs(oStarts) do if OvalDist(i, s) < 3 or OvalDist(i, oTwin[s]) < 3 then ok = false end end
			if ok then table.insert(axis, i) end
		end
	end
	-- north to south
	table.sort(axis, function(p, q) return p > q end);
	local strat = {
		{ID("RESOURCE_IRON"), 4, 6}, {ID("RESOURCE_HORSE"), 4, 6}, {ID("RESOURCE_COAL"), 5, 8},
		{ID("RESOURCE_OIL"), 5, 8}, {ID("RESOURCE_ALUMINUM"), 4, 6}, {ID("RESOURCE_URANIUM"), 3, 5},
	};
	local food = {ID("RESOURCE_WHEAT"), ID("RESOURCE_COW"), ID("RESOURCE_BISON"), ID("RESOURCE_SHEEP"), ID("RESOURCE_DEER")};
	local last = nil;
	local nextGap = 2 + OvalRand(3);
	local log = {lux = 0, strat = 0, food = 0};
	local axisLuxUsed = {};
	for _, i in ipairs(axis) do
		if last == nil or OvalDist(i, last) >= nextGap then
			local roll = OvalRand(100);
			if roll < 40 and #luxTypes > 0 then
				-- a different type each time along the line
				local pick = nil;
				for _, l in ipairs(OvalShuffle({unpack(luxTypes)})) do
					if not axisLuxUsed[l] then pick = l; break end
				end
				if pick == nil then axisLuxUsed = {}; pick = luxTypes[OvalRand(#luxTypes) + 1] end
				axisLuxUsed[pick] = true;
				OvalPutOnAxis(i, pick, 1);
				log.lux = log.lux + 1;
			elseif roll < 70 then
				local st = strat[OvalRand(#strat) + 1];
				OvalPutOnAxis(i, st[1], st[2] + OvalRand(st[3] - st[2] + 1));
				log.strat = log.strat + 1;
			else
				OvalPutOnAxis(i, food[OvalRand(#food) + 1], 1);
				log.food = log.food + 1;
			end
			last = i;
			nextGap = 2 + OvalRand(3);
		end
	end
	oCentreLog = log;
end
oCentreLog = {};

------------------------------------------------------------------------------
-- 10. CAPITAL CLEAN-UP (west capitals; the mirror copies it)
------------------------------------------------------------------------------
function OvalPrepareCapitals()
	local T = TerrainTypes;
	oStartSet = {};
	for _, s in ipairs(oStarts) do
		oStartSet[s] = true;
		oFeat[s] = -1;
		oRes[s] = -1;
		if oTerr[s] == T.TERRAIN_DESERT or oTerr[s] == T.TERRAIN_TUNDRA or oTerr[s] == T.TERRAIN_SNOW then oTerr[s] = T.TERRAIN_PLAINS end
		local ring = OvalRing(s, 1, 2);
		for _, j in ipairs(ring) do
			if oKind[j] == OVAL_WEST and oTerr[j] == T.TERRAIN_SNOW then oTerr[j] = T.TERRAIN_TUNDRA end
		end
		-- soften: at most 3 desert/tundra tiles within 2, no mountains next to it,
		-- at most 2 mountains within 2, one hill at least
		local bad = {};
		local hills, mtns = 0, 0;
		for _, j in ipairs(ring) do
			if OvalIsLand(j) and oKind[j] == OVAL_WEST then
				if oTerr[j] == T.TERRAIN_DESERT and oFeat[j] ~= FeatureTypes.FEATURE_FLOOD_PLAINS or oTerr[j] == T.TERRAIN_TUNDRA or oTerr[j] == T.TERRAIN_SNOW then table.insert(bad, j) end
				if oPlot[j] == PlotTypes.PLOT_HILLS then hills = hills + 1 end
				if oPlot[j] == PlotTypes.PLOT_MOUNTAIN then
					mtns = mtns + 1;
					if OvalDist(s, j) == 1 or mtns > 2 then oPlot[j] = PlotTypes.PLOT_HILLS; hills = hills + 1 end
				end
			end
		end
		OvalShuffle(bad);
		for k = 4, #bad do
			local j = bad[k];
			oTerr[j] = (OvalRand(2) == 0) and T.TERRAIN_PLAINS or T.TERRAIN_GRASS;
			if oFeat[j] == FeatureTypes.FEATURE_OASIS then oFeat[j] = -1 end
		end
		if hills == 0 then
			for _, j in ipairs(OvalShuffle(OvalRing(s, 1, 2))) do
				if OvalIsLand(j) and oKind[j] == OVAL_WEST and oPlot[j] == PlotTypes.PLOT_LAND and oFeat[j] ~= FeatureTypes.FEATURE_FLOOD_PLAINS then
					oPlot[j] = PlotTypes.PLOT_HILLS; break;
				end
			end
		end
	end
end

------------------------------------------------------------------------------
-- 11. NATURAL WONDERS (pairs, one per side)
------------------------------------------------------------------------------
function OvalPlaceWonders()
	local list = {};
	local mtnNW = {"FEATURE_FUJI", "FEATURE_KILIMANJARO", "FEATURE_MT_SINAI", "FEATURE_MT_KAILASH", "FEATURE_SRI_PADA", "FEATURE_POTOSI", "FEATURE_ULURU", "FEATURE_CRATER", "FEATURE_MESA", "FEATURE_GEYSER"};
	local flatNW = {"FEATURE_FOUNTAIN_YOUTH", "FEATURE_SOLOMONS_MINES"};	-- never El Dorado on mirror maps (user)
	-- natural wonders are not in the FeatureTypes enum in the game: look them up
	local function FID(t)
		local row = GameInfo.Features[t];
		if row ~= nil then return row.ID end
		return nil;
	end
	for _, t in ipairs(mtnNW) do if FID(t) then table.insert(list, {FID(t), true}) end end
	for _, t in ipairs(flatNW) do if FID(t) then table.insert(list, {FID(t), false}) end end
	OvalShuffle(list);
	local nPairs = math.max(1, math.min(3, math.floor((#oStarts + 1) / 2)));
	local cands = {};
	for i = 0, oN - 1 do
		if oKind[i] == OVAL_WEST and oMain[i] and OvalIsLand(i) and oAxisDist[i] > 2 and oRes[i] == -1 and not OvalIsCoastLand(i) then
			local ok = true;
			for _, s in ipairs(oStarts) do if OvalDist(i, s) < 5 then ok = false end end
			if ok then table.insert(cands, i) end
		end
	end
	OvalShuffle(cands);
	local done = {};
	local k = 1;
	for _, i in ipairs(cands) do
		if #done >= nPairs or k > #list then break end
		local ok = true;
		for _, d in ipairs(done) do if OvalDist(i, d) < 8 then ok = false end end
		if ok then
			local nw = list[k]; k = k + 1;
			oPlot[i] = nw[2] and PlotTypes.PLOT_MOUNTAIN or PlotTypes.PLOT_LAND;
			if oTerr[i] == TerrainTypes.TERRAIN_SNOW then oTerr[i] = TerrainTypes.TERRAIN_TUNDRA end
			oFeat[i] = nw[1];
			table.insert(done, i);
		end
	end
	-- one game in three: one more wonder right on the centre line, shared
	-- (a mountain wonder on a plot that is its own mirror image)
	oAxisWonder = nil;
	if OvalRand(3) == 0 and k <= #list then
		local nw = nil;
		for kk = k, #list do if list[kk][2] then nw = list[kk]; break end end
		if nw ~= nil then
			local spots = {};
			for i = 0, oN - 1 do
				if oKind[i] == OVAL_AXIS and oMain[i] and OvalIsLand(i) and not OvalIsCoastLand(i) and oSeamDist[i] > 2 then
					local ok = true;
					for _, st in ipairs(oStarts) do if OvalDist(i, st) < 5 or OvalDist(i, oTwin[st]) < 5 then ok = false end end
					for _, d in ipairs(done) do if OvalDist(i, d) < 4 or OvalDist(i, oTwin[d]) < 4 then ok = false end end
					if ok then table.insert(spots, i) end
				end
			end
			if #spots > 0 then
				local i = spots[OvalRand(#spots) + 1];
				oPlot[i] = PlotTypes.PLOT_MOUNTAIN;
				if oTerr[i] == TerrainTypes.TERRAIN_SNOW then oTerr[i] = TerrainTypes.TERRAIN_TUNDRA end
				oFeat[i] = nw[1];
				oRes[i] = -1;
				oAxisWonder = i;
			end
		end
	end
	oWonders = done;
end
oWonders = {};

------------------------------------------------------------------------------
-- 12. CITY STATES
------------------------------------------------------------------------------
function OvalCityStateTrait(id)
	local ok, t = pcall(function() return Players[id]:GetMinorCivTrait() end);
	if ok and t ~= nil and t >= 0 then return t end
	local ok2, t2 = pcall(function()
		local row = GameInfo.MinorCivilizations[PreGame.GetMinorCivType(id)];
		return row and row.MinorCivTrait or -1;
	end);
	if ok2 and t2 ~= nil then return t2 end
	return -1;
end

function OvalPlaceCityStates()
	local cs = {};
	for id = GameDefines.MAX_MAJOR_CIVS, GameDefines.MAX_CIV_PLAYERS - 1 do
		local p = Players[id];
		if p ~= nil and p:IsEverAlive() then table.insert(cs, id) end
	end
	-- pair by trait: same trait together, the rest paired in order
	local byTrait, traits = {}, {};
	for _, id in ipairs(cs) do
		local t = tostring(OvalCityStateTrait(id));
		if byTrait[t] == nil then byTrait[t] = {}; table.insert(traits, t) end
		table.insert(byTrait[t], id);
	end
	table.sort(traits);
	local pairsList, leftovers = {}, {};
	for _, t in ipairs(traits) do
		local l = byTrait[t];
		for k = 1, #l - 1, 2 do table.insert(pairsList, {l[k], l[k + 1]}) end
		if #l % 2 == 1 then table.insert(leftovers, l[#l]) end
	end
	for k = 1, #leftovers - 1, 2 do table.insert(pairsList, {leftovers[k], leftovers[k + 1]}) end
	local odd = (#leftovers % 2 == 1) and leftovers[#leftovers] or nil;
	-- sites on the west half: far from capitals, spread (farthest point first)
	local cands = {};
	local Fe = FeatureTypes;
	for i = 0, oN - 1 do
		if oKind[i] == OVAL_WEST and OvalIsLand(i) and oPlot[i] ~= PlotTypes.PLOT_MOUNTAIN and oAxisDist[i] >= 2
			and oSeamDist[i] >= 1 and not oStartSet[i] and oRes[i] == -1 and not OvalIsWonder(i)
			and (oFeat[i] == -1 or oFeat[i] == Fe.FEATURE_FOREST or oFeat[i] == Fe.FEATURE_JUNGLE or oFeat[i] == Fe.FEATURE_MARSH) then
			table.insert(cands, i);
		end
	end
	local sites = {};
	local capAll = {};
	for _, s in ipairs(oStarts) do table.insert(capAll, s); table.insert(capAll, oTwin[s]) end
	local function MinDist(i, list)
		local m = 999;
		for _, o in ipairs(list) do local d = OvalDist(i, o); if d < m then m = d end end
		return m;
	end
	OvalShuffle(cands);
	-- the islands made for city states come first (one city state each)
	local onIsland = {};
	for _, i in ipairs(cands) do onIsland[i] = true end
	local islandSites = {};
	for _, isl in ipairs(oCsIslands) do
		local pick, pv = nil, nil;
		for _, i in ipairs(isl) do
			if onIsland[i] then
				local v = OvalLandNbrs(i) + (oPlot[i] == PlotTypes.PLOT_HILLS and 1 or 0);
				if pv == nil or v > pv then pick, pv = i, v end
			end
		end
		if pick then table.insert(islandSites, pick) end
	end
	for p = 1, #pairsList do
		local best, bestV = islandSites[p], -1;
		if best ~= nil and OvalDist(best, oTwin[best]) < 4 then best = nil end
		if best == nil then
		for _, i in ipairs(cands) do
			local dc = MinDist(i, capAll);
			if dc >= 5 then
				local others = {};
				for _, s in ipairs(sites) do table.insert(others, s); table.insert(others, oTwin[s]) end
				local ds = MinDist(i, others);
				local dt = OvalDist(i, oTwin[i]);
				if ds >= 4 and dt >= 4 then
					local v = math.min(dc, 7) * 1.0 + math.min(ds, 10) * 1.3 + OvalRandF();
					if OvalIsCoastLand(i) then v = v + 1.5 end	-- city states like the coast and bays
					if v > bestV then best, bestV = i, v end
				end
			end
		end
		end
		-- crowded: relax step by step (every city state must get a spot)
		for _, gap in ipairs({3, 2}) do
			if best == nil then
				for _, i in ipairs(cands) do
					local ok = MinDist(i, capAll) >= gap and OvalDist(i, oTwin[i]) >= 2;
					for _, s in ipairs(sites) do if OvalDist(i, s) < gap or OvalDist(i, oTwin[s]) < gap then ok = false end end
					if ok then best = i; break end
				end
			end
		end
		if best == nil then
			for _, i in ipairs(cands) do
				local ok = not oStartSet[i];
				for _, s in ipairs(sites) do if i == s then ok = false end end
				if ok then best = i; break end
			end
		end
		if best ~= nil then table.insert(sites, best) end
	end
	-- the odd one: a self-mirrored plot on the centre line, near the middle row
	local axisSite = nil;
	if odd ~= nil then
		local bestV = nil;
		for i = 0, oN - 1 do
			if oKind[i] == OVAL_AXIS and OvalIsLand(i) and oMain[i] and oPlot[i] ~= PlotTypes.PLOT_MOUNTAIN and oRes[i] == -1 then
				local _, cy = OvalCentre(i);
				local dc = MinDist(i, capAll);
				if dc >= 4 then
					local v = -math.abs(cy - oCentreY) + math.min(dc, 8);
					for _, s in ipairs(sites) do if OvalDist(i, s) < 4 or OvalDist(i, oTwin[s]) < 4 then v = v - 20 end end
					if bestV == nil or v > bestV then axisSite, bestV = i, v end
				end
			end
		end
	end
	if odd ~= nil and axisSite == nil then
		-- no plot is its own copy (turned map) or none was free: the land plot
		-- nearest the map centre, away from capitals and other city states
		local bestV = nil;
		local mx, my = oW / 2 - 0.5, (oH - 1) / 2;
		for i = 0, oN - 1 do
			if oKind[i] == OVAL_WEST and OvalIsLand(i) and oPlot[i] ~= PlotTypes.PLOT_MOUNTAIN and oRes[i] == -1 and not oStartSet[i] and not OvalIsWonder(i) then
				local cx, cy = OvalCentre(i);
				local dc = MinDist(i, capAll);
				if dc >= 3 then
					local v = -(math.abs(cx - mx) + math.abs(cy - my)) + math.min(dc, 6);
					for _, st in ipairs(sites) do if OvalDist(i, st) < 3 or OvalDist(i, oTwin[st]) < 3 then v = v - 20 end end
					if bestV == nil or v > bestV then axisSite, bestV = i, v end
				end
			end
		end
	end
	oCitySites = {};
	for p, site in ipairs(sites) do
		oFeat[site] = -1;
		table.insert(oCitySites, {site, pairsList[p][1]});
		table.insert(oCitySites, {oTwin[site], pairsList[p][2]});
	end
	if axisSite ~= nil then
		oFeat[axisSite] = -1;
		table.insert(oCitySites, {axisSite, odd});
	end
	oAllCs = cs;
end
oCitySites, oAllCs = {}, {};

------------------------------------------------------------------------------
-- 13. RUINS
------------------------------------------------------------------------------
function OvalPlaceRuins()
	local ok, noHuts = pcall(function() return Game.IsOption(GameOptionTypes.GAMEOPTION_NO_GOODY_HUTS) end);
	if ok and noHuts then return end
	local ok2, noEra = pcall(function() return GameInfo.Eras[Game.GetStartEra()].NoGoodies end);
	if ok2 and noEra then return end
	local goody = ImprovementTypes and ImprovementTypes.IMPROVEMENT_GOODY_HUT;
	local per = 40;
	if GameInfo.Improvements and GameInfo.Improvements.IMPROVEMENT_GOODY_HUT then
		goody = GameInfo.Improvements.IMPROVEMENT_GOODY_HUT.ID;
		per = GameInfo.Improvements.IMPROVEMENT_GOODY_HUT.TilesPerGoody or 40;
		if per <= 0 then per = 40 end
	end
	if goody == nil then return end
	local landN = 0;
	local cands = {};
	for i = 0, oN - 1 do
		if oKind[i] == OVAL_WEST and OvalIsLand(i) then
			landN = landN + 1;
			if oPlot[i] ~= PlotTypes.PLOT_MOUNTAIN and oRes[i] == -1 and oAxisDist[i] > 1 and oFeat[i] ~= FeatureTypes.FEATURE_ICE
				and not (oFeat[i] ~= -1 and GameInfo.Features[oFeat[i]] and GameInfo.Features[oFeat[i]].NaturalWonder) then
				table.insert(cands, i);
			end
		end
	end
	local want = math.floor(landN / per + 0.5);
	OvalShuffle(cands);
	local avoid = {};
	for _, s in ipairs(oStarts) do table.insert(avoid, {s, 3}); table.insert(avoid, {oTwin[s], 3}) end
	for _, c in ipairs(oCitySites) do table.insert(avoid, {c[1], 3}) end
	local placed = {};
	for _, i in ipairs(cands) do
		if #placed >= want then break end
		local good = true;
		for _, a in ipairs(avoid) do if OvalDist(i, a[1]) < a[2] then good = false; break end end
		if good then for _, p in ipairs(placed) do if OvalDist(i, p) < 4 then good = false; break end end end
		if good then oImp[i] = goody; table.insert(placed, i) end
	end
end

------------------------------------------------------------------------------
-- WRITE TO THE MAP
------------------------------------------------------------------------------
function OvalWritePlots()
	for i = 0, oN - 1 do
		local p = Map.GetPlotByIndex(i);
		if p:GetPlotType() ~= oPlot[i] then p:SetPlotType(oPlot[i], false, false) end
	end
end
function OvalWriteAll()
	OvalMirrorAll();
	OvalWritePlots();
	for i = 0, oN - 1 do
		local p = Map.GetPlotByIndex(i);
		p:SetTerrainType(oTerr[i], false, false);
	end
	-- The game must know its land and water areas before features go on:
	-- a natural wonder adds itself to its plot's area (no area = crash).
	Map.RecalculateAreas();
	OvalWriteRivers();
	for i = 0, oN - 1 do
		local p = Map.GetPlotByIndex(i);
		p:SetFeatureType(oFeat[i], -1);
	end
	for i = 0, oN - 1 do
		local p = Map.GetPlotByIndex(i);
		p:SetResourceType(oRes[i], oResAmt[i]);
		if oImp[i] ~= -1 then p:SetImprovementType(oImp[i]) end
	end
end

------------------------------------------------------------------------------
-- MAIN
------------------------------------------------------------------------------
function GenerateMap()
	print("Mirror Map: Pangaea - generating");
	OvalInitGeometry();
	for i = 0, oN - 1 do
		oPlot[i] = PlotTypes.PLOT_OCEAN; oTerr[i] = TerrainTypes.TERRAIN_OCEAN; oFeat[i] = -1;
		oRes[i] = -1; oResAmt[i] = 0; oImp[i] = -1;
	end
	OvalSplitPlayers();
	OvalRollSea();
	-- the land is made again (up to 5 times) when the starts cannot keep
	-- OVAL_START_GAP tiles apart
	for try = 1, 5 do
		for i = 0, oN - 1 do
			oPlot[i] = PlotTypes.PLOT_OCEAN; oTerr[i] = TerrainTypes.TERRAIN_OCEAN; oFeat[i] = -1;
		end
		OvalGenerateLand();
		OvalPlaceIslands();
		OvalPlaceCsIslands();
		OvalRelief();
		OvalGenerateTerrain();
		OvalAddLakes();
		OvalWaterTerrain();
		OvalMirrorAll();
		OvalAddRivers();
		oRiverSide = {};
		for _, r in ipairs(oRiver) do
			oRiverSide[r[1]] = true; oRiverSide[r[2]] = true;
			oRiverSide[oTwin[r[1]]] = true; oRiverSide[oTwin[r[2]]] = true;
		end
		OvalAddFeatures();
		OvalBarrenStrip();
		oLakeAtStart = OvalLakeSet();
		OvalSetupBias();
		OvalChooseStarts();
		oStartGap = OvalStartsMinGap(oStarts);
		for c, st in ipairs(oStarts) do
			print("Mirror Map: Pangaea - pair", c, "start", OvalOnSea(st) and "COAST" or "inland");
		end
		local closeOK = true;
		if oCloseMax ~= nil then
			local e = OvalClosestEnemy(oStarts);
			closeOK = (e == nil) or (e[4] <= oCloseMax);
		end
		if oStartGap >= OVAL_START_GAP and closeOK then break end
		print("Mirror Map: Pangaea - starts only", oStartGap, "apart, making the land again");
	end
	OvalPrepareCapitals();
	OvalInitResources();
	OvalPlaceWonders();
	oLakes = OvalLakeSet();
	OvalPlaceCapitalResources();
	OvalPlaceResources();
	OvalPlaceCityStates();
	OvalPlaceRuins();
	-- city sites keep nothing on their tile
	for _, s in ipairs(oStarts) do oFeat[s] = -1; oRes[s] = -1; oImp[s] = -1 end
	for _, c in ipairs(oCitySites) do
		local i = c[1];
		if oKind[i] == OVAL_EAST then i = oTwin[i] end
		oFeat[i] = -1; oRes[i] = -1; oImp[i] = -1;
	end
	OvalWriteAll();
	Map.RecalculateAreas();
	-- start plots
	for c, id in ipairs(oWestPlayers) do
		Players[id]:SetStartingPlot(Map.GetPlotByIndex(oStarts[c]));
	end
	for c, id in ipairs(oEastPlayers) do
		Players[id]:SetStartingPlot(Map.GetPlotByIndex(oTwin[oStarts[c]]));
	end
	for _, c in ipairs(oCitySites) do
		Players[c[2]]:SetStartingPlot(Map.GetPlotByIndex(c[1]));
	end
	Map.DefaultContinentStamper();
	print("Mirror Map: Pangaea - done", oW, oH);
	-- city states: max 1 luxury + quality option (twins treated the same)
	CSQ_Run(CSQ_Level(), function(i) local t = oTwin[i]; if t ~= nil and t >= 0 then return t end return nil end);
end
