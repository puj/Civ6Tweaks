
------------------------------------------------------------------------------
include "MapEnums"
include "MapUtilities"

------------------------------------------------------------------------------
-- **************************** YnAMP globals ******************************
------------------------------------------------------------------------------

print ("PUJ loading modded AssignStartingPlots")
local YnAMP_Version = GameInfo.GlobalParameters["YNAMP_VERSION"].Value -- can't use GlobalParameters.YNAMP_VERSION ?
print ("Yet (not) Another Maps Pack version " .. tostring(YnAMP_Version) .." (2016-2018) by Gedemon")
print ("Setting YnAMP globals and cache...")

g_startTimer = os.clock()

ExposedMembers.HistoricalStartingPlots = nil

-- Globals, can be called from the mapscript
mapName = MapConfiguration.GetValue("MapName")
print ("Map Name = " .. tostring(mapName))
getTSL 					= {} -- primary TSL for each civilization
isInGame 				= {} -- Civilization/Leaders type in game
tempStartingPlots 		= {} -- Temporary table for starting plots used when Historical Spawn Dates is set.
isResourceExcludedXY 	= {}
isResourceExclusiveXY 	= {}
isResourceExclusive 	= {}
-- get options
bCulturallyLinked 	= MapConfiguration.GetValue("CulturallyLinkedStart") == "PLACEMENT_ETHNIC";
bTSL 				= MapConfiguration.GetValue("CivilizationPlacement") == "PLACEMENT_TSL";
bResourceExclusion 	= MapConfiguration.GetValue("ResourcesExclusion") == "PLACEMENT_EXCLUDE";
bRequestedResources = MapConfiguration.GetValue("RequestedResources") == "PLACEMENT_REQUEST";
bRealDeposits 		= MapConfiguration.GetValue("RealDeposits") == "PLACEMENT_DEPOSIT";
bImportResources	= MapConfiguration.GetValue("ResourcesPlacement") == "PLACEMENT_IMPORT"
iIceNorth 			= MapConfiguration.GetValue("IceNorth")
iIceSouth 			= MapConfiguration.GetValue("IceSouth")
bAnalyseChokepoints	= not GameConfiguration.GetValue("FastLoad")
bPlaceAllLuxuries	= MapConfiguration.GetValue("PlaceAllLuxuries") == "PLACEMENT_REQUEST"
bAlternatePlacement = MapConfiguration.GetValue("AlternatePlacement")

-- Create list of Civilizations and leaders in game
for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
	local CivilizationTypeName = PlayerConfigurations[iPlayer]:GetCivilizationTypeName()
	local LeaderTypeName = PlayerConfigurations[iPlayer]:GetLeaderTypeName()
	if CivilizationTypeName then isInGame[CivilizationTypeName] = true end
	if LeaderTypeName 		then isInGame[LeaderTypeName] 		= true end
end

print ("ynAMP Options: Culturally Linked = " .. tostring(bCulturallyLinked) ..", TSL = " .. tostring(bTSL) ..", Exclusion Zones = " .. tostring(bResourceExclusion) ..", Requested Resources = " .. tostring(bRequestedResources)..", Real Deposits = " .. tostring(bRealDeposits) .. ", Place All Luxuries = ".. tostring(bPlaceAllLuxuries) ) 

------------------------------------------------------------------------------
-- YnAMP >>>>>
------------------------------------------------------------------------------

------------------------------------------------------------------------------
AssignStartingPlots = {};
------------------------------------------------------------------------------
function AssignStartingPlots.Create(args)
	local instance  = {

		-- Core Process member methods
		__InitStartingData					= AssignStartingPlots.__InitStartingData,
		__SetStartMajor						= AssignStartingPlots.__SetStartMajor,
		__SetStartMinor						= AssignStartingPlots.__SetStartMinor,
		__GetWaterCheck						= AssignStartingPlots.__GetWaterCheck,
		__GetValidAdjacent					= AssignStartingPlots.__GetValidAdjacent,
		__NaturalWonderBuffer				= AssignStartingPlots.__NaturalWonderBuffer,
		__BonusResource						= AssignStartingPlots.__BonusResource,
		__TryToRemoveBonusResource			= AssignStartingPlots.__TryToRemoveBonusResource,
		__LuxuryBuffer						= AssignStartingPlots.__LuxuryBuffer,
		__StrategicBuffer					= AssignStartingPlots.__StrategicBuffer,
		__CivilizationBuffer				= AssignStartingPlots.__CivilizationBuffer,
		__MajorCivBuffer					= AssignStartingPlots.__MajorCivBuffer,
		__MinorMajorCivBuffer				= AssignStartingPlots.__MinorMajorCivBuffer,
		__MinorMinorCivBuffer				= AssignStartingPlots.__MinorMinorCivBuffer,
		__BaseFertility						= AssignStartingPlots.__BaseFertility,
		__WeightedFertility					= AssignStartingPlots.__WeightedFertility,
		__AddBonusFoodProduction			= AssignStartingPlots.__AddBonusFoodProduction,
		__AddFood							= AssignStartingPlots.__AddFood,
		__AddProduction						= AssignStartingPlots.__AddProduction,
		__InitStartBias						= AssignStartingPlots.__InitStartBias,
		__StartBiasResources				= AssignStartingPlots.__StartBiasResources,
		__StartBiasFeatures					= AssignStartingPlots.__StartBiasFeatures,
		__StartBiasTerrains					= AssignStartingPlots.__StartBiasTerrains,
		__StartBiasRivers					= AssignStartingPlots.__StartBiasRivers,
		-- Maritime CS <<<<<
		__StartBiasCoast					= AssignStartingPlots.__StartBiasCoast,
		-- Maritime CS >>>>>
		__StartBiasPlotRemoval				= AssignStartingPlots.__StartBiasPlotRemoval,
		__SortByArray						= AssignStartingPlots.__SortByArray,
		__ArraySize							= AssignStartingPlots.__ArraySize,				
		__PreFertilitySort					= AssignStartingPlots.__PreFertilitySort,			
		__SortByFertilityArray				= AssignStartingPlots.__SortByFertilityArray,	
		__AddResourcesBalanced				= AssignStartingPlots.__AddResourcesBalanced,
		__AddResourcesLegendary				= AssignStartingPlots.__AddResourcesLegendary,
		__BalancedStrategic					= AssignStartingPlots.__BalancedStrategic,
		__FindSpecificStrategic				= AssignStartingPlots.__FindSpecificStrategic,
		__AddStrategic						= AssignStartingPlots.__AddStrategic,
		__AddLuxury							= AssignStartingPlots.__AddLuxury,
		__AddBonus							= AssignStartingPlots.__AddBonus,
		__IsContinentalDivide				= AssignStartingPlots.__IsContinentalDivide,

		iNumMajorCivs = 0,
		iResourceEraModifier = 1,
		iNumMinorCivs = 0,			
		iNumRegions		= 0,
		iDefaultNumberMajor = 0,
		iDefaultNumberMinor = 0,
		uiMinMajorCivFertility = args.MIN_MAJOR_CIV_FERTILITY or 0,
		uiMinMinorCivFertility = args.MIN_MINOR_CIV_FERTILITY or 0,
		uiStartMinY = args.START_MIN_Y or 0,
		uiStartMaxY = args.START_MAX_Y or 0,
		uiStartConfig = args.START_CONFIG or 2,
		waterMap  = args.WATER or false,
		landMap  = args.LAND or false,
		majorStartPlots = {},
		majorCopy = {},
		minorStartPlots = {},	
		minorCopy = {},
		majorList		= {},
		minorList		= {},
		player_ID_list	= {},
		playerstarts = {},
		sortedArray = {},
		sortedFertilityArray = {},

		-- Team info variables (not used in the core process, but necessary to many Multiplayer map scripts)
		
	}

	--instance:__InitStartingData()
	-- YnAMP <<<<<
	if not bTSL then
		instance:__InitStartingData()
	end	
	YnAMP_StartPositions()	
	-- YnAMP >>>>>					

	return instance
end
------------------------------------------------------------------------------
function AssignStartingPlots:__InitStartingData()
	if(self.uiMinMajorCivFertility <= 0) then
		self.uiMinMajorCivFertility = 5;
	end

	if(self.uiMinMinorCivFertility <= 0) then
		self.uiMinMinorCivFertility = 5;
	end

	self.iNumMajorCivs = PlayerManager.GetAliveMajorsCount();	
	self.iNumMinorCivs = PlayerManager.GetAliveMinorsCount();
		
	self.iNumRegions = self.iNumMajorCivs + self.iNumMinorCivs;
	local iMinNumBarbarians = self.iNumMajorCivs / 2;

	StartPositioner.DivideMapIntoMajorRegions(self.iNumMajorCivs, self.uiMinMajorCivFertility, self.uiMinMinorCivFertility);
	
	local iMajorCivStartLocs = StartPositioner.GetNumMajorCivStarts();

	--Find Default Number
	MapSizeTypes = {};
	for row in GameInfo.Maps() do
		MapSizeTypes[row.RowId] = row.DefaultPlayers;
	end
	local sizekey = Map.GetMapSize() + 1;
	local iDefaultNumberPlayers = MapSizeTypes[sizekey] or 8;
	self.iDefaultNumberMajor = iDefaultNumberPlayers ;
	self.iDefaultNumberMinor = math.floor(iDefaultNumberPlayers * 1.5);

	self.iIndex = 0;
	self.player_ID_list = {};
	for i = 0, (self.iNumRegions) - 1 do
		table.insert(self.player_ID_list, i);
	end

	self.majorList = {};
	self.minorList = {};

	self.majorList = PlayerManager.GetAliveMajorIDs();
	self.minorList = PlayerManager.GetAliveMinorIDs();

	-- Place the major civ start plots in an array
	self.majorStartPlots = {};
	local failed = 0;
	for i = self.iNumMajorCivs - 1, 0, - 1 do
		plots = StartPositioner.GetMajorCivStartPlots(i);
		local startPlot = self:__SetStartMajor(plots, i);
		if(startPlot ~= nil) then
			StartPositioner.MarkMajorRegionUsed(i);
			table.insert(self.majorStartPlots, startPlot);
			info = StartPositioner.GetMajorCivStartInfo(i);
			print ("ContinentType: " .. tostring(info.ContinentType));
			print ("LandmassID: " .. tostring(info.LandmassID));
			print ("Fertility: " .. tostring(info.Fertility));
			print ("TotalPlots: " .. tostring(info.TotalPlots));
			print ("WestEdge: " .. tostring(info.WestEdge));
			print ("EastEdge: " .. tostring(info.EastEdge));
			print ("NorthEdge: " .. tostring(info.NorthEdge));
			print ("SouthEdge: " .. tostring(info.SouthEdge));
		else
			failed = failed + 1;
			info = StartPositioner.GetMajorCivStartInfo(i);
			print ("-- START FAILED MAJOR --");
			print ("ContinentType: " .. tostring(info.ContinentType));
			print ("LandmassID: " .. tostring(info.LandmassID));
			print ("Fertility: " .. tostring(info.Fertility));
			print ("TotalPlots: " .. tostring(info.TotalPlots));
			print ("WestEdge: " .. tostring(info.WestEdge));
			print ("EastEdge: " .. tostring(info.EastEdge));
			print ("NorthEdge: " .. tostring(info.NorthEdge));
			print ("SouthEdge: " .. tostring(info.SouthEdge));
			print ("-- END FAILED MAJOR --");
		end
	end
	for k, plot in ipairs(self.majorStartPlots) do
		table.insert(self.majorCopy, plot);
	end

	--Begin Start Bias for major
	self:__InitStartBias(false);

	if(self.uiStartConfig == 1 ) then
		self:__AddResourcesBalanced();
	elseif(self.uiStartConfig == 3 ) then
		self:__AddResourcesLegendary();
	end

	for i = 1, self.iNumMajorCivs do
		local player = Players[self.majorList[i]]
		
		if(player == nil) then
			print("THIS PLAYER FAILED");
		else
			local hasPlot = false;
			for k, v in pairs(self.playerStarts[i]) do
				if(v~= nil and hasPlot == false) then
					hasPlot = true;
					player:SetStartingPlot(v);
					print("Major Start X: ", v:GetX(), "Major Start Y: ", v:GetY());
				end
			end
		end
	end

	StartPositioner.DivideMapIntoMinorRegions(self.iNumMinorCivs);

	local iMinorCivStartLocs = StartPositioner.GetNumMinorCivStarts();
	local i = 0;
	local valid = 0;
	plots = GetAllPlotsRandomized();
	-- while i <= iMinorCivStartLocs - 1 and valid < self.iNumMinorCivs do
	while i <= #plots - 1 do
		-- plots = StartPositioner.GetMinorCivStartPlots(i);
		local startPlot = self:__SetStartMinor(plots);
		if(startPlot~=nil)then
			print("Placing minor at :", startPlot:GetIndex());
		else
			print("No plot found for minor: ",i);
		end
		print("Plots remaining : ", #plots)
		-- info = StartPositioner.GetMinorCivStartInfo(i);
		if(startPlot ~= nil) then
			table.insert(self.minorStartPlots, startPlot);
			-- print ("Minor ContinentType: " .. tostring(info.ContinentType));
			-- print ("Minor LandmassID: " .. tostring(info.LandmassID));
			-- print ("Minor Fertility: " .. tostring(info.Fertility));
			-- print ("Minor TotalPlots: " .. tostring(info.TotalPlots));
			-- print ("Minor WestEdge: " .. tostring(info.WestEdge));
			-- print ("Minor EastEdge: " .. tostring(info.EastEdge));
			-- print ("Minor NorthEdge: " .. tostring(info.NorthEdge));
			-- print ("Minor SouthEdge: " .. tostring(info.SouthEdge));
			valid = valid + 1;
		else
			print ("-- START FAILED MINOR --");
			-- print ("Minor ContinentType: " .. tostring(info.ContinentType));
			-- print ("Minor LandmassID: " .. tostring(info.LandmassID));
			-- print ("Minor Fertility: " .. tostring(info.Fertility));
			-- print ("Minor TotalPlots: " .. tostring(info.TotalPlots));
			-- print ("Minor WestEdge: " .. tostring(info.WestEdge));
			-- print ("Minor EastEdge: " .. tostring(info.EastEdge));
			-- print ("Minor NorthEdge: " .. tostring(info.NorthEdge));
			-- print ("Minor SouthEdge: " .. tostring(info.SouthEdge));
			-- print ("-- END FAILED MINOR --");
		end
		
		i = i + 1;
	end

	for k, plot in ipairs(self.minorStartPlots) do
		table.insert(self.minorCopy, plot);
	end

	print("Got ", #self.minorStartPlots, " minor start plots");

	--Begin Start Bias for minor
	self:__InitStartBias(true);

	for i = 1, self.iNumMinorCivs do
		local player = Players[self.minorList[i]]
		-- Maritime CS <<<<<
		local leader	:string = PlayerConfigurations[self.minorList[i]]:GetLeaderTypeName();
		local civilizationType = PlayerConfigurations[self.minorList[i]]:GetCivilizationTypeName()
		local leaderInfo:table	= GameInfo.Leaders[leader];
		if(player == nil or leader == "LEADER_MINOR_CIV_MARITIME" or leaderInfo.InheritFrom == "LEADER_MINOR_CIV_MARITIME") then
		-- Maritime CS >>>>>
			--print("THIS PLAYER FAILED");
		else
			local hasPlot = false;
			for k, v in pairs(self.playerStarts[i + self.iNumMajorCivs]) do
				if(v~= nil and hasPlot == false) then
					hasPlot = true;
					player:SetStartingPlot(v);
					print("Minor Start X: ", v:GetX(), "Minor Start Y: ", v:GetY());
				end
			end
		end
	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__SetStartMajor(plots, iMajorIndex)
	-- Sort by fertility of all the plots
	-- eliminate them if they do not meet the following:
	-- distance to another civilization
	-- distance to a natural wonder
	-- minimum production
	-- minimum food
	-- minimum luxuries
	-- minimum strategic

	sortedPlots ={};

	if plots == nil then
		return;
	end

	local iSize = #plots;
	local iContinentIndex = 1;

	-- Nothing there?  Just exit, returing nil
	if iSize == 0 then
		return;
	end
	
	for i, plot in ipairs(plots) do
		row = {};
		row.Plot = plot;
		row.Fertility = self:__WeightedFertility(plot, iMajorIndex, true);
		table.insert (sortedPlots, row);
	end

	if(self.uiStartConfig > 1 ) then
		table.sort (sortedPlots, function(a, b) return a.Fertility > b.Fertility; end);
	else
		self.sortedFertilityArray = {};
		sortedPlotsFertility = {};
		sortedPlotsFertility = self:__PreFertilitySort(sortedPlots);
		self:__SortByFertilityArray(sortedPlots, sortedPlotsFertility);
		for k, v in pairs(sortedPlots) do
			sortedPlots[k] = nil;
		end
		for i, newPlot in ipairs(self.sortedFertilityArray) do
			row = {};
			row.Plot = newPlot.Plot;
			row.Fertility = newPlot.Fertility;
			table.insert (sortedPlots, row);
		end
	end



	local bValid = false;
	local pFallback:table = Map.GetPlotByIndex(sortedPlots[1].Plot);
	local iFallBackScore = -1;
	while bValid == false and iSize >= iContinentIndex do
		bValid = true;
		local NWMajor = 0;
		pTempPlot = Map.GetPlotByIndex(sortedPlots[iContinentIndex].Plot);
		iContinentIndex = iContinentIndex + 1;
		--print("Fertility: ", sortedPlots[iContinentIndex].Fertility)

		-- Checks to see if the plot is impassable
		if(pTempPlot:IsImpassable() == true) then
			bValid = false;
		else
			local iFallBackScoreTemp = 0;
			if (iFallBackScore < iFallBackScoreTemp) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
		end

		-- Checks to see if the plot is water
		if(pTempPlot:IsWater() == true) then
			bValid = false;
		else
			local iFallBackScoreTemp = 1;
			if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
		end

		-- Checks to see if there are any major civs in the given distance
		local bMajorCivCheck = self:__MajorCivBuffer(pTempPlot); 
		if(bMajorCivCheck == false) then
		       bValid = false;
		else
			local iFallBackScoreTemp = 2;
			if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
		    end
		end

		-- Checks to see if there are luxuries
		if (math.ceil(self.iDefaultNumberMajor * 1.25) + self.iDefaultNumberMinor > self.iNumMinorCivs + self.iNumMajorCivs) then
			local bLuxuryCheck = self:__LuxuryBuffer(pTempPlot); 
			if(bLuxuryCheck  == false) then
				bValid = false;
			else
				local iFallBackScoreTemp = 3;
			if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
			end
		end
		

		--Checks to see if there are strategics
		-- local bStrategicCheck = self:__StrategicBuffer(pTempPlot); 
		-- if(bStrategicCheck  == false) then
		-- 	bValid = false;
		-- end

		-- Checks to see if there is fresh water or coast
		local bWaterCheck = self:__GetWaterCheck(pTempPlot); 
		if(bWaterCheck == false) then
			bValid = false;
		else
			local iFallBackScoreTemp = 4;
			if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
		end

		local bValidAdjacentCheck = self:__GetValidAdjacent(pTempPlot, 0); 
		if(bValidAdjacentCheck == false) then
			bValid = false;
		else
			local iFallBackScoreTemp = 5;
			if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
		end

		-- Checks to see if there are natural wonders in the given distance
		local bNaturalWonderCheck = self:__NaturalWonderBuffer(pTempPlot, false); 
		if(bNaturalWonderCheck == false) then
			bValid = false;
		else
			local iFallBackScoreTemp = 6;
			if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
		end

		-- Checks to see if there are resources
		if(pTempPlot:GetResourceCount() > 0) then
		   local bValidResource = self:__BonusResource(pTempPlot);
		    if(bValidResource == false) then
			bValid = false;
		end
		else
			local iFallBackScoreTemp = 7;
			if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
		end

		-- Checks to see if there is an Oasis
		local featureType = pTempPlot:GetFeatureType();
		if(featureType == g_FEATURE_OASIS) then
			bValid = false;
		end

		-- If the plots passes all the checks then the plot equals the temp plot
		if(bValid == true) then
			self:__TryToRemoveBonusResource(pTempPlot);
			self:__AddBonusFoodProduction(pTempPlot);
			return pTempPlot;
		end
	end
 
	return pFallback;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__SetStartMinor(plots)
	-- Sort by fertility of all the plots
	-- eliminate them if they do not meet the following:
	-- distance to another civilization
	-- distance to a natural wonder
	-- minimum production
	-- minimum food

	sortedPlots ={};

	if plots == nil then
		print("No plots found");
		return nil;
	end
	
	local iSize = #plots;

	-- Nothing there?  Just exit, returing nil
	if iSize == 0 then
		print("Empty plot list");
		return nil;
	end

	-- local iContinentIndex = 1;
	local iPlotIndex = 1;

	for i, plot in ipairs(plots) do
		row = {};
		row.Plot = plot;
		row.Fertility = self:__BaseFertility(plot);
		table.insert (sortedPlots, row);
	end

	table.sort (sortedPlots, function(a, b) return a.Fertility > b.Fertility; end);

	shuffle_table(sortedPlots);
	print("Shuffling",#sortedPlots," Plots for minor civs");

	local bValid = false;
	-- local pFallback:table = Map.GetPlotByIndex(sortedPlots[1].Plot);
	local pFallback:table = nil;
	local iFallBackScore = -1;
	-- while bValid == false and iSize >= iContinentIndex do
	while bValid == false and #plots >= iPlotIndex do
		bValid = true;
		local NWMinor = 2;
		-- pTempPlot = sortedPlots[iPlotIndex].Plot;
		pTempPlot = plots[iPlotIndex];
		-- print("Got plot : ", pTempPlot);
		for i,v in pairs(pTempPlot) do
			if type(v) == "function" then
				print(i,v,debug.getinfo(v))
			end
		end
		-- pTempPlot = Map.GetPlotByIndex(sortedPlots[iContinentIndex].Plot);
		-- iContinentIndex = iContinentIndex + 1;
		iPlotIndex = iPlotIndex + 1;
		--print("Fertility: ", sortedPlots[iContinentIndex].Fertility)

		-- print("Checking plot : ", pTempPlot.GetIndex());
		-- Checks to see if the plot is impassable
		if(pTempPlot:IsImpassable() == true) then
		print("Minor Placement Failed: Impassable");
			bValid = false;
		else
			local iFallBackScoreTemp = 0;
			if (iFallBackScore < iFallBackScoreTemp) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
		end

		-- Checks to see if the plot is water
		if(pTempPlot:IsWater() == true) then
		-- print("Minor Placement Failed: Water");
			bValid = false;
		else
			local iFallBackScoreTemp = 1;
			if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
		end

		-- Checks to see if there are any minor civs in the given distance
		local bMinorCivCheck = self:__MinorMinorCivBuffer(pTempPlot); 
		if(bMinorCivCheck == false) then
		-- print("Minor Placement Failed: MinorMinor");
				bValid = false;
		else
			local iFallBackScoreTemp = 2;
			if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
		end
		-- Checks to see if there are any minor civs in the given distance
		local bMinorCivCheck = self:__MinorMajorCivBuffer(pTempPlot); 
		if(bMinorCivCheck == false) then
		-- print("Minor Placement Failed: MinorMajor");
			bValid = false;
		else
			local iFallBackScoreTemp = 3;
			if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
		end		


		local bValidAdjacentCheck = self:__GetValidAdjacent(pTempPlot, 2); 
		if(bValidAdjacentCheck == false) then
		-- print("Minor Placement Failed: Adjacent");
			bValid = false;
		else
			local iFallBackScoreTemp = 4;
			if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
		end

		-- Checks to see if there are natural wonders in the given distance
		local bNaturalWonderCheck = self:__NaturalWonderBuffer(pTempPlot, true); 
		if(bNaturalWonderCheck == false) then
		print("Minor Placement Failed: Wonder");
			bValid = false;
		else
			local iFallBackScoreTemp = 5;
			if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
		end

		-- Checks to see if there are resources
		if(pTempPlot:GetResourceCount() > 0) then
			local bValidResource = self:__BonusResource(pTempPlot);
			if(bValidResource == false) then
			bValid = false;
		end
		-- print("Minor Placement Failed: ResourceCount");
		else
			local iFallBackScoreTemp = 6;
			if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
		end

		-- Checks to see if there is an Oasis
		local featureType = pTempPlot:GetFeatureType();
		if(featureType == g_FEATURE_OASIS) then
			bValid = false;
		end

		-- If the plots passes all the checks then the plot equals the temp plot
		if(bValid == true) then
			self:__TryToRemoveBonusResource(pTempPlot);
			return pTempPlot;
		else
			table.remove(plots, iPlotIndex)
		end
	end
 
	return pFallback;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__GetWaterCheck(plot)

	--Checks to see if there is water: rivers, it is a coastal hex, or adjacent fresh water
	local gridWidth, gridHeight = Map.GetGridSize();

	if(plot:IsFreshWater() == true) then
		return true;
	elseif( plot:IsCoastalLand() == true) then
		return true;
	end

	return false;
end
------------------------------------------------------------------------------
function AssignStartingPlots:__GetValidAdjacent(plot, minor)
	
	local impassable = 0;
	local food = 0;
	local production = 0;
	local water = 0;
	local desert = 0;
	local snow = 0;
	local gridWidth, gridHeight = Map.GetGridSize();
	local terrainType = plot:GetTerrainType();

	-- Add to the Snow Desert counter if snow shows up
	if(terrainType == g_TERRAIN_TYPE_SNOW or terrainType == g_TERRAIN_TYPE_SNOW_HILLS) then
		snow = snow + 1;
	end
	
	-- Add to the Snow Desert counter if desert shows up
	if(terrainType == g_TERRAIN_TYPE_DESERT or terrainType == g_TERRAIN_TYPE_DESERT_HILLS) then
		desert = desert + 1;
	end

	local max = 0;
	local min = 0; 
	if(minor == 0) then
		max = math.ceil(gridHeight * self.uiStartMaxY / 100);
		min = math.ceil(gridHeight * self.uiStartMinY / 100);
	end

	if(plot:GetY() <= min or plot:GetY() > gridHeight - max) then
		return false;
	end

	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), direction);
		if (adjacentPlot ~= nil) then
			terrainType = adjacentPlot:GetTerrainType();
			if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
				-- Checks to see if the plot is impassable
				if(adjacentPlot:IsImpassable() == true) then
					impassable = impassable + 1;
				end

				-- Checks to see if the plot is water
				if(adjacentPlot:IsWater() == true) then
					water = water + 1;
				end

				-- Add to the Snow Desert counter if snow shows up
				if(terrainType == g_TERRAIN_TYPE_SNOW or terrainType == g_TERRAIN_TYPE_SNOW_HILLS) then
					snow = snow + 1;
				end
			
				-- Add to the Snow Desert counter if desert shows up
				if(terrainType == g_TERRAIN_TYPE_DESERT or terrainType == g_TERRAIN_TYPE_DESERT_HILLS) then
					desert = desert + 1;
				end

				food = food + adjacentPlot:GetYield(g_YIELD_FOOD);
				production = production + adjacentPlot:GetYield(g_YIELD_PRODUCTION);
			else
				impassable = impassable + 1;
			end
		end
	end 

	--if(minor == 0) then
	--	print("X: ", plot:GetX(), " Y: ", plot:GetY(), " Food ", food, "Production: ", production);
	--end

	local balancedStart = 0;
	if(self.uiStartConfig == 1 and  minor == 0) then
		balancedStart = 1;
	end

	if((impassable >= 2 + minor - balancedStart or (self.landMap == true and impassable >= 2 + minor)) and self.waterMap == false) then
		return false;
	elseif(self.waterMap == true and impassable >= 2 + minor * 2 - balancedStart) then
		return false;
	elseif(water + impassable  >= 4 + minor - balancedStart and self.waterMap == false) then
		return false;
	elseif(water >= 3 + minor - balancedStart) then
		return false;
	elseif(water >= 4 + minor and self.waterMap == true) then
		return false;
	elseif(minor == 0 and desert > 2 - balancedStart) then
		return false;
	elseif(minor == 0 and snow > 1 - balancedStart) then
		return false;
	elseif(minor > 0 and snow > 2) then
		return false;
	else
		return true;
	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__BaseFertility(plot)

	-- Calculate the fertility of the starting plot
	local pPlot = Map.GetPlotByIndex(plot);
	local iFertility = StartPositioner.GetPlotFertility(pPlot:GetIndex(), -1);
	return iFertility;
end	

------------------------------------------------------------------------------
function AssignStartingPlots:__WeightedFertility(plot, iMajorIndex, bCheckOthers)

	-- Calculate the fertility of the starting plot
	local pPlot = Map.GetPlotByIndex(plot);
	local iFertility = StartPositioner.GetPlotFertility(pPlot:GetIndex(), iMajorIndex, bCheckOthers);
	return iFertility;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__NaturalWonderBuffer(plot, minor)
	-- Returns false if the player can start because there is a natural wonder too close.

	-- If Start position config equals legendary you can start near Natural wonders
	if(self.uiStartConfig == 3) then
		return true;
	end

	local iMaxNW = 4;
	
	
	if(minor == true) then
		iMaxNW = GlobalParameters.START_DISTANCE_MINOR_NATURAL_WONDER or 3;
	else
		iMaxNW = GlobalParameters.START_DISTANCE_MAJOR_NATURAL_WONDER or 3;
	end


	local plotX = plot:GetX();
	local plotY = plot:GetY();
	for dx = -iMaxNW, iMaxNW do
		for dy = -iMaxNW,iMaxNW do
			local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, iMaxNW);
			if(otherPlot and otherPlot:IsNaturalWonder()) then
				return false;
			end
		end
	end 

	return true;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__BonusResource(plot)
	--Finds bonus resources

	local iResourcesInDB = 0;
	eResourceType	= {};
	eResourceClassType = {};

	for row in GameInfo.Resources() do
		eResourceType[iResourcesInDB] = row.Index;
		eResourceClassType[iResourcesInDB] = row.ResourceClassType;
	    iResourcesInDB = iResourcesInDB + 1;
	end

	--Find bonus resource
	for row = 0, iResourcesInDB do
		if (eResourceClassType[row] == "RESOURCECLASS_BONUS") then
			if(eResourceType[row] == plot:GetResourceType()) then
				return true;
			end
		end		
	end 

	return false;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__TryToRemoveBonusResource(plot)
	--Removes Bonus Resources underneath starting players

	--Remove bonus resource
	local iResourcesInDB = 0;
	eResourceType	= {};
	eResourceClassType = {};

	for row in GameInfo.Resources() do
		eResourceType[iResourcesInDB] = row.Index;
		eResourceClassType[iResourcesInDB] = row.ResourceClassType;
	    iResourcesInDB = iResourcesInDB + 1;
	end

	for row = 0, iResourcesInDB do
		if (eResourceClassType[row] == "RESOURCECLASS_BONUS") then
			if(eResourceType[row] == plot:GetResourceType()) then
				ResourceBuilder.SetResourceType(plot, -1);
			end
		end		
	end 
end

------------------------------------------------------------------------------
function AssignStartingPlots:__LuxuryBuffer(plot)
	-- Checks to see if there are luxuries in the given distance

	local iResourcesInDB = 0;
	eResourceType	= {};
	eResourceClassType = {};

	for row in GameInfo.Resources() do
		eResourceType[iResourcesInDB] = row.Index;
		eResourceClassType[iResourcesInDB] = row.ResourceClassType;
	    iResourcesInDB = iResourcesInDB + 1;
	end

	local plotX = plot:GetX();
	local plotY = plot:GetY();
	for dx = -2, 2 do
		for dy = -2,2 do
			local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 2);
			if(otherPlot) then
				if(otherPlot:GetResourceCount() > 0) then
					for row = 0, iResourcesInDB do
						if (eResourceClassType[row]== "RESOURCECLASS_LUXURY") then
							if(eResourceType[row] == otherPlot:GetResourceType()) then
								return true;
							end
						end
					end
				end
			end
		end
	end 

	return false;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__StrategicBuffer(plot)
	-- Checks to see if there are strategics in the given distance

	local iResourcesInDB = 0;
	eResourceType	= {};
	eResourceClassType = {};

	for row in GameInfo.Resources() do
		eResourceType[iResourcesInDB] = row.Index;
		eResourceClassType[iResourcesInDB] = row.ResourceClassType;
	    iResourcesInDB = iResourcesInDB + 1;
	end

	local plotX = plot:GetX();
	local plotY = plot:GetY();
	for dx = -2, 2 do
		for dy = -2,2 do
			local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 2);
			if(otherPlot) then
				if(otherPlot:GetResourceCount() > 0) then
					for row = 0, iResourcesInDB do
						if (eResourceClassType[row]== "RESOURCECLASS_STRATEGIC") then
							if(eResourceType[row] == otherPlot:GetResourceType()) then
								return true;
							end
						end
					end
				end
			end
		end
	end 

	return false;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__MajorCivBuffer(plot)
	-- Checks to see if there are major civs in the given distance for this major civ

	local iMaxStart = GlobalParameters.START_DISTANCE_MAJOR_CIVILIZATION or 9;
	iMaxStart = iMaxStart - GlobalParameters.START_DISTANCE_RANGE_MAJOR or 2;

	local iSourceIndex = plot:GetIndex();
	for i, majorPlot in ipairs(self.majorStartPlots) do
		if(Map.GetPlotDistance(iSourceIndex, majorPlot:GetIndex()) <= iMaxStart) then
			return false;
		end
	end 

	return true;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__MinorMajorCivBuffer(plot)
	-- Checks to see if there are najors in the given distance for this minor civ

	local iMaxStart = GlobalParameters.START_DISTANCE_MINOR_MAJOR_CIVILIZATION or 7;

	local iSourceIndex = plot:GetIndex();

	if(self.waterMap == true) then
			iMaxStart = iMaxStart - 1;
		end

	for i, majorPlot in ipairs(self.majorCopy) do
		if(Map.GetPlotDistance(iSourceIndex, majorPlot:GetIndex()) <= iMaxStart) then
			return false;
		end
	end 

	return true;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__MinorMinorCivBuffer(plot)
	-- Checks to see if there are minors in the given distance for this minor civ

	local iMaxStart = GlobalParameters.START_DISTANCE_MINOR_CIVILIZATION_START or 5;
	iMaxStart = iMaxStart - GlobalParameters.START_DISTANCE_RANGE_MINOR or 2;

	local iSourceIndex = plot:GetIndex();

	for i, minorPlot in ipairs(self.minorStartPlots) do
		if(Map.GetPlotDistance(iSourceIndex, minorPlot:GetIndex()) <= iMaxStart) then
			return false;
		end
	end 

	return true;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__AddBonusFoodProduction(plot)
	local food = 0;
	local production = 0;
	local maxFood = 0;
	local maxProduction = 0;
	local gridWidth, gridHeight = Map.GetGridSize();
	local terrainType = plot:GetTerrainType();

	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), direction);
		if (adjacentPlot ~= nil) then
			terrainType = adjacentPlot:GetTerrainType();
			if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
				-- Gets the food and productions
				food = food + adjacentPlot:GetYield(g_YIELD_FOOD);
				production = production + adjacentPlot:GetYield(g_YIELD_PRODUCTION);

				--Checks the maxFood
				if(maxFood <=  adjacentPlot:GetYield(g_YIELD_FOOD)) then
					maxFood = adjacentPlot:GetYield(g_YIELD_FOOD);
				end

				--Checks the maxProduction
				if(maxProduction <=  adjacentPlot:GetYield(g_YIELD_PRODUCTION)) then
					maxProduction = adjacentPlot:GetYield(g_YIELD_PRODUCTION);
				end
			end
		end
	end 

	if(food < 7 or maxFood < 3) then
		--print("X: ", plot:GetX(), " Y: ", plot:GetY(), " Food Time");
		self:__AddFood(plot); 
	end

	if(production < 5 or maxProduction < 2) then
		--print("X: ", plot:GetX(), " Y: ", plot:GetY(), " Production Time");
		self:__AddProduction(plot); 
	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__AddFood(plot)
	local iResourcesInDB = 0;
	eResourceType	= {};
	eResourceClassType = {};
	aBonus = {};

	for row in GameInfo.Resources() do
		eResourceType[iResourcesInDB] = row.Index;
		eResourceClassType[iResourcesInDB] = row.ResourceClassType;
	    iResourcesInDB = iResourcesInDB + 1;
	end

	for row = 0, iResourcesInDB do
		if (eResourceClassType[row] == "RESOURCECLASS_BONUS") then
			for row2 in GameInfo.TypeTags() do
				if(GameInfo.Resources[row2.Type] ~= nil) then
					if(GameInfo.Resources[row2.Type].Index== eResourceType[row] and row2.Tag=="CLASS_FOOD") then
						table.insert(aBonus, eResourceType[row]);
					end
				end
			end
		end
	end

	local dir = TerrainBuilder.GetRandomNumber(DirectionTypes.NUM_DIRECTION_TYPES, "Random Direction");
	for i = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), dir);
		if (adjacentPlot ~= nil) then
			aShuffledBonus =  GetShuffledCopyOfTable(aBonus);
			for i, bonus in ipairs(aShuffledBonus) do
				if(ResourceBuilder.CanHaveResource(adjacentPlot, bonus)) then
					--print("X: ", adjacentPlot:GetX(), " Y: ", adjacentPlot:GetY(), " Resource #: ", bonus);
					ResourceBuilder.SetResourceType(adjacentPlot, bonus, 1);
					return;
				end
			end
		end


		if(dir == DirectionTypes.NUM_DIRECTION_TYPES - 1) then
			dir = 0;
		else
			dir = dir + 1;
		end
	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__AddProduction(plot)
	local iResourcesInDB = 0;
	eResourceType	= {};
	eResourceClassType = {};
	aBonus = {};

	for row in GameInfo.Resources() do
		eResourceType[iResourcesInDB] = row.Index;
		eResourceClassType[iResourcesInDB] = row.ResourceClassType;
	    iResourcesInDB = iResourcesInDB + 1;
	end

	for row = 0, iResourcesInDB do
		if (eResourceClassType[row] == "RESOURCECLASS_BONUS") then
			for row2 in GameInfo.TypeTags() do
				if(GameInfo.Resources[row2.Type] ~= nil) then
					if(GameInfo.Resources[row2.Type].Index== eResourceType[row] and row2.Tag=="CLASS_PRODUCTION") then
						table.insert(aBonus, eResourceType[row]);
					end
				end
			end
		end
	end

	local dir = TerrainBuilder.GetRandomNumber(DirectionTypes.NUM_DIRECTION_TYPES, "Random Direction");
	for i = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), dir);
		if (adjacentPlot ~= nil) then
			aShuffledBonus =  GetShuffledCopyOfTable(aBonus);
			for i, bonus in ipairs(aShuffledBonus) do
				if(ResourceBuilder.CanHaveResource(adjacentPlot, bonus)) then
					--print("X: ", adjacentPlot:GetX(), " Y: ", adjacentPlot:GetY(), " Resource #: ", bonus);
					ResourceBuilder.SetResourceType(adjacentPlot, bonus, 1);
					return;
				end
			end
		end


		if(dir == DirectionTypes.NUM_DIRECTION_TYPES - 1) then
			dir = 0;
		else
			dir = dir + 1;
		end
	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__InitStartBias(minor)
	--Create an array of each starting plot for each civ
	self.playerStarts = {};
	if (minor == true) then
		print("Setting start locations for " , self.iNumMinorCivs, " minors");
		for i = 1, self.iNumMinorCivs do
			local playerStart = {}
			-- for j, plot in ipairs(self.minorStartPlots) do
			-- 	playerStart[j] = plot;
			local plot = self.minorStartPlots[i];
				print("Setting player ", self.iNumMajorCivs+i , " to start plot ", plot:GetIndex());
			-- end
			playerStart[1]=plot;
			self.playerStarts[self.iNumMajorCivs + i] = playerStart
		end
	else
		for i = 1, self.iNumMajorCivs do
			local playerStart = {}
			-- for j, plot in ipairs(self.majorStartPlots) do
			-- 	playerStart[j] = plot;
			local plot = self.majorStartPlots[i];
				print("Setting player ", i , " to start plot ", plot:GetIndex());
			-- end
			playerStart[1]=plot;
			self.playerStarts[i] = playerStart;
		end
	end

	-- --Find the Max tier
	-- local max = 0; 
	-- for row in GameInfo.StartBiasResources() do
	-- 	if( row.Tier > max) then
	-- 		max = row.Tier;
	-- 	end
	-- end
	-- for row in GameInfo.StartBiasFeatures() do
	-- 	if( row.Tier > max) then
	-- 		max = row.Tier;
	-- 	end
	-- end
	-- for row in GameInfo.StartBiasTerrains() do
	-- 	if( row.Tier > max) then
	-- 		max = row.Tier;
	-- 	end
	-- end
	-- for row in GameInfo.StartBiasRivers() do
	-- 	if(row.Tier > max) then
	-- 		max = row.Tier;
	-- 	end
	-- end

	
	-- for i = 1, max do
	-- 	players = {};
		
	-- 	--Add all the civs that are in this tier to a table
	-- 	if(minor == true) then
	-- 		for j = 1, self.iNumMinorCivs do
	-- 			local playerIndex = self.iNumMajorCivs + j;
	-- 			local civilizationType = PlayerConfigurations[self.minorList[j]]:GetCivilizationTypeName();

	-- 			for row in GameInfo.StartBiasResources() do
	-- 				if(row.CivilizationType == civilizationType) then
	-- 					if( row.Tier == i) then
	-- 						table.insert(players, playerIndex);
	-- 					end
	-- 				end
	-- 			end

	-- 			for row in GameInfo.StartBiasFeatures() do
	-- 				if(row.CivilizationType == civilizationType) then
	-- 					if( row.Tier == i) then
	-- 						table.insert(players, playerIndex);
	-- 					end
	-- 				end
	-- 			end

	-- 			for row in GameInfo.StartBiasTerrains() do
	-- 				if(row.CivilizationType == civilizationType) then
	-- 					if( row.Tier == i) then
	-- 						table.insert(players, playerIndex);
	-- 					end
	-- 				end
	-- 			end

	-- 			-- Maritime CS <<<<<
	-- 			for row in GameInfo.StartBiasCoast() do
	-- 				if(row.CivilizationType == civilizationType) then
	-- 					if( row.Tier == i) then
	-- 						table.insert(players, playerIndex);
	-- 					end
	-- 				end
	-- 			end
	-- 			-- Maritime CS >>>>>
				
	-- 			for row in GameInfo.StartBiasRivers() do
	-- 				if(row.CivilizationType == civilizationType) then
	-- 					if( row.Tier == i) then
	-- 						table.insert(players, playerIndex);
	-- 					end
	-- 				end
	-- 			end
	-- 		end
	-- 	else
	-- 		for j = 1, self.iNumMajorCivs do
	-- 			local playerIndex = j;
	-- 			local civilizationType = PlayerConfigurations[self.majorList[j]]:GetCivilizationTypeName();
	-- 			for row in GameInfo.StartBiasResources() do
	-- 				if(row.CivilizationType == civilizationType) then
	-- 					if( row.Tier == i) then
	-- 						table.insert(players, playerIndex);
	-- 					end
	-- 				end
	-- 			end

	-- 			for row in GameInfo.StartBiasFeatures() do
	-- 				if(row.CivilizationType == civilizationType) then
	-- 					if( row.Tier == i) then
	-- 						table.insert(players, playerIndex);
	-- 					end
	-- 				end
	-- 			end

	-- 			for row in GameInfo.StartBiasTerrains() do
	-- 				if(row.CivilizationType == civilizationType) then
	-- 					if( row.Tier == i) then
	-- 						table.insert(players, playerIndex);
	-- 					end
	-- 				end
	-- 			end

	-- 			-- Maritime CS <<<<<
	-- 			for row in GameInfo.StartBiasCoast() do
	-- 				if(row.CivilizationType == civilizationType) then
	-- 					if( row.Tier == i) then
	-- 						table.insert(players, playerIndex);
	-- 					end
	-- 				end
	-- 			end
	-- 			-- Maritime CS >>>>>

	-- 			for row in GameInfo.StartBiasRivers() do
	-- 				if(row.CivilizationType == civilizationType) then
	-- 					if( row.Tier == i) then
	-- 						table.insert(players, playerIndex);
	-- 					end
	-- 				end
	-- 			end
	-- 		end
	-- 	end


	-- 	players =  GetShuffledCopyOfTable(players); -- Shuffle the table
	-- 	-- Go through all the players in this tier
	-- 	for j, playerIndex in ipairs(players) do
	-- 		local playerId = (playerIndex > self.iNumMajorCivs) and self.minorList[playerIndex - self.iNumMajorCivs] or self.majorList[playerIndex];
	-- 		local civilizationType = PlayerConfigurations[playerId]:GetCivilizationTypeName()
			
	-- 		--Check if this player has a resource bias then it calls that method
	-- 		local resource = false;
	-- 		for row in GameInfo.StartBiasResources() do
	-- 			if(row.CivilizationType == civilizationType) then
	-- 				if( row.Tier == i) then
	-- 					resource = true;
	-- 				end
	-- 			end
	-- 		end
	-- 		if(resource == true) then
	-- 			self:__StartBiasResources(playerIndex, i, minor);
	-- 		end

	-- 		--Check if this player has a feature bias then it calls that method
	-- 		local feature = false;
	-- 		for row in GameInfo.StartBiasFeatures() do
	-- 			if(row.CivilizationType == civilizationType) then
	-- 				if( row.Tier == i) then
	-- 					feature = true;
	-- 				end
	-- 			end
	-- 		end
	-- 		if(feature == true) then
	-- 			self:__StartBiasFeatures(playerIndex, i, minor);
	-- 		end

	-- 		--Check if this player has a terrain bias then it calls that method
	-- 		local terrain = false;
	-- 		for row in GameInfo.StartBiasTerrains() do
	-- 			if(row.CivilizationType == civilizationType) then
	-- 				if( row.Tier == i) then
	-- 					terrain = true;
	-- 				end
	-- 			end
	-- 		end
	-- 		if(terrain == true) then
	-- 			self:__StartBiasTerrains(playerIndex, i, minor);
	-- 		end

	-- 		-- Maritime CS <<<<<
	-- 		--Check if this player has a true coast bias then it calls that method
	-- 		local terrainCoast = false;
	-- 		for row in GameInfo.StartBiasCoast() do
	-- 			if(row.CivilizationType == civilizationType) then
	-- 				if( row.Tier == i) then
	-- 					terrainCoast = true;
	-- 				end
	-- 			end
	-- 		end
	-- 		if(terrainCoast == true) then
	-- 			self:__StartBiasCoast(playerIndex, i, minor);
	-- 		end
	-- 		-- Maritime CS >>>>>

	-- 		--Check if this player has a river bias then it calls that method
	-- 		local river = false;
	-- 		for row in GameInfo.StartBiasRivers() do
	-- 			if(row.CivilizationType == civilizationType) then
	-- 				if( row.Tier == i) then
	-- 					river = true;
	-- 				end
	-- 			end
	-- 		end
	-- 		if(river == true) then
	-- 			self:__StartBiasRivers(playerIndex, i, minor);
	-- 		end
	-- 	end

	-- 	local minorModifier = 0;
	-- 	if(minor == true) then
	-- 		minorModifier = self.iNumMajorCivs;
	-- 	end

	-- 	if(i == max) then
	-- 		local loop = self.iNumMajorCivs;

	-- 		if(minor == true) then
	-- 			loop = self.iNumMinorCivs;
	-- 		end

	-- 		for j = 1, loop do
	-- 			if(self:__ArraySize(self.playerStarts, j + minorModifier) > 1) then
	-- 				for k, v in pairs(self.playerStarts[j + minorModifier]) do
	-- 					if(v~= nil) then
	-- 						--Call Removal
	-- 						self:__StartBiasPlotRemoval(v, minor, j + minorModifier);
	-- 					end
	-- 				end
	-- 			end
	-- 		end
	-- 	else
	-- 		for j, playerIndex in ipairs(players) do
	-- 			local hasPlot = false;

	-- 			if(self:__ArraySize(self.playerStarts, playerIndex) > 1) then
	-- 				for k, v in pairs(self.playerStarts[playerIndex]) do
	-- 					if(v~= nil and hasPlot == false) then
	-- 						hasPlot = true;
	-- 						--Call Removal
	-- 						self:__StartBiasPlotRemoval(v, minor, playerIndex);
	-- 					end
	-- 				end
	-- 			end
	-- 		end
	-- 	end
	-- end
	

	-- -- Safety net for starting plots
	-- playerRestarts = {};
	-- local loop = 0;
	-- if (minor == true) then
	-- 	loop = self.iNumMinorCivs;
		
	-- 	for k, plot in ipairs(self.minorCopy) do
	-- 		table.insert(playerRestarts, plot);
	-- 	end

	-- 	for i = 1, self.iNumMinorCivs do
	-- 		local removed = false;
	-- 		for j, plot in pairs(self.playerStarts[i + self.iNumMajorCivs]) do
	-- 			for k, rePlot in ipairs(playerRestarts) do
	-- 				if(plot:GetIndex() == rePlot:GetIndex() and removed == false) then
	-- 					table.remove(playerRestarts, k);
	-- 					removed = true;
	-- 				end
	-- 			end
	-- 		end
	-- 	end
	-- else
	-- 	loop = self.iNumMajorCivs;
		
	-- 	for k, plot in ipairs(self.majorCopy) do
	-- 		table.insert(playerRestarts, plot);
	-- 	end

	-- 	for i = 1, self.iNumMajorCivs do
	-- 		local removed = false;
	-- 		for j, plot in pairs(self.playerStarts[i]) do
	-- 			for k, rePlot in ipairs(playerRestarts) do
	-- 				if(plot:GetIndex() == rePlot:GetIndex() and removed == false) then
	-- 					table.remove(playerRestarts, k);
	-- 					removed = true;
	-- 				end
	-- 			end
	-- 		end
	-- 	end
	-- end

	
	-- for i = 1, loop do
	-- 	local bHasStart = false;

	-- 	local offset = minor and self.iNumMajorCivs or 0;

	-- 	for j, plot in pairs(self.playerStarts[i + offset]) do
	-- 		if(plot ~= nil) then
	-- 			bHasStart = true;
	-- 		end
	-- 	end

	-- 	if(bHasStart == false) then
	-- 		local bNeedPlot = true;
	-- 		local index = -1;
	-- 		for j, plot in ipairs(playerRestarts) do
	-- 			if (plot ~= nil and bNeedPlot == true) then
	-- 				bNeedPlot = false;
	-- 				index = j;
	-- 			end
	-- 		end
	-- 		if(bNeedPlot == true) then
	-- 			--print("Start Bias Error");
	-- 		else
	-- 			table.insert(self.playerStarts[i + offset], playerRestarts[index]);
	-- 			table.remove(playerRestarts, index);
	-- 		end
	-- 	end
	-- end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__StartBiasResources(playerIndex, tier, minor)
	local numResource = 0;
	resources = {}

	local playerId = minor and self.minorList[playerIndex - self.iNumMajorCivs] or self.majorList[playerIndex];
	local civilizationType = PlayerConfigurations[playerId]:GetCivilizationTypeName()
	local playerStart = self.playerStarts[playerIndex];

	-- Find the resouces in this tier
	for row in GameInfo.StartBiasResources() do
		if(row.CivilizationType == civilizationType) then
			if( row.Tier == tier) then
				table.insert(resources,  row.ResourceType);
			end
		end
	end

	--Change the range if it is a minor civ
	local range = 2;
	if(minor == true) then
		range = 1;
	end

	resourcePlots = {};

	Resources = {};

	for row in GameInfo.Resources() do
		table.insert(Resources, row.ResourceType);
	end

	--Loop through all the starting plots
	for k, v in pairs(playerStart) do
		--Count the starting plots with the given resource(s) in this tier and add them to an array
		if(v ~= nil) then
			local plotX = v:GetX();
			local plotY = v:GetY();

			local hasResource = false;

			for dx = -range, range, 1 do
				for dy = -range,range, 1 do
					local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, range);
					if(otherPlot) then
						if(otherPlot:GetResourceCount() > 0) then
							for j, resource in ipairs(resources) do
								if(Resources[otherPlot:GetResourceType()+1] == resource) then
									hasResource = true;
								end
							end
						end
					end
				end
			end

			if (hasResource == true) then
				numResource = numResource + 1;
				table.insert(resourcePlots, v);
			end
		end
	end 

	--If more than 1 has this resource(s) within 3
	if(numResource  > 1) then
		-- Remove all other starting plots from this civ�s list.
		for k, v in pairs(playerStart) do
			playerStart[k] = nil;
		end
		for i, resourcePlot in ipairs(resourcePlots) do
			table.insert(playerStart, resourcePlot);
		end
	elseif (numResource  == 1) then
		local startPlot = resourcePlots[1];
		
		-- Remove all other starting plots from this civ�s list.
		for k, v in pairs(playerStart) do
			if(startPlot:GetIndex() == v:GetIndex()) then
					playerStart[k] = startPlot;
			else
					playerStart[k] = nil;
			end
		end

		-- Remove this starting plot from all other civ's list
		-- Check to to see if they have one starting spot left if so remove it from all other players
		self:__StartBiasPlotRemoval(startPlot, minor, playerIndex);

	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__StartBiasFeatures(playerIndex, tier, minor)
	local numFeature = 0;
	features = {}

	local playerId = minor and self.minorList[playerIndex - self.iNumMajorCivs] or self.majorList[playerIndex];
	local civilizationType = PlayerConfigurations[playerId]:GetCivilizationTypeName()
	local playerStart = self.playerStarts[playerIndex];

	-- Find the features in this tier
	for row in GameInfo.StartBiasFeatures() do
		if(row.CivilizationType == civilizationType) then
			if( row.Tier == tier) then
				table.insert(features,  row.FeatureType);
			end
		end
	end

	--Change the range if it is a minor civ
	local range = 3;
	if(minor == true) then
		range = 2;
	end

	featurePlots = {};

	Features = {};

	for row in GameInfo.Features() do
		table.insert(Features, row.FeatureType);
	end

	--Loop through all the starting plots
	for k, v in pairs(playerStart) do
		--Count the starting plots with the given feature(s) in this tier and add them to an array
		if(v ~= nil) then
			local plotX = v:GetX();
			local plotY = v:GetY();

			local hasFeature = false;

			for dx = -range, range - 1, 1 do
				for dy = -range,range -1, 1 do
					local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, range);
					if(otherPlot) then
						if(otherPlot:GetFeatureType() ~= g_FEATURE_NONE) then
							for j, feature in ipairs(features) do
								if(Features[otherPlot:GetFeatureType()+1] == feature) then
									hasFeature = true;
								end
							end
						end
					end
				end
			end

			if (hasFeature == true) then
				numFeature = numFeature + 1;
				table.insert(featurePlots, v);
			end
		end
	end 

	--If more than 1 has this feature(s) within 3
	if(numFeature  > 1) then
		-- Remove all other starting plots from this civ�s list.
		local featureValue = table.fill(0, #featurePlots);

		for i, featurePlot in ipairs(featurePlots) do
			local plotX = featurePlot:GetX();
			local plotY = featurePlot:GetY();


			for dx = -range, range - 1, 1 do
				for dy = -range,range -1, 1 do
					local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, range);
					if(otherPlot) then
						if(featurePlot:GetIndex() ~= otherPlot:GetIndex()) then
							if(otherPlot:GetFeatureType() ~= g_FEATURE_NONE) then
								for j, feature in ipairs(features) do
									if(Features[otherPlot:GetFeatureType()+1] == feature) then
										featureValue[i] = featureValue[i] + 1;
									end
								end
							end
						end
					end
				end
			end
		end

		self.sortedArray = {};
		self:__SortByArray(featurePlots, featureValue);

		for k, v in pairs(playerStart) do
			playerStart[k] = nil;
		end
		for i, featurePlot in ipairs(self.sortedArray) do
			table.insert(playerStart, featurePlot);
		end
	elseif (numFeature  == 1) then
		local startPlot = featurePlots[1];

		-- Remove all other starting plots from this civ�s list.
		for k, v in pairs(playerStart) do
			if(startPlot:GetIndex() == v:GetIndex()) then
					playerStart[k] = startPlot;
			else
					playerStart[k] = nil;
			end
		end

		-- Remove this starting plot from all other civ's list
		-- Check to to see if they have one starting spot left if so remove it from all other players
		self:__StartBiasPlotRemoval(startPlot, minor, playerIndex);

	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__StartBiasTerrains(playerIndex, tier, minor)
	local numTerrain = 0;
	terrains = {}

	local playerId = minor and self.minorList[playerIndex - self.iNumMajorCivs] or self.majorList[playerIndex];
	local civilizationType = PlayerConfigurations[playerId]:GetCivilizationTypeName()
	local playerStart = self.playerStarts[playerIndex];

	-- Find the terrains in this tier
	for row in GameInfo.StartBiasTerrains() do
		if(row.CivilizationType == civilizationType) then
			if( row.Tier == tier) then
				table.insert(terrains,  row.TerrainType);
			end
		end
	end

	--Change the range if it is a minor civ
	local range = 3;
	if(minor == true) then
		range = 2;
	end

	terrainPlots = {};

	Terrains = {};

	for row in GameInfo.Terrains() do
		table.insert(Terrains, row.TerrainType);
	end

	--Loop through all the starting plots
	for k, v in pairs(playerStart) do
		--Count the starting plots with the given terrain(s) in this tier and add them to an array
		if(v ~= nil) then
			local plotX = v:GetX();
			local plotY = v:GetY();

			local hasTerrain = false;

			for dx = -range, range - 1, 1 do
				for dy = -range,range -1, 1 do
					local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, range);
					if(otherPlot) then
						if(v:GetIndex() ~= otherPlot:GetIndex()) then
							if(otherPlot:GetTerrainType() ~= g_TERRAIN_NONE) then
								for j, terrain in ipairs(terrains) do
									if(Terrains[otherPlot:GetTerrainType()+1] == terrain) then
										hasTerrain = true;
									end
								end
							end
						end
					end
				end
			end

			if (hasTerrain == true) then
				numTerrain = numTerrain + 1;
				table.insert(terrainPlots, v);
			end
		end
	end 

	--If more than 1 has this terrain(s) within 3
	if(numTerrain  > 1) then
		-- Remove all other starting plots from this civ�s list.
		local terrainValue = table.fill(0, #terrainPlots);

		for i, terrainPlot in ipairs(terrainPlots) do
			local plotX = terrainPlot:GetX();
			local plotY = terrainPlot:GetY();


			for dx = -range, range - 1, 1 do
				for dy = -range,range -1, 1 do
					local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, range);
					if(otherPlot) then
						if(otherPlot:GetTerrainType() ~= g_TERRAIN_NONE) then
							for j, terrain in ipairs(terrains) do
								if(Terrains[otherPlot:GetTerrainType()+1] == terrain) then
									terrainValue[i] = terrainValue[i] + 1;
								end
							end
						end
					end
				end
			end
		end

		self.sortedArray = {};
		self:__SortByArray(terrainPlots, terrainValue);

		for k, v in pairs(playerStart) do
			playerStart[k] = nil;
		end
		for i, terrainPlot in ipairs(self.sortedArray) do
			table.insert(playerStart, terrainPlot);
		end
	elseif (numTerrain  == 1) then
		local startPlot = terrainPlots[1];

		-- Remove all other starting plots from this civ�s list.
		for k, v in pairs(playerStart) do
			if(startPlot:GetIndex() == v:GetIndex()) then
				playerStart[k] = startPlot;
			else
				playerStart[k] = nil;
			end
		end

		-- Remove this starting plot from all other civ's list
		-- Check to to see if they have one starting spot left if so remove it from all other players
		self:__StartBiasPlotRemoval(startPlot, minor, playerIndex);

	end
end

------------------------------------------------------------------------------
-- Maritime CS  <<<<<
function AssignStartingPlots:__StartBiasCoast(playerIndex, tier, minor)
	local numTerrain = 0;
	--print("Starting startbiascoast");
	local playerId = minor and self.minorList[playerIndex - self.iNumMajorCivs] or self.majorList[playerIndex];
	local civilizationType = PlayerConfigurations[playerId]:GetCivilizationTypeName()
	local playerStart = self.playerStarts[playerIndex];

	--get a table of all plots on the map
	--cycle through the table and if the plot is water/impassable/snow do not add it to validplots
	allMapPlots = {};
	local gridWidth, gridHeight = Map.GetGridSize();
	for sx = 0, gridWidth, 1 do
		for sy = 0, gridHeight, 1 do
			local tempPlot = Map.GetPlot(sx, sy);
			table.insert(allMapPlots, tempPlot);
		end
	end
	--print("-----# of plots added to AllMapPlots", #allMapPlots);
	
	--parse the plots for valid starting plots
	validplots = {};
	local count = 1;
	local bValid = false;
	while (count < #allMapPlots) do
		local bValid = false;
		bValid = true;
		local NWMinor = 2;
		--print(count);
		local pTempPlot = allMapPlots[count];
		count = count + 1;
		--print("Fertility: ", sortedPlots[count].Fertility)

		-- Checks to see if the plot is impassable
		if(pTempPlot:IsImpassable() == true) then
			bValid = false;
		end
		
		local isNextToSaltWater = false;
		
		-- Checks to see if the plot isn't AdjacentToSaltWater
		if not pTempPlot:IsWater() then -- This plot is land, process it.
			for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
				local testPlot = Map.GetAdjacentPlot(pTempPlot:GetX(),pTempPlot:GetY(), direction);
				if testPlot ~= nil then
					if testPlot:IsWater() then -- Adjacent plot is water! Check if ocean or lake.
						if testPlot:IsLake() == false then -- Adjacent plot is salt water!
							isNextToSaltWater = true
						end
					end
				end
			end
		end
		
		if(isNextToSaltWater ~= true) then
			bValid = false;
		end
		
		-- Checks to see if the plot is water
		if(pTempPlot:IsWater() == true) then
			bValid = false;
		end

		-- Checks to see if there are resources
		if(pTempPlot:GetResourceCount() > 0) then
			local bValidResource = self:__BonusResource(pTempPlot);
			if(bValidResource == false) then
				bValid = false;
			end
		end

		local bValidAdjacentCheck = self:__GetValidAdjacent(pTempPlot, 2); 
		if(bValidAdjacentCheck == false) then
			bValid = false;
		end

		-- Checks to see if there are natural wonders in the given distance
		local bNaturalWonderCheck = self:__NaturalWonderBuffer(pTempPlot, true); 
		if(bNaturalWonderCheck == false) then
			bValid = false;
		end

		-- Checks to see if there are any minor civs in the given distance
		local bMinorCivCheck = self:__MinorMinorCivBuffer(pTempPlot, 1); 
		if(bMinorCivCheck == false) then
			bValid = false;
		end

		-- Checks to see if there is an Oasis
		local featureType = pTempPlot:GetFeatureType();
		if(featureType == g_FEATURE_OASIS) then
			bValid = false;
		end
		
		-- Checks to see if tundra
		local terrainType = pTempPlot:GetTerrainType();
		if(terrainType == g_TERRAIN_TYPE_TUNDRA) then
			bValid = false;
		end
		-- Checks to see if tundra hills
		local terrainType = pTempPlot:GetTerrainType();
		if(terrainType == g_TERRAIN_TYPE_TUNDRA_HILLS) then
			bValid = false;
		end
		-- Checks to see if snow
		local terrainType = pTempPlot:GetTerrainType();
		if(terrainType == g_TERRAIN_TYPE_SNOW) then
			bValid = false;
		end
		-- Checks to see if snow hills
		local terrainType = pTempPlot:GetTerrainType();
		if(terrainType == g_TERRAIN_TYPE_SNOW_HILLS) then
			bValid = false;
		end

		-- If the plots passes all the checks then the plot equals the temp plot
		if(bValid == true) then
			self:__TryToRemoveBonusResource(pTempPlot);
			table.insert(validplots, pTempPlot);
		end
	end
	--print("Found valid plots", #validplots);

	numTerrain = #validplots;
	if(numTerrain == 0) then
	--print("-----There are no possible fertile Maritime starts for", civilizationType, ". Generating a new table of startplots for this civ based on coastal fertility.");
	else
	--print("-----Found", numTerrain, "possible Maritime starts for", civilizationType, "------");
	end
		
		local player = Players[playerId];
		validplots = GetShuffledCopyOfTable(validplots);
		
		for k, validplot in pairs(validplots) do
			table.insert(playerStart, validplot);
		end
		if(numTerrain > 0) then
			local f = validplots[1];
			--print("Attempting to assign a CUSTOM COASTAL starting plot to", player, civilizationType, " ");
			player:SetStartingPlot(f);
			--print(civilizationType, "X:", f:GetX(), "Y:", f:GetY());
		for k, v in pairs(playerStart) do
			if(f:GetIndex() == v:GetIndex()) then
				playerStart[k] = f;
			else
				playerStart[k] = nil;
			end
		end
		end
end
-- Maritime CS >>>>>

------------------------------------------------------------------------------
function AssignStartingPlots:__StartBiasRivers(playerIndex, tier, minor)
	local numRiver = 0;

	--The range is 1 in the beginning
	local range = 1;

	riverPlots = {};

	local playerId = minor and self.minorList[playerIndex - self.iNumMajorCivs] or self.majorList[playerIndex];
	local civilizationType = PlayerConfigurations[playerId]:GetCivilizationTypeName()
	local playerStart = self.playerStarts[playerIndex];

	--Loop through all the starting plots
	for k, v in pairs(playerStart) do
		--Count the starting plots with the given river(s) in this tier and add them to an array
		if(v ~= nil) then
			local plotX = v:GetX();
			local plotY = v:GetY();

			local hasRiver = false;

			for dx = -range, range - 1, 1 do
				for dy = -range,range -1, 1 do
					local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, range);
					if(otherPlot) then
						if(otherPlot:IsRiver()) then
							hasRiver = true;
						end
					end
				end
			end

			if (hasRiver == true) then
				numRiver = numRiver + 1;
				table.insert(riverPlots, v);
			end
		end
	end 

	--If more than 1 has this river(s) within 3
	if(numRiver  > 1) then
		-- Remove all other starting plots from this civ�s list.
		for k, v in pairs(playerStart) do
			playerStart[k] = nil;
		end
		for i, riverPlot in ipairs(riverPlots) do
			table.insert(playerStart, riverPlot);
		end
	elseif (numRiver  == 1) then
		local startPlot = riverPlots[1];
		
		-- Remove all other starting plots from this civ�s list.
		for k, v in pairs(playerStart) do
			if(startPlot:GetIndex() == v:GetIndex()) then
				playerStart[k] = startPlot;
			else
				playerStart[k] = nil;
			end
		end

		-- Remove this starting plot from all other civ's list
		-- Check to to see if they have one starting spot left if so remove it from all other players
		self:__StartBiasPlotRemoval(startPlot, minor, playerIndex);

	elseif(minor == false) then
		--Change the range if no rivers within 3 and major
		local numRiver = 0;
		local range = 3;

		riverPlots = {};

		--Loop through all the starting plots
		for k, v in pairs(playerStart) do
			--Count the starting plots with the given river(s) in this tier and add them to an array
			if(v ~= nil) then
				local plotX = v:GetX();
				local plotY = v:GetY();

				local hasRiver = false;

				for dx = -range, range - 1, 1 do
					for dy = -range,range -1, 1 do
						local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, range);
						if(otherPlot) then
							if(otherPlot:IsRiver()) then
								hasRiver = true;
							end
						end
					end
				end

				if (hasRiver == true) then
					numRiver = numRiver + 1;
					table.insert(riverPlots, v);
				end
			end
		end 

		if(numRiver  > 1) then
			-- Remove all other starting plots from this civ�s list.
			for k, v in pairs(playerStart) do
				playerStart[k] = nil;
			end
			for i, riverPlot in ipairs(riverPlots) do
				table.insert(playerStart, riverPlot);
			end
		elseif (numRiver  == 1) then
			local startPlot = riverPlots[1];
		
			-- Remove all other starting plots from this civ�s list.
			for k, v in pairs(playerStart) do
				if(startPlot:GetIndex() == v:GetIndex()) then
					playerStart[k] = startPlot;
				else
					playerStart[k] = nil;
				end
			end

			-- Remove this starting plot from all other civ's list
			-- Check to to see if they have one starting spot left if so remove it from all other players
			self:__StartBiasPlotRemoval(startPlot, minor, playerIndex);
		end
	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__StartBiasPlotRemoval(startPlot, minor, playerIndex)
	
	if(startPlot == nil) then
		print("Nil1 Starting Plot");
	end
 
	local start = 1;
	local finish = self.iNumMajorCivs; 

	if (minor == true) then
		start = self.iNumMajorCivs + 1;
		finish = self.iNumMajorCivs + self.iNumMinorCivs;
	end

	for i = start, finish do
		if(i ~= playerIndex) then
			local plotID  = -1;

			for k, v in pairs(self.playerStarts[i]) do
				if(v~= nil and v:GetIndex() == startPlot:GetIndex()) then
					plotID = k;
				end
			end

			--If only one left remove it. And remove it from others...
			if(plotID > -1) then
				if(self:__ArraySize(self.playerStarts, i) == 1) then
					--print("Deleting the last entry will have bad results. Minor is ", minor);
				end

				self.playerStarts[i][plotID] = nil;

				if(self:__ArraySize(self.playerStarts, i) == 1) then
					local hasPlot = false;
					for k, v in pairs(self.playerStarts[i]) do
						if(v~= nil and hasPlot == false) then
							hasPlot = true;
							--Call Removal
							self:__StartBiasPlotRemoval(v, minor, i)
							print("Removing bc of bias : ",minor);
						end
					end
				end
			end
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:__SortByArray(sorted, keyArray)
	local greatestValue = -1;
	local index  = -1;

	for k, key in ipairs(keyArray) do
		if(key ~= nil and key > greatestValue) then
			index = k;
			greatestValue = key;
		end
	end

	if(index > 0 and sorted[index] ~= nil) then
		table.insert(self.sortedArray,sorted[index]);
		table.remove(sorted,index);
		table.remove(keyArray,index);
	else
		print("Nil");
	end 

	if(#keyArray > 0) then
		self:__SortByArray(sorted, keyArray);
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:__ArraySize(array, index)
	local count = 0;
	
	if( array ~= nil) then
		for v in pairs(array[index]) do 
			if(v~=nil) then
				count = count + 1;
			end
		end
	end

 	return count;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__PreFertilitySort(sortedPlots)
	--Only used for balanced start
	local iFirstFertility = sortedPlots[1].Fertility;
	if(iFirstFertility < 0) then
		iFirstFertility = 0;
	end

	local score = {};

	for i, plot in ipairs(sortedPlots) do
		local value = plot.Fertility;

		if(value < 0) then
			value = 0
		end

		if(iFirstFertility - value < 0) then
			value = iFirstFertility - value;
		end

		table.insert(score, value);
	end

	return score;
end
------------------------------------------------------------------------------
function AssignStartingPlots:__SortByFertilityArray(sorted, keyArray)
	--Only used for balanced start
	local greatestValue = math.huge * -1;
	local index  = -1;

	for k, key in ipairs(keyArray) do
		if(key ~= nil and key > greatestValue) then
			index = k;
			greatestValue = key;
		end
	end

	if(index > 0 and sorted[index] ~= nil) then
		row = {};
		row.Plot = sorted[index].Plot;
		row.Fertility = sorted[index].Fertility;
		table.insert(self.sortedFertilityArray,row);
		table.remove(sorted,index);
		table.remove(keyArray,index);
	else
		--print("Nil");
	end 

	if(#keyArray > 0) then
		self:__SortByFertilityArray(sorted, keyArray);
	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__AddResourcesBalanced()
	local iStartEra = GameInfo.Eras[ GameConfiguration.GetStartEra() ];
	local iStartIndex = 1;
	if iStartEra ~= nil then
		iStartIndex = iStartEra.ChronologyIndex;
	end

	local iHighestFertility = 0;
	for i, plot in ipairs(self.majorStartPlots) do
		self:__BalancedStrategic(plot, iStartIndex);
		
		if(self:__BaseFertility(plot:GetIndex()) > iHighestFertility) then
			iHighestFertility = self:__BaseFertility(plot:GetIndex());
		end
	end

	for i, plot in ipairs(self.majorStartPlots) do
		local iFertilityLeft = self:__BaseFertility(plot:GetIndex());

		if(iFertilityLeft > 0) then
			if(self:__IsContinentalDivide(plot) == true) then
				local iContinentalWeight = GlobalParameters.START_FERTILITY_WEIGHT_CONTINENTAL_DIVIDE or 250;
				iFertilityLeft = iFertilityLeft - iContinentalWeight
			else
				local bAddLuxury = true;
				local iLuxWeight = GlobalParameters.START_FERTILITY_WEIGHT_LUXURY or 250;
				while iFertilityLeft >= iLuxWeight and bAddLuxury == true do 
					bAddLuxury = self:__AddLuxury(plot);
					if(bAddLuxury == true) then
						iFertilityLeft = iFertilityLeft - iLuxWeight;
					end
				end
			end
			local bAddBonus = true;
			local iBonusWeight = GlobalParameters.START_FERTILITY_WEIGHT_BONUS or 75;
			while iFertilityLeft >= iBonusWeight and bAddBonus == true do 
				bAddBonus = self:__AddBonus(plot);
				if(bAddBonus == true) then
					iFertilityLeft = iFertilityLeft - iBonusWeight;
				end
			end
		end
	end
end
------------------------------------------------------------------------------
function AssignStartingPlots:__AddResourcesLegendary()
	local iStartEra = GameInfo.Eras[ GameConfiguration.GetStartEra() ];
	local iStartIndex = 1;
	if iStartEra ~= nil then
		iStartIndex = iStartEra.ChronologyIndex;
	end

	local iLegendaryBonusResources = GlobalParameters.START_LEGENDARY_BONUS_QUANTITY or 2;
	local iLegendaryLuxuryResources = GlobalParameters.START_LEGENDARY_LUXURY_QUANTITY or 1;
	for i, plot in ipairs(self.majorStartPlots) do
		self:__BalancedStrategic(plot, iStartIndex);

		if(self:__IsContinentalDivide(plot) == true) then
			iLegendaryLuxuryResources = iLegendaryLuxuryResources - 1;
		else	
			local bAddLuxury = true;
			while iLegendaryLuxuryResources > 0 and bAddLuxury == true do 
				bAddLuxury = self:__AddLuxury(plot);
				if(bAddLuxury == true) then
						iLegendaryLuxuryResources = iLegendaryLuxuryResources - 1;
				end
			end
		end

		local bAddBonus = true;
		iLegendaryBonusResources = iLegendaryBonusResources + 2 * iLegendaryLuxuryResources;
		while iLegendaryBonusResources > 0 and bAddBonus == true do 
			bAddBonus = self:__AddBonus(plot);
			if(bAddBonus == true) then
					iLegendaryBonusResources = iLegendaryBonusResources - 1;
			end
		end
	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__BalancedStrategic(plot, iStartIndex)
	local iResourcesInDB = 0;
	eResourceType	= {};
	eResourceClassType = {};	
	eRevealedEra = {};	
	local iRange = STRATEGIC_RESOURCE_FERTILITY_STARTING_ERA_RANGE or 1;

	for row in GameInfo.Resources() do
		eResourceType[iResourcesInDB] = row.Index;
		eResourceClassType[iResourcesInDB] = row.ResourceClassType;
		eRevealedEra[iResourcesInDB] = row.RevealedEra;
	    iResourcesInDB = iResourcesInDB + 1;
	end

	for row = 0, iResourcesInDB do
		if (eResourceClassType[row]== "RESOURCECLASS_STRATEGIC") then
			if(iStartIndex - iRange <= eRevealedEra[row] and iStartIndex + iRange >= eRevealedEra[row]) then
				local bHasResource = false;
				bHasResource = self:__FindSpecificStrategic(eResourceType[row], plot);	
				if(bHasResource == false) then
					self:__AddStrategic(eResourceType[row], plot)
					--print("Placed!");
				end
			end
		end
	end
end

------------------------------------------------------------------------------
function AssignStartingPlots:__FindSpecificStrategic(eResourceType, plot)
	-- Checks to see if there is a specific strategic in a given distance

	local plotX = plot:GetX();
	local plotY = plot:GetY();
	for dx = -3, 3 do
		for dy = -3,3 do
			local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 3);
			if(otherPlot) then
				if(otherPlot:GetResourceCount() > 0) then
					if(eResourceType == otherPlot:GetResourceType() ) then
						return true;
					end
				end
			end
		end
	end 

	return false;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__AddStrategic(eResourceType, plot)
	-- Checks to see if it can place a specific strategic

	local plotX = plot:GetX();
	local plotY = plot:GetY();
	for dx = -3, 3 do
		for dy = -3,3 do
			local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 3);
			if(otherPlot) then
				if(ResourceBuilder.CanHaveResource(otherPlot, eResourceType) and otherPlot:GetIndex() ~= plot:GetIndex()) then
					ResourceBuilder.SetResourceType(otherPlot, eResourceType, 1);
					return;
				end
			end
		end
	end 

	--print("Failed");
end

------------------------------------------------------------------------------
function AssignStartingPlots:__AddLuxury(plot)
	-- Checks to see if it can place a nearby luxury

	local iResourcesInDB = 0;
	eResourceType	= {};
	eResourceClassType	= {};
	eAddLux	= {};

	for row in GameInfo.Resources() do
		eResourceType[iResourcesInDB] = row.Index;
		eResourceClassType[iResourcesInDB] = row.ResourceClassType;
		iResourcesInDB = iResourcesInDB + 1;
	end

	local plotX = plot:GetX();
	local plotY = plot:GetY();
	for dx = -4, 4 do
		for dy = -4, 4 do
			local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 4);
			if(otherPlot) then
				if(otherPlot:GetResourceCount() > 0) then
					for row = 0, iResourcesInDB do
						if (eResourceClassType[row]== "RESOURCECLASS_LUXURY") then
							if(otherPlot:GetResourceType() == eResourceType[row]) then
								table.insert(eAddLux, eResourceType[row]);
							end
						end
					end
				end
			end
		end
	end 

	for dx = -2, 2 do
		for dy = -2, 2 do
			local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 2);
			if(otherPlot) then
				eAddLux =  GetShuffledCopyOfTable(eAddLux);
				for i, resource in ipairs(eAddLux) do
					if(ResourceBuilder.CanHaveResource(otherPlot, resource) and otherPlot:GetIndex() ~= plot:GetIndex()) then
						ResourceBuilder.SetResourceType(otherPlot, resource, 1);
						--print("Yeah Lux");
						return true;
					end
				end
			end
		end
	end 

	--print("Failed Lux");
	return false;
end

------------------------------------------------------------------------------
function AssignStartingPlots:__AddBonus(plot)
	local iResourcesInDB = 0;
	eResourceType	= {};
	eResourceClassType = {};
	aBonus = {};

	for row in GameInfo.Resources() do
		eResourceType[iResourcesInDB] = row.Index;
		eResourceClassType[iResourcesInDB] = row.ResourceClassType;
	    iResourcesInDB = iResourcesInDB + 1;
	end

	for row = 0, iResourcesInDB do
		if (eResourceClassType[row] == "RESOURCECLASS_BONUS") then
			for row2 in GameInfo.TypeTags() do
				if(GameInfo.Resources[row2.Type] ~= nil) then
					table.insert(aBonus, eResourceType[row]);
				end
			end
		end
	end

	local plotX = plot:GetX();
	local plotY = plot:GetY();
	aBonus =  GetShuffledCopyOfTable(aBonus);
	for i, resource in ipairs(aBonus) do
		for dx = -2, 2 do
			for dy = -2, 2 do
				local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 2);
				if(otherPlot) then
					if(ResourceBuilder.CanHaveResource(otherPlot, resource) and otherPlot:GetIndex() ~= plot:GetIndex()) then
						ResourceBuilder.SetResourceType(otherPlot, resource, 1);
						--print("Yeah Bonus");
						return true;
					end
				end
			end
		end
	end 

	--print("Failed Bonus");
	return false
end


------------------------------------------------------------------------------
function AssignStartingPlots:__IsContinentalDivide(plot)
	local plotX = plot:GetX();
	local plotY = plot:GetY();

	eContinents	= {};

	for dx = -4, 4 do
		for dy = -4, 4 do
			local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 4);
			if(otherPlot) then
				if(otherPlot:GetContinentType() ~= nil) then
					if(#eContinents == 0) then
						table.insert(eContinents, otherPlot:GetContinentType());
					else
						if(eContinents[1] ~= otherPlot:GetContinentType()) then
							return true;
						end
					end
				end
			end
		end
	end 
	
	return false;
end


------------------------------------------------------------------------------
-- **************************** YnAMP functions ******************************
------------------------------------------------------------------------------

print ("Loading YnAMP functions ...")

local g_StartingPlotRange
local g_MinStartDistanceMajor
local g_MaxStartDistanceMajor

------------------------------------------------------------------------------
-- Create Tables
------------------------------------------------------------------------------
hasBuildExclusionList = false
function buildExclusionList()
	print ("Building Region Exclusion list for "..tostring(mapName).."...")
	
	for RegionRow in GameInfo.RegionPosition() do
		if RegionRow.MapName == mapName  then
			local region = RegionRow.Region
			print ("  - Exclusion list for "..tostring(region))
			if region then
				local resExclusionTable = {}
				local resExclusiveTable = {}
				
				-- Find resources that can't be placed in that region
				for exclusionList in GameInfo.ResourceRegionExclude() do
					if exclusionList.Region == region then 
						if exclusionList.Resource  then
							if GameInfo.Resources[exclusionList.Resource] then
								table.insert(resExclusionTable, GameInfo.Resources[exclusionList.Resource].Index)
							else
								print ("  - WARNING : can't find "..tostring(exclusionList.Resource).." in Resources")
							end
						else
							print ("  - WARNING : found nil Resource")
						end
					end
				end
				
				-- Find resource that can only be placed in specific regions
				for exclusiveList in GameInfo.ResourceRegionExclusive() do
					if exclusiveList.Region == region then 
						if exclusiveList.Resource  then
							if GameInfo.Resources[exclusiveList.Resource] then
								local eResourceID = GameInfo.Resources[exclusiveList.Resource].Index
								table.insert(resExclusiveTable, eResourceID)
								isResourceExclusive[eResourceID] = true
							else
								print ("  - WARNING : can't find "..tostring(exclusiveList.Resource).." in Resources")
							end
						else
							print ("  - WARNING : found nil Resource")
						end
					end
				end
				
				-- fill the exclusion/exclusive table
				if (#resExclusionTable > 0) or (#resExclusiveTable > 0) then
					for x = RegionRow.X, RegionRow.X + RegionRow.Width do
						for y = RegionRow.Y, RegionRow.Y + RegionRow.Height do
							if (isResourceExcludedXY[x] and isResourceExcludedXY[x][y]) then
								for i, resourceID in ipairs(resExclusionTable) do
									isResourceExcludedXY[x][y][resourceID] = true
								end
								for i, resourceID in ipairs(resExclusiveTable) do
									isResourceExclusiveXY[x][y][resourceID] = true
								end
							else
								print ("  - WARNING : Region out of bound ( x = " ..tostring(x)..", y = ".. tostring(y).." )")
							end
						end
					end
				end
				if (#resExclusionTable > 0) then
					print("   - Exluded resources :")
					for i, resourceID in ipairs(resExclusionTable) do
						print("      "..tostring(GameInfo.Resources[resourceID].ResourceType))
					end
				end
				if (#resExclusiveTable > 0) then
					print("   - Exlusive resources :")
					for i, resourceID in ipairs(resExclusiveTable) do
						print("      "..tostring(GameInfo.Resources[resourceID].ResourceType))
					end	
				end			
			else
				print ("  - WARNING : found nil region")
			end
		end
	end
	hasBuildExclusionList = true
end

function buidTSL()
	print ("------------------------------------------------------------------------------")
	print ("Building TSL list for "..tostring(mapName).."...")
	
	local bAlternateTSL 	= MapConfiguration.GetValue("AlternateTSL")
	local bLeaderTSL 		= MapConfiguration.GetValue("LeaderTSL")
	local tAlternateTSL 	= {}
	local tHasSpecificTSL 	= {}
		
	-- Create list of leaders TSL
	for row in GameInfo.StartPosition() do
		if row.MapName == mapName  then
			if row.Leader then
				tHasSpecificTSL[row.Leader] = true
			end
		end
	end
	
	-- Create list of possible alternates TSL
	if bAlternateTSL then
		for row in GameInfo.StartPosition() do
			if row.MapName == mapName  then
				if row.AlternateStart and row.AlternateStart == 1 and isInGame[row.Civilization] then
					if not (row.DisabledByCivilization and isInGame[row.DisabledByCivilization]) then
						if not (row.DisabledByLeader and isInGame[row.DisabledByLeader]) then
							if not tAlternateTSL[row.Civilization] then 
								tAlternateTSL[row.Civilization] = {} 
							end
							table.insert(tAlternateTSL[row.Civilization], row)
						end
					end
				end
			end
		end
	end
	
	-- local function to check distance between a new TSL and those already reserved if AlternateStart are used
	local function InRangeCurrentTSL(row, currentTSL)
		local MinDistance = GlobalParameters.CITY_MIN_RANGE
		for iPlayer, position in pairs(currentTSL) do
			local player = Players[iPlayer]
			if Map.GetPlotDistance(row.X, row.Y, position.X, position.Y) <= MinDistance then
				return true
			end
		end
		return false
	end
	
	-- Reserve TSL for each civ
	for row in GameInfo.StartPosition() do
		if row.MapName == mapName and not(row.AlternateStart and row.AlternateStart == 1) then -- Alternate TSL are already in their own table, to be used if the normal TSL is unavailable
			for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do -- players can share a Civilization/Leader, so we can't assume "one TSL by Civilization/Leader" and need to loop the players table
				local CivilizationTypeName = PlayerConfigurations[iPlayer]:GetCivilizationTypeName()
				if row.Civilization == CivilizationTypeName then
					local LeaderTypeName = PlayerConfigurations[iPlayer]:GetLeaderTypeName()
					local bCanPlaceHere = true
					local sWarning = ""
					local plot = Map.GetPlot(row.X,row.Y)
					
					if row.DisabledByCivilization and isInGame[row.DisabledByCivilization] then
						sWarning = "position disabled by " .. tostring(row.DisabledByCivilization)
						bCanPlaceHere = false
					elseif row.DisabledByLeader and isInGame[row.DisabledByLeader] then
						sWarning = "position disabled by " .. tostring(row.DisabledByLeader)
						bCanPlaceHere = false
					elseif InRangeCurrentTSL(row, getTSL) then
						sWarning = "too close from another TSL"
						bCanPlaceHere = false
					elseif plot and(plot:IsWater() or plot:IsImpassable()) then
						sWarning = "plot is impassable or water"
						bCanPlaceHere = false
					end	
					
					if row.Leader then -- Leaders TSL are exclusive
						if bLeaderTSL and row.Leader == LeaderTypeName then
							print ("- Checking Leader specific TSL for "..tostring(LeaderTypeName).." of "..tostring(CivilizationTypeName).." at "..tostring(row.X)..","..tostring(row.Y))
							if bAlternateTSL and not bCanPlaceHere then
								local bFound = false
								if tAlternateTSL[row.Civilization] then
									for _, alternateRow in ipairs(tAlternateTSL[row.Civilization]) do
										if (not bFound) and alternateRow.Leader and (alternateRow.Leader == LeaderTypeName) then
											print ("   - Reserving alternative TSL at "..tostring(alternateRow.X)..","..tostring(alternateRow.Y).." (initial TSL "..sWarning..")")
											getTSL[iPlayer] = {X = alternateRow.X, Y = alternateRow.Y}
											bFound = true
										end										
									end									
								end
								if (not bFound) then
									print ("   - Reserving TSL with WARNING ("..sWarning.." and no alternative TSL found) at "..tostring(row.X)..","..tostring(row.Y))
									getTSL[iPlayer] = {X = row.X, Y = row.Y}										
								end
							else
								if bCanPlaceHere then
									print ("   - Reserving TSL at "..tostring(row.X)..","..tostring(row.Y))
								else
									print ("   - Reserving TSL with WARNING ("..sWarning.." and no alternative TSL allowed) at "..tostring(row.X)..","..tostring(row.Y))
								end
								getTSL[iPlayer] = {X = row.X, Y = row.Y}								
							end
						end
						
					elseif (not bLeaderTSL) or (not tHasSpecificTSL[LeaderTypeName]) then -- If a Leaders has a specific TSL available, it will never use generic TSL for its Civilization
						print ("- Checking generic civilization TSL for "..tostring(LeaderTypeName).." of "..tostring(CivilizationTypeName).." at "..tostring(row.X)..","..tostring(row.Y))						
						if bAlternateTSL and not bCanPlaceHere then
							local bFound = false
							if tAlternateTSL[row.Civilization] then
								for _, alternateRow in ipairs(tAlternateTSL[row.Civilization]) do
									if (not bFound) and not alternateRow.Leader then
										print ("   - Reserving alternative TSL at "..tostring(alternateRow.X)..","..tostring(alternateRow.Y).." (initial TSL "..sWarning..")")
										getTSL[iPlayer] = {X = alternateRow.X, Y = alternateRow.Y}
										bFound = true
									end										
								end									
							end
							if (not bFound) then
								print ("   - Reserving TSL with WARNING ("..sWarning.." and no alternative TSL found) at "..tostring(row.X)..","..tostring(row.Y))
								getTSL[iPlayer] = {X = row.X, Y = row.Y}										
							end
						else
							if bCanPlaceHere then
								print ("   - Reserving TSL at "..tostring(row.X)..","..tostring(row.Y))
							else
								print ("   - Reserving TSL with WARNING ("..sWarning.." and no alternative TSL allowed) at "..tostring(row.X)..","..tostring(row.Y))
							end
							getTSL[iPlayer] = {X = row.X, Y = row.Y}								
						end						
					end
				end
			end
		end
	end
	
	-- List Civs without TSL
	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		if not getTSL[iPlayer] then
			local player = Players[iPlayer]
			local CivilizationTypeName = PlayerConfigurations[iPlayer]:GetCivilizationTypeName()
			local LeaderTypeName = PlayerConfigurations[iPlayer]:GetLeaderTypeName()
			print ("WARNING : no starting position reserved for "..tostring(LeaderTypeName).." of "..tostring(CivilizationTypeName) )
		end
	end	
	print ("------------------------------------------------------------------------------")
end


------------------------------------------------------------------------------
-- Imported Maps Creation
------------------------------------------------------------------------------

function GenerateImportedMap(MapToConvert, Civ6DataToConvert, NaturalWonders, g_iW, g_iH)

	--local pPlot
	--g_iFlags = TerrainBuilder.GetFractalFlags();
	
	g_MaxStartDistanceMajor = math.sqrt(g_iW * g_iH / PlayerManager.GetWasEverAliveMajorsCount())
	g_MinStartDistanceMajor = g_MaxStartDistanceMajor / 3
	print("g_MaxStartDistanceMajor = ", g_MaxStartDistanceMajor)
	print("g_MinStartDistanceMajor = ", g_MinStartDistanceMajor)
	
	local bIsCiv5Map = (#MapToConvert[0][0][6] == 2) -- 6th entry is resource for civ5 data ( = 2 : type and number), cliffs positions for civ6 data ( = 3 : all possible positions on a hexagon side)
	
	print("Importing Map Data (Civ5 = "..tostring(bIsCiv5Map)..")")

	local currentTimer = 0
	currentTimer = os.clock() - g_startTimer
	print("Current timer at beginning of Map creation (Map script is loaded) = "..tostring(currentTimer).." seconds")
	
	-- Create the resource exclusion table now, in case we call YnAMP_CanHaveResource before filling it, at least it wont crash
	if bResourceExclusion then
		for x = 0, g_iW - 1, 1 do
			isResourceExcludedXY[x] = {}
			isResourceExclusiveXY[x] = {}
			for y = 0, g_iH - 1, 1 do
				isResourceExcludedXY[x][y] = {}
				isResourceExclusiveXY[x][y] = {}
			end
		end
	end
		
	local featuresPlacement = MapConfiguration.GetValue("FeaturesPlacement")
	print("Features placement = "..tostring(featuresPlacement))	
	local bImportFeatures = featuresPlacement == "PLACEMENT_IMPORT"
	local bNoFeatures = featuresPlacement == "PLACEMENT_EMPTY"
	
	local riversPlacement = MapConfiguration.GetValue("RiversPlacement")
	print("Rivers Placement = "..tostring(riversPlacement))	
	local bImportRivers = riversPlacement == "PLACEMENT_IMPORT"
	local bNoRivers = riversPlacement == "PLACEMENT_EMPTY"
	
	local resourcePlacement = MapConfiguration.GetValue("ResourcesPlacement")
	print("Resource placement = "..tostring(resourcePlacement))	
	local bNoResources = resourcePlacement == "PLACEMENT_EMPTY"
	
	local naturalWondersPlacement = MapConfiguration.GetValue("NaturalWondersPlacement")
	print("Natural Wonders placement = "..tostring(naturalWondersPlacement))	
	local bImportNaturalWonders = naturalWondersPlacement == "PLACEMENT_IMPORT"
	local bNoNaturalWonders = naturalWondersPlacement == "PLACEMENT_EMPTY"
	
	local continentsPlacement = MapConfiguration.GetValue("ContinentsPlacement")
	print("Continents naming = "..tostring(continentsPlacement))	
	local bImportContinents = continentsPlacement == "PLACEMENT_IMPORT"

	-- We'll do importation of Rivers after Natural Wonders placement, as they can create incompatibilities and Resources come after Rivers (in case Rivers are generated instead of imported)
	-- We do Features now to prevent overriding the NW placement
	-- First pass: create terrains and place cliffs... (	bDoTerrains, 	bImportRivers, 	bImportFeatures, 	bImportResources, 	bDoCliffs, 	bImportContinents)
	if bIsCiv5Map then
		-- 														(	bDoTerrains, 	bImportRivers, 	bImportFeatures, 	bImportResources, 	bDoCliffs, 	bImportContinents)
		ImportCiv5Map(MapToConvert, Civ6DataToConvert, g_iW, g_iH, 	true, 			false, 			bImportFeatures, 	false, 			true, 		false)
	else
		-- 									(	bDoTerrains, 	bImportRivers, 	bImportFeatures, 	bImportResources, 	bImportContinents)
		ImportCiv6Map(MapToConvert, g_iW, g_iH, true, 			false, 			bImportFeatures, 	false, 			false)	
	end
	currentTimer = os.clock() - g_startTimer
	print("Intermediate timer = "..tostring(currentTimer).." seconds")

	-- Temp
	AreaBuilder.Recalculate();
	local biggest_area = Areas.FindBiggestArea(false);
	print("After Adding Hills: ", biggest_area:GetPlotCount());
	
	currentTimer = os.clock() - g_startTimer
	print("Intermediate timer = "..tostring(currentTimer).." seconds")		
	
	-- River generation is affected by plot types, originating from highlands and preferring to traverse lowlands.
	if not (bImportRivers or bNoRivers)  then
		AddRivers()
	end

	-- NW placement is affected by rivers, but when importing placement can be forced
	if not (bImportNaturalWonders or bNoNaturalWonders)  then
		local args = {
			numberToPlace = GameInfo.Maps[Map.GetMapSize()].NumNaturalWonders,
		};
		local nwGen = NaturalWonderGenerator.Create(args);
	end
	if bImportNaturalWonders then
		PlaceRealNaturalWonders(NaturalWonders)
	end
	
	currentTimer = os.clock() - g_startTimer
	print("Intermediate timer = "..tostring(currentTimer).." seconds")
		
	-- Second pass : importing options...	
	if bIsCiv5Map then
		-- 														(	bDoTerrains, 	bImportRivers, 	bImportFeatures, 	bImportResources, bDoCliffs, 	bImportContinents)
		ImportCiv5Map(MapToConvert, Civ6DataToConvert, g_iW, g_iH, 	false, 			bImportRivers, 	false, 				bImportResources, false, 		bImportContinents)
	else
		-- 										(	bDoTerrains, 	bImportRivers, 	bImportFeatures, 	bImportResources, bImportContinents)
		ImportCiv6Map(MapToConvert, g_iW, g_iH, 	false, 			bImportRivers, 	false, 				bImportResources, bImportContinents)	
	end

	-- Now that we are certain that rivers were placed we can add features if they were not imported
	if not (bImportFeatures or bNoFeatures) then
		AddFeatures()
	end

	currentTimer = os.clock() - g_startTimer
	print("Intermediate timer before AreaBuilder.Recalculate() = "..tostring(currentTimer).." seconds")
	
	AreaBuilder.Recalculate();
	
	if not bImportContinents then
		currentTimer = os.clock() - g_startTimer
		print("Intermediate timer before TerrainBuilder.StampContinents() = "..tostring(currentTimer).." seconds")	
		TerrainBuilder.StampContinents();
	end
	
	currentTimer = os.clock() - g_startTimer
	print("Intermediate timer = "..tostring(currentTimer).." seconds")
	
	if bRealDeposits then
		AddDeposits()
		-- to do : how to balance with normal placement ?
		-- Deposits should be mostly strategic, so call AddDeposit after ResourceGenerator.Create and remove a number of previous resources ?
	end
	
	if not (bImportResources or bNoResources) then
		if bResourceExclusion then
			buildExclusionList()
			placeExclusiveResources()
		end
		resourcesConfig = MapConfiguration.GetValue("resources");
		local args = {
			resources = resourcesConfig,
		};
		ResourceGenerator.Create(args);
	else
		--local resourceType = GameInfo.Resources["RESOURCE_NITER"].Index
		--print(" Adding Civ6 resource : Niter (TypeID = " .. tostring(resourceType)..")")
		--PlaceStrategicResources(resourceType)
	end
	
	-- The map may require some specific placement...
	ExtraPlacement()
	
	-- Analyse Chokepoints after extra placement...
	currentTimer = os.clock() - g_startTimer
	print("Intermediate timer before TerrainBuilder.AnalyzeChokepoints() = "..tostring(currentTimer).." seconds")
	
	if not WorldBuilder:IsActive() and bAnalyseChokepoints then -- to do : must use an option here, is this added to saved map ? will they work without this ? But it saves a lot of time for editing and exporting terrain data for YnAMP
		TerrainBuilder.AnalyzeChokepoints();
	else
		print("Worldbuilder detected, skipping TerrainBuilder.AnalyzeChokepoints()...")
		print("WARNING skipping AnalyzeChokepoints may (or may not) create issues with saved maps (exporting for YnAMP scripts is not affected)")
	end
		
	currentTimer = os.clock() - g_startTimer
	print("Intermediate timer = "..tostring(currentTimer).." seconds")
	
	print("Creating start plot database.")	
	if bTSL then
		buidTSL()
	end	
	local startConfig = MapConfiguration.GetValue("start");-- Get the start config
	-- START_MIN_Y and START_MAX_Y is the percent of the map ignored for major civs' starting positions.
	local args = {
		MIN_MAJOR_CIV_FERTILITY = 150,
		MIN_MINOR_CIV_FERTILITY = 50, 
		MIN_BARBARIAN_FERTILITY = 1,
		START_MIN_Y = 15,
		START_MAX_Y = 15,
		START_CONFIG = startConfig,
	}	
	currentTimer = os.clock() - g_startTimer
	print("Intermediate timer before AssignStartingPlots.Create(args) = "..tostring(currentTimer).." seconds")	
	local start_plot_database = AssignStartingPlots.Create(args)				
	
	currentTimer = os.clock() - g_startTimer
	print("Intermediate timer = "..tostring(currentTimer).." seconds")
	
	ResourcesValidation(g_iW, g_iH) -- before Civ specific resources may be added (we allow exclusion override then)

	-- Check if all selected civs have been given a Starting Location
	if not bTSL or bAlternatePlacement then
		CheckAllCivilizationsStartingLocations()
	end
		
	if bRequestedResources and not bNoResources then
		AddStartingLocationResources()
	end
		
	-- Balance Starting positions for TSL
	if bTSL then	
		currentTimer = os.clock() - g_startTimer
		print("Intermediate timer before balancing TSL = "..tostring(currentTimer).." seconds")
		-- to do : remove magic numbers
		--if startConfig == 1 then AssignStartingPlots:__AddResourcesBalanced() end
		--if startConfig == 3 then AssignStartingPlots:__AddResourcesLegendary()() end
		
		for _, iPlayer in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
			local player = Players[iPlayer]
			local plot = player:GetStartingPlot(plot)
			if plot then
				AssignStartingPlots:__AddBonusFoodProduction(plot)
			end
		end		
		
	end
	
	currentTimer = os.clock() - g_startTimer
	print("Intermediate timer = "..tostring(currentTimer).." seconds")

	local GoodyGen = AddGoodies(g_iW, g_iH);
	
	local totalTimer = os.clock() - g_startTimer
	
	-- Restore the original ResourceBuilder.CanHaveResource
	ResourceBuilder.CanHaveResource = ResourceBuilder.OldCanHaveResource
	
	print("Total time for Map creation = "..tostring(totalTimer).." seconds")
end

-------------------------------------------------------------------------------
-- Find backup starting positions if the game's start positioner as failed
-------------------------------------------------------------------------------
function CheckAllCivilizationsStartingLocations()

	-- Check for Civilization placement
	local bNeedPlacementUpdate 	= false
	local toPlace 				= {}
	for _, iPlayer in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
		local player = Players[iPlayer]
		local plot = player:GetStartingPlot(plot)
		if not plot and player:IsMajor() then
			print("WARNING : no starting plot set for player ID#" .. tostring(iPlayer) .. " " .. PlayerConfigurations[iPlayer]:GetPlayerName())
			table.insert(toPlace, iPlayer)
		end
	end
	
	if #toPlace > 0 then
		bExtraStartingPlotPlacement = true -- tell AssignStartingPlots:__SetStartMajor to use a different method for checking space between civs
		local startPlotList = GetCustomStartingPlots()
		for i, iPlayer in ipairs(toPlace) do
			print("Searching custom starting plot for " .. PlayerConfigurations[iPlayer]:GetPlayerName())
			local pPlot = GetBestStartingPlotFromList(startPlotList)
			if pPlot then
				local player = Players[iPlayer]
				player:SetStartingPlot(pPlot)
				bNeedPlacementUpdate = true
			end
		end
	end
	
	local notPlaced = 0
	for _, iPlayer in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
		local player = Players[iPlayer]
		local plot = player:GetStartingPlot(plot)
		if not plot then
			notPlaced = notPlaced + 1
		end
	end
	if notPlaced > 0 then
		print("WARNING : Still no starting plot for #" .. tostring(notPlaced) .. " major civilizations")
	else
		print("All #"..tostring(PlayerManager.GetWasEverAliveMajorsCount()).." major civilizations placed !")
	end
	
	local toPlace 			= {}
	for _, iPlayer in ipairs(PlayerManager.GetAliveMinorIDs()) do
		local player = Players[iPlayer]
		local plot = player:GetStartingPlot(plot)
		if not plot then
			print("WARNING : no starting plot set for player ID#" .. tostring(iPlayer) .. " " .. PlayerConfigurations[iPlayer]:GetPlayerName())
			table.insert(toPlace, iPlayer)
		end
	end
	
	if #toPlace > 0 then
		bExtraStartingPlotPlacement = true -- tell AssignStartingPlots:__SetStartMajor to use a different method for checking space between civs
		local startPlotList = GetCustomStartingPlots()
		for i, iPlayer in ipairs(toPlace) do
			print("Searching custom starting plot for " .. PlayerConfigurations[iPlayer]:GetPlayerName())
			local pPlot = GetBestStartingPlotFromList(startPlotList, true)
			if pPlot then
				local player = Players[iPlayer]
				player:SetStartingPlot(pPlot)
				bNeedPlacementUpdate = true
			end
		end
	end
	
	local notPlaced = 0
	for _, iPlayer in ipairs(PlayerManager.GetAliveMinorIDs()) do
		local player = Players[iPlayer]
		local plot = player:GetStartingPlot(plot)
		if not plot then
			notPlaced = notPlaced + 1
		end
	end
	if notPlaced > 0 then
		print("WARNING : Still no starting plot for #" .. tostring(notPlaced) .. " minor civilizations")
	elseif PlayerManager.GetAliveMinorsCount() > 0 then
		print("All #"..tostring(PlayerManager.GetAliveMinorsCount()).." minor civilizations placed !")
	end
	
	
	if bCulturallyLinked and bNeedPlacementUpdate then
		print("Updating Culturally Linked placement...")
		CulturallyLinkedCivilizations(true)	
		CulturallyLinkedCityStates(true)	
	end
end

function GetPlotFertility(plot)
	-- Calculate the fertility of the starting plot
	local iRange = 3;
	local pPlot = plot;
	local plotX = pPlot:GetX();
	local plotY = pPlot:GetY();

	local gridWidth, gridHeight = Map.GetGridSize();
	local gridHeightMinus1 = gridHeight - 1;

	local iFertility = 0;
	
	--Rivers are awesome to start next to
	local terrainType = pPlot:GetTerrainType();
	if(pPlot:IsFreshWater() == true and terrainType ~= g_TERRAIN_TYPE_SNOW and terrainType ~= g_TERRAIN_TYPE_SNOW_HILLS and pPlot:IsImpassable() ~= true) then
		iFertility = iFertility + 50;
		if pPlot:IsRiver() == true then
			iFertility = iFertility + 50
		end
	end	
	
	for dx = -iRange, iRange do
		for dy = -iRange,iRange do
			local otherPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, iRange);

			-- Valid plot?  Also, skip plots along the top and bottom edge
			if(otherPlot) then
				local otherPlotY = otherPlot:GetY();
				if(otherPlotY > 0 and otherPlotY < gridHeightMinus1) then

					terrainType = otherPlot:GetTerrainType();
					featureType = otherPlot:GetFeatureType();

					-- Subtract one if there is snow and no resource. Do not count water plots unless there is a resource
					if((terrainType == g_TERRAIN_TYPE_SNOW or terrainType == g_TERRAIN_TYPE_SNOW_HILLS or terrainType == g_TERRAIN_TYPE_SNOW_MOUNTAIN) and otherPlot:GetResourceCount() == 0) then
						iFertility = iFertility - 10;
					elseif(featureType == g_FEATURE_ICE) then
						iFertility = iFertility - 20;
					elseif((otherPlot:IsWater() == false) or otherPlot:GetResourceCount() > 0) then
						iFertility = iFertility + (otherPlot:GetYield(g_YIELD_PRODUCTION)*3)
						iFertility = iFertility + (otherPlot:GetYield(g_YIELD_FOOD)*5)
					end
				
					-- Lower the Fertility if the plot is impassable
					if(iFertility > 5 and otherPlot:IsImpassable() == true) then
						iFertility = iFertility - 5;
					end

					-- Lower the Fertility if the plot has Features
					if(featureType ~= g_FEATURE_NONE) then
						iFertility = iFertility - 2
					end	

				else
					iFertility = iFertility - 20;
				end
			else
				iFertility = iFertility - 20;
			end
		end
	end 

	return iFertility;
end

function IsStartingDistanceFarEnough(plot, bIsMinor)
	-- we're using the alternate placement method because the start positioner as failed, maybe because there are too many civs on the map
	-- so we use a minimum start distance calculated on map size 
	local MinDistance 				= math.min(g_MinStartDistanceMajor, (GlobalParameters.START_DISTANCE_MAJOR_CIVILIZATION or 9))
	if bIsMinor then MinDistance 	= math.min(g_MinStartDistanceMajor, (GlobalParameters.START_DISTANCE_MINOR_CIVILIZATION or 5))	end
	MinDistance 					= math.max(GlobalParameters.CITY_MIN_RANGE, MinDistance)
	
	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local player = Players[iPlayer]
		local startingPlot = player:GetStartingPlot()
		if startingPlot then 
			local distance 	= Map.GetPlotDistance(plot:GetIndex(), startingPlot:GetIndex())
			if distance <= MinDistance then
				--print("Not far enough, distance = ".. tostring(distance) .." <= MinDistance of "..tostring(MinDistance))
				return false
			end
		end
	end
	return true
end

function GetCustomStartingPlots()
	local g_iW, g_iH 	= Map.GetGridSize()
	local potentialPlots 	= {}

	for iX = 0, g_iW - 1 do
		for iY = 0, g_iH - 1 do
			local index = (iY * g_iW) + iX;
			pPlot = Map.GetPlotByIndex(index)
			local fertility = GetPlotFertility(pPlot)
			if fertility > 50 then
				--print("fertility = ", fertility)
				table.insert(potentialPlots, { Plot = pPlot, Fertility = fertility} )
			end
		end
	end
	print("GetCustomStartingPlots returns "..tostring(#potentialPlots).." plots")
	
	table.sort (potentialPlots, function(a, b) return a.Fertility > b.Fertility; end);
	return potentialPlots
end

function GetBestStartingPlotFromList(plots, bIsMinor)

	sortedPlots = plots

	if not plots then -- sometime the start positioner fails...
		print("WARNING: plots is nil for SetStartMajor(plots) !")
		print("Skipping...")
		return nil
	else
		--print("num plots = " .. tostring(#plots).. " in SetStartMajor(plots)")
	end
	
	local iSize = #plots;
	local iContinentIndex 	= 1
	local bValid 			= false;
	while bValid == false and iSize >= iContinentIndex do
		bValid = true;
		local NWMajor = 0;
		if sortedPlots[iContinentIndex].Plot then
			pTempPlot = sortedPlots[iContinentIndex].Plot;
			--print("Fertility: ", sortedPlots[iContinentIndex].Fertility)

			-- Checks to see if the plot is impassable
			if(pTempPlot:IsImpassable() == true) then
				bValid = false;
			end

			-- Checks to see if the plot is water
			if(pTempPlot:IsWater() == true) then
				bValid = false;
			end

			-- Checks to see if there are any major civs in the given distance
			local bMajorCivCheck = IsStartingDistanceFarEnough(pTempPlot, bIsMinor)
			if(bMajorCivCheck == false) then
				bValid = false;
				sortedPlots[iContinentIndex].Plot = nil -- no need to test that plot again...
			end
			
			iContinentIndex = iContinentIndex + 1;

			-- If the plots passes all the checks then the plot equals the temp plot
			if(bValid == true) then
				print("GetBestStartingPlotFromList : returning plot #"..tostring(iContinentIndex).."/"..tostring(iSize).." at fertility = ".. tostring(sortedPlots[iContinentIndex].Fertility))
				return pTempPlot;
			end
		else		
			iContinentIndex = iContinentIndex + 1;
			bValid = false
		end
	end

	return nil;
end

-------------------------------------------------------------------------------
-- Features & Extra placement
-------------------------------------------------------------------------------
function PlaceRealNaturalWonders(NaturalWonders)
	print("YnAMP Natural Wonders placement...")

	-- Adding custom NW to the table
	local DirectPlacementPlots = {}
	for NaturalWonderRow in GameInfo.NaturalWonderPosition() do
		if NaturalWonderRow.MapName == mapName and GameInfo.Features[NaturalWonderRow.FeatureType] then
			local eFeatureType = GameInfo.Features[NaturalWonderRow.FeatureType].Index
			if NaturalWonders[eFeatureType] then
				-- Seems to be a multiplots feature...
				if not DirectPlacementPlots[eFeatureType] then
					-- add original plot entry to the multiplots table
					DirectPlacementPlots[eFeatureType] = {}
					local plot = Map.GetPlot(NaturalWonders[eFeatureType].X, NaturalWonders[eFeatureType].Y)
					if plot then
						if NaturalWonderRow.TerrainType and GameInfo.Terrains[NaturalWonderRow.TerrainType] then
							TerrainBuilder.SetTerrainType(plot, GameInfo.Terrains[NaturalWonderRow.TerrainType].Index)
						end
						TerrainBuilder.SetFeatureType(plot, -1)
						ResourceBuilder.SetResourceType(plot, -1)
						table.insert(DirectPlacementPlots[eFeatureType], plot:GetIndex())
					end
				end
				-- add new plot entry to the multiplots table
				local plot = Map.GetPlot(NaturalWonderRow.X, NaturalWonderRow.Y)
				if plot then				
					if NaturalWonderRow.TerrainType and GameInfo.Terrains[NaturalWonderRow.TerrainType] then
						TerrainBuilder.SetTerrainType(plot, GameInfo.Terrains[NaturalWonderRow.TerrainType].Index)
					end
					TerrainBuilder.SetFeatureType(plot, -1)
					ResourceBuilder.SetResourceType(plot, -1)
					table.insert(DirectPlacementPlots[eFeatureType], plot:GetIndex())
				end
			else
				-- create original entry in the base table
				NaturalWonders[GameInfo.Features[NaturalWonderRow.FeatureType].Index] = { X = NaturalWonderRow.X, Y = NaturalWonderRow.Y}
				print("- Loaded " .. tostring(NaturalWonderRow.FeatureType) .." position from the DB")
			end
		end
	end
	
	-- Place all NW from the table
	for eFeatureType, position in pairs(NaturalWonders) do
		if GameInfo.Features[eFeatureType] then
			local featureTypeName = GameInfo.Features[eFeatureType].FeatureType
			local x, y = position.X, position.Y
			print ("- Trying to place " .. tostring(featureTypeName) .. " at (" .. tostring(x) .. ", " .. tostring(y) .. ")");		
			local pPlot = Map.GetPlot(x, y);
			local plotsIndex = {}
			local plotsList = {}
			local bUseOnlyPlotListPlacement = false
			
			-- Preparing placement
			if featureTypeName == "FEATURE_DEAD_SEA" then
				print(" - Preparing position...")
				-- 2 plots, flat desert surrounded by desert, 1st plot is SOUTHWEST 
				-- preparing the 2 plot
				local terrainType = g_TERRAIN_TYPE_DESERT
				table.insert(plotsList, { Plot = pPlot, Terrain = terrainType })
				table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_NORTHEAST), Terrain = terrainType })
			end		
			
			if featureTypeName == "FEATURE_PIOPIOTAHI" then
				print(" - Preparing position...")
				-- 3 plots, flat grass near coast, 1st plot is WEST
				-- preparing the 3 plots
				local terrainType = g_TERRAIN_TYPE_GRASS
				table.insert(plotsList, { Plot = pPlot, Terrain = terrainType })
				table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_NORTHEAST), Terrain = terrainType })
				table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_EAST), Terrain = terrainType })
			end
			
			if featureTypeName == "FEATURE_EVEREST" then
				print(" - Preparing position...")
				-- 3 plots, mountains, 1st plot is WEST
				-- preparing the 3 plots
				local terrainType = g_TERRAIN_TYPE_TUNDRA_MOUNTAIN
				table.insert(plotsList, { Plot = pPlot, Terrain = terrainType })
				table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_SOUTHEAST), Terrain = terrainType })
				table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_EAST), Terrain = terrainType })
			end
			
			if featureTypeName == "FEATURE_PANTANAL" then
				print(" - Preparing position...")
				-- 4 plots, flat grass/plains without features, 1st plot is SOUTH-WEST
				-- preparing the 4 plots
				local terrainType = g_TERRAIN_TYPE_PLAINS
				local pPlot2 = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_NORTHEAST) -- we need plot2 to get plot4
				table.insert(plotsList, { Plot = pPlot, Terrain = terrainType })
				table.insert(plotsList, { Plot = pPlot2, Terrain = terrainType })
				table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_EAST), Terrain = terrainType })
				table.insert(plotsList, { Plot = Map.GetAdjacentPlot(pPlot2:GetX(), pPlot2:GetY(), DirectionTypes.DIRECTION_EAST), Terrain = terrainType })
			end

			if featureTypeName == "FEATURE_CLIFFS_DOVER" then
				print(" - Preparing position...")
				-- 2 plots, hills on coast, 1st plot is WEST 
				-- preparing the 2 plots
				local terrainType = g_TERRAIN_TYPE_GRASS_HILLS
				table.insert(plotsList, { Plot = pPlot, Terrain = terrainType })
				table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_EAST), Terrain = terrainType })
			end
			
			if featureTypeName == "FEATURE_YOSEMITE" or featureTypeName == "FEATURE_EYJAFJALLAJOKULL" then
				print(" - Preparing position...")
				-- 2 plots EAST-WEST, flat tundra/plains without features, 1st plot is WEST
				-- preparing the 2 plots
				local terrainType = g_TERRAIN_TYPE_PLAINS
				table.insert(plotsList, { Plot = pPlot, Terrain = terrainType })
				table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_EAST), Terrain = terrainType })
			end
			
			if featureTypeName == "FEATURE_TORRES_DEL_PAINE" then
				print(" - Preparing position...")
				-- 2 plots EAST-WEST without features, 1st plot is WEST
				-- preparing the 2 plots
				local terrainType = g_TERRAIN_TYPE_PLAINS
				table.insert(plotsList, { Plot = pPlot, Terrain = terrainType })
				table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_EAST), Terrain = terrainType })
			end		

			if featureTypeName == "FEATURE_BARRIER_REEF" then
				print(" - Preparing position...")
				-- 2 plots, coast, 1st plot is SOUTHEAST 
				-- preparing the 2 plots
				local terrainType = g_TERRAIN_TYPE_COAST
				table.insert(plotsList, { Plot = pPlot, Terrain = terrainType })
				table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_NORTHWEST), Terrain = terrainType })
			end

			if featureTypeName == "FEATURE_GALAPAGOS" then
				print(" - Preparing position...")
				-- 2 plots, coast, surrounded by coast, 1st plot is SOUTHWEST 
				-- preparing the area
				local terrainType = g_TERRAIN_TYPE_COAST
				bUseOnlyPlotListPlacement = true
				table.insert(plotsList, { Plot = pPlot, Terrain = terrainType })
				table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_NORTHWEST), Terrain = terrainType })
			end

			if featureTypeName == "FEATURE_GIANTS_CAUSEWAY" then
				print(" - Preparing position...")
				-- 2 plots, one on coastal land and one in water, 1st plot is land, SOUTHEAST
				-- preparing the 2 plots
				bUseOnlyPlotListPlacement = true
				table.insert(plotsList, { Plot = pPlot, Terrain = g_TERRAIN_TYPE_PLAINS })
				table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_NORTHWEST), Terrain = g_TERRAIN_TYPE_COAST })
			end
			
			if featureTypeName == "FEATURE_LYSEFJORDEN"then
				print(" - Preparing position...")
				-- 3 plots, flat grass near coast, 1st plot is EAST
				-- preparing the 3 plots
				local terrainType = g_TERRAIN_TYPE_GRASS
				table.insert(plotsList, { Plot = pPlot, Terrain = terrainType })
				table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_SOUTHWEST), Terrain = terrainType })
				table.insert(plotsList, { Plot = Map.GetAdjacentPlot(x, y, DirectionTypes.DIRECTION_WEST), Terrain = terrainType })
			end
			
			-- Set terrain, remove features and resources for Civ6 NW
			for k, data in ipairs(plotsList) do 
				TerrainBuilder.SetTerrainType(data.Plot, data.Terrain)
				TerrainBuilder.SetFeatureType(data.Plot, -1)
				ResourceBuilder.SetResourceType(data.Plot, -1)
				table.insert(plotsIndex, data.Plot:GetIndex())
			end	

			 -- now handling custom multiplots NW (terrain type and removing features/resources has already been handled for those)
			if #plotsList == 0 and DirectPlacementPlots[eFeatureType] then -- plotsList is empty at this point for custom NW
				plotsIndex = DirectPlacementPlots[eFeatureType]
				bUseOnlyPlotListPlacement = true
			end
			
			if not(TerrainBuilder.CanHaveFeature(pPlot, eFeatureType)) then			
				print("  - WARNING : TerrainBuilder.CanHaveFeature says that we can't place that feature here...")
			end		
			
			if not bUseOnlyPlotListPlacement then
				print("  - Trying Direct Placement...")
				TerrainBuilder.SetFeatureType(pPlot, eFeatureType);
			end
			local bPlaced = pPlot:IsNaturalWonder()
				
			if (not bPlaced) and (#plotsIndex > 0) then
				print("  - Direct Placement has failed, using plot list for placement")
				TerrainBuilder.SetMultiPlotFeatureType(plotsIndex, eFeatureType)
				bPlaced = pPlot:IsNaturalWonder()
			end
			
			if bPlaced then
				ResetTerrain(pPlot:GetIndex())
				ResourceBuilder.SetResourceType(pPlot, -1)

				local plotX = pPlot:GetX()
				local plotY = pPlot:GetY()

				for dx = -2, 2 do
					for dy = -2,2 do
						local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 2)
						if(otherPlot) then
							if(otherPlot:IsNaturalWonder() == true) then
								ResetTerrain(otherPlot:GetIndex())
								ResourceBuilder.SetResourceType(otherPlot, -1)
							end
						end
					end
				end
				print ("  - Success : plot is now a natural wonder !")
			else
				print ("  - Failed to place natural wonder here...")		
			end
		else
			print ("  - WARNING : Can't find "..tostring().." in Features tables")
		end
	end
end

function AddFeatures()
	print("---------------")
	print("Adding Features")

	-- Get Rainfall setting input by user.
	local rainfall = MapConfiguration.GetValue("rainfall");
	if rainfall == 4 then
		rainfall = 1 + TerrainBuilder.GetRandomNumber(3, "Random Rainfall - Lua");
	end
	
	local iEquatorAdjustment = MapConfiguration.GetValue("EquatorAdjustment") or 0
	print("Equator Adjustment = "..tostring(iEquatorAdjustment))
	
	local iJunglePercent = MapConfiguration.GetValue("JunglePercent") or 12
	print("Jungle Percent = "..tostring(iJunglePercent))
	
	local iForestPercent = MapConfiguration.GetValue("ForestPercent") or 18
	print("Forest Percent = "..tostring(iForestPercent)) 
	
	local iMarshPercent = MapConfiguration.GetValue("MarshPercent") or 3
	print("Marsh Percent = "..tostring(iMarshPercent)) 
	
	local iOasisPercent = MapConfiguration.GetValue("OasisPercent") or 1
	print("Oasis Percent = "..tostring(iOasisPercent)) 

	
	local args = {rainfall = rainfall, iEquatorAdjustment = iEquatorAdjustment, iJunglePercent = iJunglePercent, iForestPercent = iForestPercent, iMarshPercent = iMarshPercent, iOasisPercent = iOasisPercent }
	local featuregen = FeatureGenerator.Create(args);

	featuregen:AddFeatures();
end

function ExtraPlacement()

	print("-------------------------------")
	print("Checking for extra placement...")
	
	for row in GameInfo.ExtraPlacement() do
		if row.MapName == mapName  then
			local bDoPlacement = false
			if row.ConfigurationId then
				-- check if this setting is selected
				local value = MapConfiguration.GetValue(row.ConfigurationId)				
				if value == true or value == row.ConfigurationValue then
					bDoPlacement = true
				end			
			else
				-- no specific rules, always place
				bDoPlacement = true
			end
			
			-- The placement may be conditionned by a specific Civilization in game
			if row.Civilization then			
				if not isInGame[row.Civilization] then
					bDoPlacement = false
				end
			end
			
			if bDoPlacement then
				local terrainType = row.TerrainType
				local featureType = row.FeatureType
				local resourceType = row.ResourceType
				local quantity = row.Quantity
				local x = row.X
				local y = row.Y
				local plot = Map.GetPlot(x,y)
				
				if plot then
					ResourceBuilder.SetResourceType(plot, -1) -- remove previous resource if any
					if terrainType and GameInfo.Terrains[terrainType] then
						print("- Trying to place ".. tostring(terrainType).. " at " .. tostring(x) ..",".. tostring(y))
						TerrainBuilder.SetTerrainType(plot, GameInfo.Terrains[terrainType].Index)
					end
					if featureType and GameInfo.Features[featureType] then
						print("- Trying to place ".. tostring(featureType).. " at " .. tostring(x) ..",".. tostring(y))
						TerrainBuilder.SetFeatureType(plot, GameInfo.Features[featureType].Index)
					end
					if resourceType and GameInfo.Resources[resourceType] then
						print("- Trying to place ".. tostring(resourceType).. " at " .. tostring(x) ..",".. tostring(y))
						local num = quantity or 1
						ResourceBuilder.SetResourceType(plot, GameInfo.Resources[resourceType].Index, num)
					end
				else
					print("- WARNING, plot is nil at " .. tostring(x) ..",".. tostring(y))
				end
			end		
		end
	end
end

function MakeRiverFlowToNorth(plot)
	if plot then
		if plot:IsNEOfRiver() then TerrainBuilder.SetNEOfRiver(plot, true, FlowDirectionTypes.FLOWDIRECTION_NORTHWEST) end
		if plot:IsWOfRiver() then TerrainBuilder.SetWOfRiver(plot, true, FlowDirectionTypes.FLOWDIRECTION_NORTH) end
		if plot:IsNWOfRiver() then TerrainBuilder.SetNWOfRiver(plot, true, FlowDirectionTypes.FLOWDIRECTION_NORTHEAST) end
	end
end

function MakeRiverFlowToEast(plot)
	if plot then
		if plot:IsNEOfRiver() then TerrainBuilder.SetNEOfRiver(plot, true, FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST) end
		if plot:IsWOfRiver() then TerrainBuilder.SetWOfRiver(plot, true, FlowDirectionTypes.FLOWDIRECTION_NORTH) end
		if plot:IsNWOfRiver() then TerrainBuilder.SetNWOfRiver(plot, true, FlowDirectionTypes.FLOWDIRECTION_NORTHEAST) end
	end
end

------------------------------------------------------------------------------
-- Resources
------------------------------------------------------------------------------
-- Add a strategic resource
function PlaceStrategicResources(eResourceType)
	
	--ResourceBuilder.SetResourceType(pPlot, eResourceType, 1)
end

function IsResourceExclusion(pPlot, eResourceType)

	if not bResourceExclusion then
		-- exlusion is not activated, so this plot can't be in an exclusion/exclusive zone...
		return false
	end	
	
	---[[
	if isResourceExclusive[eResourceType] and not isResourceExclusiveXY[pPlot:GetX()][pPlot:GetY()][eResourceType] then
		-- resource is exclusive to specific regions, and this plot is not in one of them
		--print("YnAMP_CanHaveResource(pPlot, eResourceType) isResourceExclusive", pPlot:GetX(), pPlot:GetY(), GameInfo.Resources[eResourceType].ResourceType)
		return true
	end
	--]]
	--[[
	if isResourceExclusive[eResourceType] then -- would require an argument to allow placement now that YnAMP_CanHaveResource replace ResourceBuilder.CanHaveResource
		-- those are directly placed on the map
		print("YnAMP_CanHaveResource(pPlot, eResourceType) isResourceExclusive", pPlot:GetX(), pPlot:GetY(), GameInfo.Resources[eResourceType].ResourceType)
		return false
	end
	--]]
	
	if isResourceExcludedXY[pPlot:GetX()][pPlot:GetY()][eResourceType] then
		-- this plot is in a region from which this resource is excluded		
		--print("YnAMP_CanHaveResource(pPlot, eResourceType) isResourceExcludedXY", pPlot:GetX(), pPlot:GetY(), GameInfo.Resources[eResourceType].ResourceType)
		return true
	end
	
	return false
end

-- Check for Resource placement rules
function YnAMP_CanHaveResource(pPlot, eResourceType, bOverrideExclusion)

	if bOverrideExclusion then 
		return ResourceBuilder.OldCanHaveResource(pPlot, eResourceType)
	end
	
	--[[
	if (not hasBuildExclusionList) and (eResourceType ~= -1) and bResourceExclusion then
		print("Calling YnAMP_CanHaveResource(pPlot, eResourceType) before  hasBuildExclusionList at", pPlot:GetX(), pPlot:GetY(), GameInfo.Resources[eResourceType].ResourceType)
	end	
	--]]
	
	if IsResourceExclusion(pPlot, eResourceType) then
		return false
	end
		
	-- Resource is not excluded from this plot, or this plot is allowed for a region-exclusive resources, now check normal placement rules
	return ResourceBuilder.OldCanHaveResource(pPlot, eResourceType)
end

function placeExclusiveResources()
	print("Placing Exclusive resources...")
	print("-------------------------------")	
	for row in GameInfo.ResourceRegionExclusive() do
		local region = row.Region
		local resource = row.Resource
		print ("Trying to place ".. tostring(resource) .." in "..tostring(region))
		
		local eResourceType = nil
		if GameInfo.Resources[resource] then
			eResourceType = GameInfo.Resources[resource].Index
		else
			print (" - WARNING : can't find "..tostring(resource).." in Resources")
		end	
		
		if region and eResourceType then
			placeResourceInRegion(eResourceType, region, 5, true)
		end		
	end
	print("-------------------------------")
end

function AddDeposits()
	print("Adding major deposits...")
	print("-------------------------------")	
	for DepositRow in GameInfo.ResourceRegionDeposit() do
		local region = DepositRow.Region
		local resource = DepositRow.Resource
		print ("Trying to place ".. tostring(resource) .." in "..tostring(region))
		
		local eResourceType = nil
		if GameInfo.Resources[resource] then
			eResourceType = GameInfo.Resources[resource].Index
		else
			print (" - WARNING : can't find "..tostring(resource).." in Resources")
		end	
		
		if region and eResourceType then
			placeResourceInRegion(eResourceType, region, DepositRow.Deposit)
		end		
	end
	print("-------------------------------")
end

function placeResourceInRegion(eResourceType, region, number, bNumberIsRatio)
	for Data in GameInfo.RegionPosition() do
		if Data.MapName == mapName  then
			if Data.Region == region then
				-- get possible plots table
				local plotTable = {}
				local plotCount = 0
				plotTable, plotCount = getPlotsInAreaForResource(Data.X, Data.Width, Data.Y, Data.Height, eResourceType)

				-- shuffle it
				local shuffledPlotTable = GetShuffledCopyOfTable(plotTable)
				
				-- place deposits
				local toPlace = number			
				if bNumberIsRatio then
					toPlace = math.ceil(plotCount * number / 1000) -- to do : check statistics to get a better approximation ?
				end
				local placed = math.min(toPlace, #shuffledPlotTable)
				for i = 1, placed do
					local pPlot = shuffledPlotTable[i]
					ResourceBuilder.SetResourceType(pPlot, eResourceType, 1)
				end
				--print (" - Asked for " .. toPlace .. ", placed " .. placed .. " (available plots = " .. #shuffledPlotTable .. ", total plots in region = ".. plotCount .." )" )
			end
		end
	end
end

function getPlotsInAreaForResource(iX, iWidth, iY, iHeight, eResourceType)
	local plotTable = {}
	local plotCount = 0
	for x = iX, iX + iWidth do
		for y = iY, iY + iHeight do
			local pPlot = Map.GetPlot(x,y)
			if pPlot then
				plotCount = plotCount + 1
				local bOverrideExclusion = true -- we want to place Civ specific resources even in excluded region
				if ResourceBuilder.CanHaveResource(pPlot, eResourceType, bOverrideExclusion) then
					table.insert ( plotTable, pPlot )
				end
			end
		end
	end
	return plotTable, plotCount
end

-- add civ's specific resources
function AddStartingLocationResources()

	print("-----------------------------------------")
	print("-- Adding requested resources for civs...")
	print("-----------------------------------------")
		
	for _, player_ID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do

		-- creating player lists
		local player = Players[player_ID]
		local playerConfig = PlayerConfigurations[player_ID]
		local civilization = playerConfig:GetCivilizationTypeName()
		--print ("Searching Resources for ".. tostring(civilization))
		
		local startPlot = player:GetStartingPlot()
		if startPlot then

			local startX = startPlot:GetX()
			local startY = startPlot:GetY()
			for row in GameInfo.CivilizationRequestedResource() do
				if row.Civilization == civilization then
					
					local resource = row.Resource
					--print ("  - Trying to place ".. tostring(resource))
					
					local eResourceType = nil
					if GameInfo.Resources[resource] then
						eResourceType = GameInfo.Resources[resource].Index
					else
						print (" - WARNING : can't find "..tostring(resource).." in Resources")
					end
					
					if eResourceType then
						-- to do : use rings
						-- first pass, search in range = 2
						local plotTable = {}
						local plotCount = 0
						plotTable, plotCount = getPlotsInAreaForResource(startX - 2, 4, startY - 2, 4, eResourceType)
						
						-- do a second pass if needed, search in range = 4
						if #plotTable == 0 then
							--print ("  - no result on first pass, trying a larger search...")
							plotTable, plotCount = getPlotsInAreaForResource(startX - 4, 8, startY - 4, 8, eResourceType)
						end
						
						if #plotTable > 0 then
							local random_index = 1 + TerrainBuilder.GetRandomNumber(#plotTable, "YnAMP - Placing requested resources")
							local pPlot = plotTable[random_index]
							ResourceBuilder.SetResourceType(pPlot, eResourceType, 1)
							--print ("  - Resource placed !")
						else
							--print ("  - Failed on second pass...")
						end
					end
				end
			end
		end
	end
	print("-------------------------------")
end


function ResourcesValidation(g_iW, g_iH)

	-- replacement tables
	local resTable 		= {}
	local luxTable 		= {}
	local foodTable 	= {}
	local prodTable 	= {}
	local stratTable 	= {}
	local goldTable		= {}
	for resRow in GameInfo.Resources() do
		resTable[resRow.Index] = 0
		if resRow.ResourceClassType == "RESOURCECLASS_LUXURY" then
			luxTable[resRow.Index] = true
		elseif resRow.ResourceClassType == "RESOURCECLASS_STRATEGIC" then
			stratTable[resRow.Index] = true
		end
	end	
	
	for resRow in GameInfo.Resource_YieldChanges() do
		local index = GameInfo.Resources[resRow.ResourceType].Index
		if not (luxTable[index] or stratTable[index]) then
			if resRow.YieldType == "YIELD_FOOD" then
				foodTable[index] = resRow.YieldChange
			elseif resRow.YieldType == "YIELD_PRODUCTION" then
				prodTable[index] = resRow.YieldChange
			elseif resRow.YieldType == "YIELD_GOLD" then
				goldTable[index] = resRow.YieldChange
			end
		end
	end
	
	function FindReplacement(eResourceType, plot)
		local listTable = {luxTable, stratTable, foodTable, prodTable, goldTable}
		for _, curTable in ipairs(listTable) do
			if curTable[eResourceType] then
				for newResourceType, value in pairs (curTable) do
					if newResourceType ~= eResourceType and YnAMP_CanHaveResource(plot, newResourceType) then
						--print(" - Found replacement resource for", GameInfo.Resources[eResourceType].ResourceType, "at", plot:GetX(), plot:GetY(), "by resource", GameInfo.Resources[newResourceType].ResourceType)
						return newResourceType						
					end
				end
			end
		end	
	end
		
	local totalplots = g_iW * g_iH
	for i = 0, (totalplots) - 1, 1 do
		plot = Map.GetPlotByIndex(i)
		local eResourceType = plot:GetResourceType()
		if (eResourceType ~= -1) then
			if resTable[eResourceType] then
				if not bImportResources and IsResourceExclusion(plot, eResourceType) then
					--print("WARNING - Removing unauthorised resource at", plot:GetX(), plot:GetY(), GameInfo.Resources[eResourceType].ResourceType)
					ResourceBuilder.SetResourceType(plot, -1)
					-- find replacement
					local newResourceType = FindReplacement(eResourceType, plot)
					if newResourceType then
						ResourceBuilder.SetResourceType(plot, newResourceType, 1)
						resTable[newResourceType] = resTable[newResourceType] + 1
					end					
				else
					resTable[eResourceType] = resTable[eResourceType] + 1
				end
			else
				print("WARNING - resTable[eResourceType] is nil for eResourceType = " .. tostring(eResourceType))
			end
		end
	end

	print("------------------------------------")
	print("-- Resources Placement Statistics --")
	print("------------------------------------")
	print("-- Total plots on map = " .. tostring(totalplots))
	print("------------------------------------")

	local landPlots 		= Map.GetLandPlotCount()
	local missingLuxuries 	= {}
	local missingStrategics	= {}
	for resRow in GameInfo.Resources() do
		local numRes = resTable[resRow.Index]
		local placedPercent	= Round(numRes / landPlots * 10000) / 100
		if placedPercent == 0 then placedPercent = "0.00" end
		local ratio = Round(placedPercent * 100 / resRow.Frequency)
		if ratio == 0 then ratio = "0.00" end
		if resRow.Frequency > 0 then
			local sFrequency = tostring(resRow.Frequency)
			if resRow.Frequency < 10 then sFrequency = " "..sFrequency end
			print("Resource = " .. tostring(resRow.ResourceType).."		placed = " .. tostring(numRes).."		(" .. tostring(placedPercent).."% of land)		frequency = " .. sFrequency.."		ratio = " .. tostring(ratio))
			if numRes == 0 then
				if luxTable[resRow.Index] and bPlaceAllLuxuries then
					table.insert(missingLuxuries, resRow.Index)
				end
				if stratTable[resRow.Index] then
					table.insert(missingStrategics, resRow.Index)
				end
				
			end
		end
	end
	
	if bPlaceAllLuxuries and #missingLuxuries > 0 then
		PlaceMissingResources(missingLuxuries)
	end
	
	if #missingStrategics > 0 then
		PlaceMissingResources(missingStrategics)
	end

	print("------------------------------------")
end

function PlaceMissingResources(missingResourceTable)
	print("Placing missing resources...")
	local g_iW, g_iH 	= Map.GetGridSize()
	for _, resourceType in ipairs(missingResourceTable) do
		local row = GameInfo.Resources[resourceType]
		local possiblePlots = {}
		for x = 0, g_iW - 1 do 
			for y = 0, g_iH - 1 do
				local plotID = (y * g_iW) + x
				local plot = Map.GetPlotByIndex(plotID)
				if YnAMP_CanHaveResource(plot, resourceType) then
					table.insert(possiblePlots, plot)					
				end
			end
		end		
		
		-- The code below gives a result close to standard numbers, for precise number, we'll have to include parts of ResourceGenerator.lua here, or include this to the core of ResourceGenerator.lua
		local iMagicFrequency = 14
		local toPlace = math.max(1, Round(#possiblePlots * (iMagicFrequency / 100) * (row.Frequency / 100)))
		
		print("Trying to place ".. tostring(toPlace).." " .. tostring(row.ResourceType))
		aShuffledResourcePlots = GetShuffledCopyOfTable(possiblePlots)
		for i = 1, toPlace do
			local plot = aShuffledResourcePlots[i]
			ResourceBuilder.SetResourceType(plot, resourceType, 1)
		end
	end
end

-----------------
-- ENUM 
-----------------

-- ResourceType Civ5
--[[
	[0]	 = RESOURCE_IRON
	[1]	 = RESOURCE_HORSE
	[2]	 = RESOURCE_COAL
	[3]	 = RESOURCE_OIL
	[4]	 = RESOURCE_ALUMINUM
	[5]	 = RESOURCE_URANIUM
	[6]	 = RESOURCE_WHEAT
	[7]	 = RESOURCE_COW
	[8]	 = RESOURCE_SHEEP
	[9]	 = RESOURCE_DEER
	[10] = RESOURCE_BANANA
	[11] = RESOURCE_FISH
	[12] = RESOURCE_STONE
	[13] = RESOURCE_WHALE
	[14] = RESOURCE_PEARLS
	[15] = RESOURCE_GOLD
	[16] = RESOURCE_SILVER
	[17] = RESOURCE_GEMS
	[18] = RESOURCE_MARBLE
	[19] = RESOURCE_IVORY
	[20] = RESOURCE_FUR
	[21] = RESOURCE_DYE
	[22] = RESOURCE_SPICES
	[23] = RESOURCE_SILK
	[24] = RESOURCE_SUGAR
	[25] = RESOURCE_COTTON
	[26] = RESOURCE_WINE
	[27] = RESOURCE_INCENSE
	[28] = RESOURCE_JEWELRY
	[29] = RESOURCE_PORCELAIN
	[30] = RESOURCE_COPPER
	[31] = RESOURCE_SALT
	[32] = RESOURCE_CRAB
	[33] = RESOURCE_TRUFFLES
	[34] = RESOURCE_CITRUS
	[40] = RESOURCE_BISON
	[41] = RESOURCE_COCOA
--]]
-- ResourceType Civ6
--[[
	[0]	 = RESOURCE_BANANAS
	[1]	 = RESOURCE_CATTLE
	[2]	 = RESOURCE_COPPER
	[3]	 = RESOURCE_CRABS
	[4]	 = RESOURCE_DEER
	[5]	 = RESOURCE_FISH
	[6]	 = RESOURCE_RICE
	[7]	 = RESOURCE_SHEEP
	[8]	 = RESOURCE_STONE
	[9]	 = RESOURCE_WHEAT
	[10] = RESOURCE_CITRUS
	[11] = RESOURCE_COCOA
	[12] = RESOURCE_COFFEE
	[13] = RESOURCE_COTTON
	[14] = RESOURCE_DIAMONDS
	[15] = RESOURCE_DYES
	[16] = RESOURCE_FURS
	[17] = RESOURCE_GYPSUM
	[18] = RESOURCE_INCENSE
	[19] = RESOURCE_IVORY
	[20] = RESOURCE_JADE
	[21] = RESOURCE_MARBLE
	[22] = RESOURCE_MERCURY
	[23] = RESOURCE_PEARLS
	[24] = RESOURCE_SALT
	[25] = RESOURCE_SILK
	[26] = RESOURCE_SILVER
	[27] = RESOURCE_SPICES
	[28] = RESOURCE_SUGAR
	[29] = RESOURCE_TEA
	[30] = RESOURCE_TOBACCO
	[31] = RESOURCE_TRUFFLES
	[32] = RESOURCE_WHALES
	[33] = RESOURCE_WINE
	[40] = RESOURCE_ALUMINUM
	[41] = RESOURCE_COAL
	[42] = RESOURCE_HORSES
	[43] = RESOURCE_IRON
	[44] = RESOURCE_NITER
	[45] = RESOURCE_OIL
	[46] = RESOURCE_URANIUM
--]]
-- FeaturesType Civ5
--[[
	[0]  = FEATURE_ICE			----> 1
	[1]  = FEATURE_JUNGLE		----> 2
	[2]  = FEATURE_MARSH		----> 5
	[3]  = FEATURE_OASIS		----> 4
	[4]  = FEATURE_FLOOD_PLAINS	----> 0
	[5]  = FEATURE_FOREST		----> 3
	[6]  = FEATURE_FALLOUT
	[7]  = FEATURE_CRATER
	[8]  = FEATURE_FUJI
	[9]  = FEATURE_MESA
	[10] = FEATURE_REEF			----> 6
	[11] = FEATURE_VOLCANO
	[12] = FEATURE_GIBRALTAR
	[13] = FEATURE_GEYSER
	[14] = FEATURE_FOUNTAIN_YOUTH
	[15] = FEATURE_POTOSI
	[16] = FEATURE_EL_DORADO
	[17] = FEATURE_ATOLL
	[18] = FEATURE_SRI_PADA
	[19] = FEATURE_MT_SINAI
	[20] = FEATURE_MT_KAILASH
	[21] = FEATURE_ULURU
	[22] = FEATURE_LAKE_VICTORIA
	[23] = FEATURE_KILIMANJARO	----> 12
	[24] = FEATURE_SOLOMONS_MINES	
--]]
-- FeaturesType Civ6
--[[
[0]  = FEATURE_FLOODPLAINS
[1]  = FEATURE_ICE
[2]  = FEATURE_JUNGLE
[3]  = FEATURE_FOREST
[4]  = FEATURE_OASIS
[5]  = FEATURE_MARSH
[6]  = FEATURE_BARRIER_REEF
[7]  = FEATURE_CLIFFS_DOVER
[8]  = FEATURE_CRATER_LAKE
[9]  = FEATURE_DEAD_SEA
[10] = FEATURE_EVEREST
[11] = FEATURE_GALAPAGOS
[12] = FEATURE_KILIMANJARO
[13] = FEATURE_PANTANAL
[14] = FEATURE_PIOPIOTAHI
[15] = FEATURE_TORRES_DEL_PAINE
[16] = FEATURE_TSINGY
[17] = FEATURE_YOSEMITE
--]]
-- PlotType Civ5
--[[
	[0] =	PLOT_MOUNTAIN		
	[1] =	PLOT_HILLS		
	[2] =	PLOT_LAND		
	[3] =	PLOT_OCEAN
--]]	
-- TerrainTypes Civ5
--[[
	[0] = TERRAIN_GRASS, 
	[1] = TERRAIN_PLAINS,
	[2] = TERRAIN_DESERT,
	[3] = TERRAIN_TUNDRA,
	[4] = TERRAIN_SNOW,
	[5] = TERRAIN_COAST,
	[6] = TERRAIN_OCEAN,
--]]
-- Continental Art Set Civ5
--[[
	[0] = Ocean
	[1] = America
	[2] = Asia
	[3] = Africa
	[4] = Europe
--]]
-- Rivers (same for civ6)
--[[	
	
	[0] = FLOWDIRECTION_NORTH
	[1] = FLOWDIRECTION_NORTHEAST
	[2] = FLOWDIRECTION_SOUTHEAST
	[3] = FLOWDIRECTION_SOUTH
	[4] = FLOWDIRECTION_SOUTHWEST
	[5] = FLOWDIRECTION_NORTHWEST
	
	Directions (same for civ6)
	[0] = DIRECTION_NORTHEAST	
	[1] = DIRECTION_EAST
	[2] = DIRECTION_SOUTHEAST
	[3] = DIRECTION_SOUTHWEST
	[4] = DIRECTION_WEST		
	[5] = DIRECTION_NORTHWEST
--]]	
-- Code to export a civ5 map
--[[
	for iPlotLoop = 0, Map.GetNumPlots()-1, 1 do
		local plot = Map.GetPlotByIndex(iPlotLoop)
		local NEOfRiver = 0
		local WOfRiver = 0
		local NWOfRiver = 0
		if plot:IsNEOfRiver() then NEOfRiver = 1 end -- GetRiverSWFlowDirection()
		if plot:IsWOfRiver() then WOfRiver = 1 end -- GetRiverEFlowDirection()
		if plot:IsNWOfRiver() then NWOfRiver = 1 end -- GetRiverSEFlowDirection()
		print("MapToConvert["..plot:GetX().."]["..plot:GetY().."]={"..plot:GetTerrainType()..","..plot:GetPlotType()..","..plot:GetFeatureType()..","..plot:GetContinentArtType()..",{{"..NEOfRiver..","..plot:GetRiverSWFlowDirection().. "},{"..WOfRiver..","..plot:GetRiverEFlowDirection().."},{"..NWOfRiver..","..plot:GetRiverSEFlowDirection().."}},{"..plot:GetResourceType(-1)..","..plot:GetNumResource().."}}")
	end
--]]
-- Code to export a civ6 cliffs map
--[[
	local iPlotCount = Map.GetPlotCount();
	for iPlotLoop = 0, iPlotCount-1, 1 do
		local bData = false
		local plot = Map.GetPlotByIndex(iPlotLoop)
		local NEOfCliff = 0
		local WOfCliff = 0
		local NWOfCliff = 0
		if plot:IsNEOfCliff() then NEOfCliff = 1 end 
		if plot:IsWOfCliff() then WOfCliff = 1 end 
		if plot:IsNWOfCliff() then NWOfCliff = 1 end 
		
		bData = NEOfCliff + WOfCliff + NWOfCliff > 0
		if bData then
			print("Civ6DataToConvert["..plot:GetX().."]["..plot:GetY().."]={{"..NEOfCliff..","..WOfCliff..","..NWOfCliff.."},}")
		end
	end
--]]

-- Code to export a civ6 complete map
--[[
	local iPlotCount = Map.GetPlotCount();
	for iPlotLoop = 0, iPlotCount-1, 1 do
		local bData = false
		local plot = Map.GetPlotByIndex(iPlotLoop)
		local NEOfCliff = 0
		local WOfCliff = 0
		local NWOfCliff = 0
		if plot:IsNEOfCliff() then NEOfCliff = 1 end 
		if plot:IsWOfCliff() then WOfCliff = 1 end 
		if plot:IsNWOfCliff() then NWOfCliff = 1 end 
		local NEOfRiver = 0
		local WOfRiver = 0
		local NWOfRiver = 0
		if plot:IsNEOfRiver() then NEOfRiver = 1 end -- GetRiverSWFlowDirection()
		if plot:IsWOfRiver() then WOfRiver = 1 end -- GetRiverEFlowDirection()
		if plot:IsNWOfRiver() then NWOfRiver = 1 end -- GetRiverSEFlowDirection()
		print("MapToConvert["..plot:GetX().."]["..plot:GetY().."]={"..plot:GetTerrainType()..","..plot:GetFeatureType()..","..plot:GetContinentType()..",{{"..NEOfRiver..","..plot:GetRiverSWFlowDirection().. "},{"..WOfRiver..","..plot:GetRiverEFlowDirection().."},{"..NWOfRiver..","..plot:GetRiverSEFlowDirection().."}},{"..plot:GetResourceType(-1)..","..tostring(1).."},{"..NEOfCliff..","..WOfCliff..","..NWOfCliff.."}}")
	end
--]]

function ImportCiv5Map(MapToConvert, Civ6DataToConvert, g_iW, g_iH, bDoTerrains, bImportRivers, bImportFeatures, bImportResources, bDoCliffs, bImportContinents)
	print("Importing Civ5 Map ( Terrain = "..tostring(bDoTerrains)..", Rivers = "..tostring(bImportRivers)..", Features = "..tostring(bImportFeatures)..", Resources = "..tostring(bImportResources)..", Cliffs = "..tostring(bDoCliffs)..", Continents = "..tostring(bImportContinents)..")")
	local count = 0
	
	-- Civ5 ENUM
	PLOT_MOUNTAIN = 0
	PLOT_HILLS = 1
	
	-- Civ5 to Civ6 
	local FeaturesCiv5toCiv6 = {}
	for i = 0, 24 do FeaturesCiv5toCiv6[i] = g_FEATURE_NONE end
	FeaturesCiv5toCiv6[0]  = g_FEATURE_ICE
	FeaturesCiv5toCiv6[1]  = g_FEATURE_JUNGLE
	FeaturesCiv5toCiv6[2]  = g_FEATURE_MARSH
	FeaturesCiv5toCiv6[3]  = g_FEATURE_OASIS
	FeaturesCiv5toCiv6[4]  = g_FEATURE_FLOODPLAINS
	FeaturesCiv5toCiv6[5]  = g_FEATURE_FOREST
	-- Natural wonders require a special coding
	
	local ResourceCiv5toCiv6 = {}
	for i = 0, 41 do ResourceCiv5toCiv6[i] = -1 end
	ResourceCiv5toCiv6[4]	= 40 	-- ALUMINUM
	ResourceCiv5toCiv6[10]	= 0 	-- BANANAS
	ResourceCiv5toCiv6[40]	= 16 	-- BISON to FURS
	ResourceCiv5toCiv6[7]	= 1 	-- CATTLE
	ResourceCiv5toCiv6[34]	= 10 	-- CITRUS
	ResourceCiv5toCiv6[2]	= 41 	-- COAL
	ResourceCiv5toCiv6[41]	= 11 	-- COCOA
	ResourceCiv5toCiv6[30]	= 2 	-- COPPER
	ResourceCiv5toCiv6[25]	= 13 	-- COTTON
	ResourceCiv5toCiv6[32]	= 3 	-- CRABS
	ResourceCiv5toCiv6[9]	= 4 	-- DEER
	ResourceCiv5toCiv6[17]	= 14 	-- DIAMONDS
	ResourceCiv5toCiv6[21]	= 15 	-- DYES
	ResourceCiv5toCiv6[11]	= 5 	-- FISH
	ResourceCiv5toCiv6[20]	= 16 	-- FURS
	ResourceCiv5toCiv6[15]	= 26 	-- GOLD to SILVER
	ResourceCiv5toCiv6[1]	= 42 	-- HORSES
	ResourceCiv5toCiv6[27]	= 18 	-- INCENSE
	ResourceCiv5toCiv6[0]	= 43 	-- IRON
	ResourceCiv5toCiv6[19]	= 19 	-- IVORY
	ResourceCiv5toCiv6[28]	= 20 	-- JEWELRY to JADE
	ResourceCiv5toCiv6[18]	= 21 	-- MARBLE
	ResourceCiv5toCiv6[3]	= 45 	-- OIL
	ResourceCiv5toCiv6[14]	= 23 	-- PEARLS
	ResourceCiv5toCiv6[31]	= 24 	-- SALT
	ResourceCiv5toCiv6[8]	= 7		-- SHEEP
	ResourceCiv5toCiv6[23]	= 25 	-- SILK
	ResourceCiv5toCiv6[16]	= 26 	-- SILVER
	ResourceCiv5toCiv6[22]	= 27 	-- SPICES
	ResourceCiv5toCiv6[12]	= 8 	-- STONE
	ResourceCiv5toCiv6[24]	= 28 	-- SUGAR
	ResourceCiv5toCiv6[33]	= 31 	-- TRUFFLES
	ResourceCiv5toCiv6[5]	= 46 	-- URANIUM
	ResourceCiv5toCiv6[13]	= 32 	-- WHALES
	ResourceCiv5toCiv6[6]	= 9 	-- WHEAT
	ResourceCiv5toCiv6[26]	= 33 	-- WINE
	
	local ContinentsCiv5toCiv6 = {}
	for i = 0, 4 do ContinentsCiv5toCiv6[i] = 0 end
	ContinentsCiv5toCiv6[0]  = -1
	ContinentsCiv5toCiv6[1]  = GameInfo.Continents["CONTINENT_AMERICA"].Index
	ContinentsCiv5toCiv6[2]  = GameInfo.Continents["CONTINENT_ASIA"].Index
	ContinentsCiv5toCiv6[3]  = GameInfo.Continents["CONTINENT_AFRICA"].Index
	ContinentsCiv5toCiv6[4]  = GameInfo.Continents["CONTINENT_EUROPE"].Index
	
	bOutput = false
	for i = 0, (g_iW * g_iH) - 1, 1 do
		plot = Map.GetPlotByIndex(i)
		if bOutput then
			print("----------")
			print("Convert plot at "..plot:GetX()..","..plot:GetY())
		end
		-- Map Data
		-- MapToConvert[x][y] = {civ5TerrainType, civ5PlotTypes, civ5FeatureTypes, civ5ContinentType, {{IsNEOfRiver, flow}, {IsWOfRiver, flow}, {IsNWOfRiver, flow}}, {Civ5ResourceType, num} }
		local civ5TerrainType = MapToConvert[plot:GetX()][plot:GetY()][1]
		local civ5PlotTypes = MapToConvert[plot:GetX()][plot:GetY()][2]
		local civ5FeatureTypes = MapToConvert[plot:GetX()][plot:GetY()][3]
		local civ5ContinentType = MapToConvert[plot:GetX()][plot:GetY()][4]
		local Rivers = MapToConvert[plot:GetX()][plot:GetY()][5] -- = {{IsNEOfRiver, flow}, {IsWOfRiver, flow}, {IsNWOfRiver, flow}}
		local resource = MapToConvert[plot:GetX()][plot:GetY()][6] -- = {Civ5ResourceType, num}
		
		-- Get Civ6 map data exported form the internal WB
		local Cliffs
		if Civ6DataToConvert[plot:GetX()] and Civ6DataToConvert[plot:GetX()][plot:GetY()] then
			Cliffs = Civ6DataToConvert[plot:GetX()][plot:GetY()][1] -- {IsNEOfCliff,IsWOfCliff,IsNWOfCliff}
		end
		
		-- Set terrain type
		if bDoTerrains then
			local civ6TerrainType = g_TERRAIN_TYPE_OCEAN		
			if civ5TerrainType == 5 then civ6TerrainType = g_TERRAIN_TYPE_COAST
			elseif civ5TerrainType ~= 6 then
				-- the code below won't work if the order is changed in the terrains table
				-- entrie for civ5 are: 0 = GRASS, 1= PLAINS, ...
				-- entries for civ6 are: 0 = GRASS, 1= GRASS_HILL, 2 = GRASS_MOUNTAIN, 3= PLAINS, 4 = PLAINS_HILL, ...
				civ6TerrainType = civ5TerrainType * 3 -- civ5TerrainType * 3  0-0 1-3 2-6 3-9 4-12
				if civ5PlotTypes == PLOT_HILLS then 
					civ6TerrainType = civ6TerrainType + g_TERRAIN_BASE_TO_HILLS_DELTA
				elseif civ5PlotTypes == PLOT_MOUNTAIN then
					civ6TerrainType = civ6TerrainType + g_TERRAIN_BASE_TO_MOUNTAIN_DELTA
				end
			end
			if bOutput then print(" - Set Terrain Type = "..tostring(GameInfo.Terrains[civ6TerrainType].TerrainType)) end
			count = count + 1
			TerrainBuilder.SetTerrainType(plot, civ6TerrainType)
		end
		
		-- Set Rivers
		if bImportRivers then
			if Rivers[1][1] == 1 then -- IsNEOfRiver
				TerrainBuilder.SetNEOfRiver(plot, true, Rivers[1][2])
				if bOutput then print(" - Set is NE of River, flow = "..tostring(Rivers[1][2])) end
			end
			if Rivers[2][1] == 1 then -- IsWOfRiver
				TerrainBuilder.SetWOfRiver(plot, true, Rivers[2][2])
				if bOutput then print(" - Set is W of River, flow = "..tostring(Rivers[2][2])) end
			end
			if Rivers[3][1] == 1 then -- IsNWOfRiver
				TerrainBuilder.SetNWOfRiver(plot, true, Rivers[3][2])
				if bOutput then print(" - Set is NW of River, flow = "..tostring(Rivers[3][2])) end
			end
		end
		
		-- Set Features
		if bImportFeatures then
			if civ5FeatureTypes ~= -1 and FeaturesCiv5toCiv6[civ5FeatureTypes] ~= g_FEATURE_NONE then		
				if bOutput then print(" - Set Feature Type = "..tostring(GameInfo.Features[FeaturesCiv5toCiv6[civ5FeatureTypes]].FeatureType)) end
				TerrainBuilder.SetFeatureType(plot, FeaturesCiv5toCiv6[civ5FeatureTypes])
			end
		end
		
		-- Set Continent
		if bImportContinents then
			if civ5ContinentType ~= 0 and ContinentsCiv5toCiv6[civ5ContinentType] ~= -1 then		
				if bOutput then print(" - Set Continent Type = "..tostring(GameInfo.Continents[ContinentsCiv5toCiv6[civ5ContinentType]].ContinentType)) end
				TerrainBuilder.SetContinentType(plot, ContinentsCiv5toCiv6[civ5ContinentType])
			end
		end
		
		-- Set Resources
		if bImportResources and not plot:IsNaturalWonder() and resource[1] ~= -1 then
			local Civ6ResourceType = ResourceCiv5toCiv6[resource[1]]
			if Civ6ResourceType ~= -1 then		
				if bOutput then print(" - Set Resource Type = "..tostring(GameInfo.Resources[Civ6ResourceType].ResourceType)) end
				--ResourceBuilder.SetResourceType(plot, ResourceCiv5toCiv6[resource[1]], resource[2]) -- maybe an option to import number of resources on one plot even if civ6 use 1 ?
				if(ResourceBuilder.CanHaveResource(plot, Civ6ResourceType)) then
					ResourceBuilder.SetResourceType(plot, Civ6ResourceType, 1)
				else
					print(" - WARNING : ResourceBuilder.CanHaveResource says that "..tostring(GameInfo.Resources[Civ6ResourceType].ResourceType).." can't be placed at "..plot:GetX()..","..plot:GetY())
				end
			end
		end
		
		-- Set Cliffs
		if bDoCliffs and Cliffs then
			if Cliffs[1] == 1 then -- IsNEOfCliff
				TerrainBuilder.SetNEOfCliff(plot, true)
				if bOutput then print(" - Set is NE of Cliff") end
			end
			if Cliffs[2] == 1 then -- IsWOfCliff
				TerrainBuilder.SetWOfCliff(plot, true)
				if bOutput then print(" - Set is W of Cliff") end
			end
			if Cliffs[3] == 1 then -- IsNWOfCliff
				TerrainBuilder.SetNWOfCliff(plot, true)
				if bOutput then print(" - Set is NW of Cliff") end
			end	
		end
		
	end	
	
	print("Placed terrain on "..tostring(count) .. " tiles")
end


function ImportCiv6Map(MapToConvert, g_iW, g_iH, bDoTerrains, bImportRivers, bImportFeatures, bImportResources, bImportContinents, bIgnoreCliffs)
	print("Importing Civ6 Map ( Terrain = "..tostring(bDoTerrains)..", Rivers = "..tostring(bImportRivers)..", Features = "..tostring(bImportFeatures)..", Resources = "..tostring(bImportResources)..", Continents = "..tostring(bImportContinents)..")")
	local count = 0
		
	bOutput = false
	for i = 0, (g_iW * g_iH) - 1, 1 do
		plot = Map.GetPlotByIndex(i)
		if bOutput then
			print("----------")
			print("Convert plot at "..plot:GetX()..","..plot:GetY())
		end
		-- Map Data
		-- MapToConvert[x][y] = {civ6TerrainType, civ6FeatureType, civ6ContinentType, {{IsNEOfRiver, flow}, {IsWOfRiver, flow}, {IsNWOfRiver, flow}}, {Civ6ResourceType, num} }
		local civ6TerrainType = MapToConvert[plot:GetX()][plot:GetY()][1]
		local civ6FeatureType = MapToConvert[plot:GetX()][plot:GetY()][2]
		local civ6ContinentType = MapToConvert[plot:GetX()][plot:GetY()][3]
		local Rivers = MapToConvert[plot:GetX()][plot:GetY()][4] -- = {{IsNEOfRiver, flow}, {IsWOfRiver, flow}, {IsNWOfRiver, flow}}
		local resource = MapToConvert[plot:GetX()][plot:GetY()][5] -- = {Civ6ResourceType, num}
		local Cliffs =  MapToConvert[plot:GetX()][plot:GetY()][6] -- {IsNEOfCliff,IsWOfCliff,IsNWOfCliff}
		
		-- Set terrain type
		if bDoTerrains then
			if bOutput then print(" - Set Terrain Type = "..tostring(GameInfo.Terrains[civ6TerrainType].TerrainType)) end
			count = count + 1
			TerrainBuilder.SetTerrainType(plot, civ6TerrainType)
		end
		
		-- Set Rivers
		if bImportRivers then
			if Rivers[1][1] == 1 then -- IsNEOfRiver
				TerrainBuilder.SetNEOfRiver(plot, true, Rivers[1][2])
				if bOutput then print(" - Set is NE of River, flow = "..tostring(Rivers[1][2])) end
			end
			if Rivers[2][1] == 1 then -- IsWOfRiver
				TerrainBuilder.SetWOfRiver(plot, true, Rivers[2][2])
				if bOutput then print(" - Set is W of River, flow = "..tostring(Rivers[2][2])) end
			end
			if Rivers[3][1] == 1 then -- IsNWOfRiver
				TerrainBuilder.SetNWOfRiver(plot, true, Rivers[3][2])
				if bOutput then print(" - Set is NW of River, flow = "..tostring(Rivers[3][2])) end
			end
		end
		
		-- Set Features
		if bImportFeatures then
			if civ6FeatureType ~= g_FEATURE_NONE and civ6FeatureType < GameInfo.Features["FEATURE_BARRIER_REEF"].Index then -- Do not import Natural Wonder here !
				if bOutput then print(" - Set Feature Type = "..tostring(GameInfo.Features[civ6FeatureType].FeatureType)) end
				TerrainBuilder.SetFeatureType(plot, civ6FeatureType)
			end
		end
		
		-- Set Continent
		if bImportContinents then
			if civ6ContinentType ~= -1 then		
				if bOutput then print(" - Set Continent Type = "..tostring(GameInfo.Continents[civ6ContinentType].ContinentType)) end
				TerrainBuilder.SetContinentType(plot, civ6ContinentType)
			end
		end
		
		-- Set Resources
		if bImportResources and not plot:IsNaturalWonder() then
			if resource[1] ~= -1 then		
				if bOutput then print(" - Set Resource Type = "..tostring(GameInfo.Resources[resource[1]].ResourceType)) end
				--ResourceBuilder.SetResourceType(plot, ResourceCiv5toCiv6[resource[1]], resource[2]) -- maybe an option to import number of resources on one plot even if civ6 use 1 ?
				ResourceBuilder.SetResourceType(plot, resource[1], 1)
			end
		end
		
		-- Set Cliffs
		if Cliffs and not bIgnoreCliffs then
			if Cliffs[1] == 1 then -- IsNEOfCliff
				TerrainBuilder.SetNEOfCliff(plot, true)
				if bOutput then print(" - Set is NE of Cliff") end
			end
			if Cliffs[2] == 1 then -- IsWOfCliff
				TerrainBuilder.SetWOfCliff(plot, true)
				if bOutput then print(" - Set is W of Cliff") end
			end
			if Cliffs[3] == 1 then -- IsNWOfCliff
				TerrainBuilder.SetNWOfCliff(plot, true)
				if bOutput then print(" - Set is NW of Cliff") end
			end	
		end
		
	end	
	
	print("Placed terrain on "..tostring(count) .. " tiles")
end

------------------------------------------------------------------------------
-- True Starting Locations
------------------------------------------------------------------------------

local bForceAll = (MapConfiguration.GetValue("ForceTSL") == "FORCE_TSL_ALL")
local bForceAI = (MapConfiguration.GetValue("ForceTSL") == "FORCE_TSL_AI") or bForceAll

function IsSafeStartingDistance(plot, bIsMajor, bIsHuman)
	if MapConfiguration.GetValue("ForceTSL") == "FORCE_TSL_OFF"	then
		return true
	elseif (not bForceAI) and bIsMajor then
		return true
	elseif (not bForceAll) and bIsHuman then
		return true
	end
	
	local MinDistance = GlobalParameters.CITY_MIN_RANGE
	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local player = Players[iPlayer]
		local startingPlot = player:GetStartingPlot()
		if startingPlot and Map.GetPlotDistance(plot:GetIndex(), startingPlot:GetIndex()) <= MinDistance then
			return false
		end
	end
	return true
end

function SetTrueStartingLocations()
	print ("-------------------------------------------------------")
	print ("Beginning True Starting Location placement for "..tostring(mapName))
	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local player = Players[iPlayer]
		local CivilizationTypeName = PlayerConfigurations[iPlayer]:GetCivilizationTypeName()
		local position = getTSL[iPlayer]
		if position then 
			print ("- "..tostring(CivilizationTypeName).." at "..tostring(position.X)..","..tostring(position.Y))
			local plot = Map.GetPlot(position.X, position.Y)
			if plot and not plot:IsWater() then
				if plot:IsStartingPlot() then
					print ("WARNING ! Plot is already a Starting Position")
				else					
					if player:IsMajor() then
						if IsSafeStartingDistance(plot, true, player:IsHuman()) then
							player:SetStartingPlot(plot)
							--table.insert(AssignStartingPlots.majorStartPlots, plot)
						else
							print ("WARNING ! Plot is too close from another Starting Position")
						end
					else
						if IsSafeStartingDistance(plot, false, false) then
							player:SetStartingPlot(plot)
							--table.insert(AssignStartingPlots.minorStartPlots, plot)
						else
							print ("WARNING ! Plot is too close from another Starting Position")
						end
					end
				end
			else
				print ("WARNING ! Plot is out of land !")
			end
		end
	end	
end

function YnAMP_StartPositions()

	if bTSL then
		SetTrueStartingLocations()	
	end
	
	if bCulturallyLinked then
		CulturallyLinkedCivilizations()	
		CulturallyLinkedCityStates()
	end
end

------------------------------------------------------------------------------
-- Culturally Linked Start Locations
------------------------------------------------------------------------------
function Round(num)
    under = math.floor(num)
    upper = math.floor(num) + 1
    underV = -(under - num)
    upperV = upper - num
    if (upperV > underV) then
        return under
    else
        return upper
    end
end

BRUTE_FORCE_TRIES 	= 3 -- raise this number for better placement but longer initialization. From tests, 3 passes should be more than enough.
OVERSEA_PENALTY 	= 50 -- distance penalty for starting plot separated by sea
SAME_GROUP_WEIGHT 	= 5 -- factor to use for distance in same cultural group

g_CultureRelativeDistance = {
	["ETHNICITY_EURO"] 		= 0, -- Eurocentrism confirmed !
	["ETHNICITY_MEDIT"] 	= 1,
	["ETHNICITY_SOUTHAM"] 	= 20,
	["ETHNICITY_ASIAN"] 	= 10,
	["ETHNICITY_AFRICAN"] 	= 5,
}

function CalculateDistanceScore(cultureList, bOutput, player1, player2)

	local prevOutput	= bOutput
	if bOutput then print ("------------------------------------------------------- ") end
	if bOutput then  print ("Calculating distance score...") end
	local globalDistanceScore 	= 0
	local cultureDistanceScore 	= {}
	for civCulture, playerList in pairs(cultureList) do
		if bOutput then  print (" - culture = " .. tostring(civCulture)) end
		local distanceScore = 0
		for i, playerID in pairs(playerList) do
			bOutput						= prevOutput or playerID == player1 or  playerID == player2
			local player 				= Players[playerID]
			local playerConfig 			= PlayerConfigurations[playerID]
			local initialDistanceScore 	= distanceScore
			if bOutput then  print ("    - player = " .. tostring(playerConfig:GetPlayerName())) end
			for _, player_ID2 in ipairs(PlayerManager.GetAliveMajorIDs()) do
				local player2 		= Players[player_ID2]
				local playerConfig2 = PlayerConfigurations[player_ID2]
				local civCulture2 	= GameInfo.Civilizations[playerConfig2:GetCivilizationTypeID()].Ethnicity
				if  civCulture2 == civCulture then
					local startPlot1 = player:GetStartingPlot()
					--if not startPlot1 then print("WARNING no starting plot for : " .. tostring(playerConfig:GetPlayerName())) end
					local startPlot2 = player2:GetStartingPlot()
					--if not startPlot2 then print("WARNING no starting plot for : " .. tostring(playerConfig2:GetPlayerName())) end
					if startPlot1 and startPlot2 then
						local distance = Map.GetPlotDistance(startPlot1:GetX(), startPlot1:GetY(), startPlot2:GetX(), startPlot2:GetY())
						if startPlot1:GetArea() ~= startPlot2:GetArea() then
							distance = distance + OVERSEA_PENALTY
						end
						distanceScore = distanceScore + Round(distance*SAME_GROUP_WEIGHT) -- we want distance to be a bigger factor between Civilization of the same Ethnicity, so that the global score gets higher when they are far apart
						if bOutput then print ("      - Distance to same culture (" .. tostring(playerConfig2:GetPlayerName()) .. ") = " .. tostring(distance) .. " (*".. tostring(SAME_GROUP_WEIGHT) .."), total distance score = " .. tostring(distanceScore) ) end
					end
				else
					local interGroupMinimizer = 1
					if g_CultureRelativeDistance[civCulture] and g_CultureRelativeDistance[civCulture2] then
						interGroupMinimizer = math.abs(g_CultureRelativeDistance[civCulture] - g_CultureRelativeDistance[civCulture2])
					else
						interGroupMinimizer = 8 -- unknown culture group (new DLC ?), average distance
					end
					local startPlot1 = player:GetStartingPlot()
					--if not startPlot1 then print("WARNING no starting plot for : " .. tostring(playerConfig:GetPlayerName())) end
					local startPlot2 = player2:GetStartingPlot()
					--if not startPlot2 then print("WARNING no starting plot for : " .. tostring(playerConfig2:GetPlayerName())) end
					if startPlot1 and startPlot2 then
						local distance = Map.GetPlotDistance(startPlot1:GetX(), startPlot1:GetY(), startPlot2:GetX(), startPlot2:GetY())
						distanceScore = distanceScore + Round(distance/interGroupMinimizer)  -- we want distance to be a smaller factor between Civilization of different Ethnicity, so that the global score doesn't get too high when they are already far apart
						if bOutput then print ("      - Distance to different culture (" .. tostring(playerConfig2:GetPlayerName()) .. ") = " .. tostring(distance) .. " (/".. tostring(interGroupMinimizer) .." from intergroup relative distance), total distance score = " .. tostring(distanceScore) ) end
					end
				end
			end
			if bOutput then  print ("         - Player Distance Score = "..tostring(distanceScore - initialDistanceScore).." for " .. tostring(playerConfig:GetPlayerName())) end
			bOutput	= prevOutput
		end
		cultureDistanceScore[civCulture] = distanceScore
		globalDistanceScore = globalDistanceScore + distanceScore
	end		
	if bOutput then print ("Global distance score = " .. tostring(globalDistanceScore)) end
	if bOutput then print ("------------------------------------------------------- ") end
	return globalDistanceScore
end

local bAllCivsPlaced
function CulturallyLinkedCivilizations(bForcePlacement)

	local playerList 		= {}
	local cultureList 		= {}
	local cultureCount 		= {}
	local bestList 			= {}
	local bestDistanceScore = 9999999 -- need to keep that one above 1 million for extrem cases	(ludicrous maps / 63 civilizations)
	bAllCivsPlaced 			= true
	
	print ("------------------------------------------------------- ")
	print ("Creating Civilization list for Culturally linked startingposition... ")
	for _, player_ID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do

		-- creating player lists
		local player 		= Players[player_ID]
		local playerConfig 	= PlayerConfigurations[player_ID]
		if not player:GetStartingPlot() then
			print("WARNING : no Starting Plot defined for " .. playerConfig:GetPlayerName())
			bAllCivsPlaced = false
		else
			local civCulture = GameInfo.Civilizations[playerConfig:GetCivilizationTypeID()].Ethnicity
			if not civCulture then
				-- print("PUJ WARNING : no Ethnicity defined for " .. playerConfig:GetPlayerName() ..", using EURO")
				civCulture = "ETHNICITY_EURO"
			end
			print (" - Adding player " .. tostring(playerConfig:GetPlayerName()) .. " to culture " .. tostring(civCulture))
			table.insert(playerList, player_ID)
			if cultureList[civCulture] then
				table.insert(cultureList[civCulture], player_ID)
				cultureCount[civCulture] = cultureCount[civCulture] + 1
			else
				cultureList[civCulture] = {}
				table.insert(cultureList[civCulture], player_ID)
				cultureCount[civCulture] = 1
			end
		end

	end
	print ("------------------------------------------------------- ")
	
	if (not bAllCivsPlaced) then
		if (not bForcePlacement) then
			print("Aborting cultural placement...")
			return
		else
			print("Force cultural placement for Civilizations with a Starting Location...")
		end
	end

	-- Sort culture table by number of civs...
	local cultureTable = {}
	for civCulture, num in pairs(cultureCount) do	
		table.insert(cultureTable, {Culture = civCulture, Num = num})
	end
	table.sort(cultureTable, function(a,b) return a.Num > b.Num end)
	for i, data in ipairs(cultureTable) do	
		print ("Culture " .. tostring(data.Culture) .. " represented by " .. tostring(data.Num) .. " civs")
	end
	print ("------------------------------------------------------- ")

	
	local initialDistanceScore = CalculateDistanceScore(cultureList)
	if  initialDistanceScore < bestDistanceScore then
		bestDistanceScore = initialDistanceScore
	end

	-- todo : do and lock initial placement of the biggest cultural group in game
	-- on the area with most starting plots, then use brute force for the remaining civs

	-- todo : add cultural relative distance (ie Mediterannean should be closer from European than American or Asian culture)

	-- very brute force
	for try = 1, BRUTE_FORCE_TRIES do 
		print ("------------------------------------------------------- ")
		print ("Brute Force Pass num = " .. tostring(try) )
		for _, player_ID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
			local player = Players[player_ID]
			local playerConfig = PlayerConfigurations[player_ID]
			print ("------------------------------------------------------- ")
			print ("Testing " .. tostring(playerConfig:GetPlayerName()) )
			local culture = GameInfo.Civilizations[playerConfig:GetCivilizationTypeID()].Ethnicity or "ETHNICITY_EURO"
			for _, player_ID2 in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do	
				--print ("in loop 2")
				if player_ID ~= player_ID2 then
					local player2 = Players[player_ID2]
					local playerConfig2 = PlayerConfigurations[player_ID2]
					local culture2 = GameInfo.Civilizations[playerConfig2:GetCivilizationTypeID()].Ethnicity or "ETHNICITY_EURO"
					if culture ~= culture2 then -- don't try to swith civs from same culture style, we can gain better score from different culture only...
						--print ("culture ~= culture2")
						local startPlot1 = player:GetStartingPlot()
						local startPlot2 = player2:GetStartingPlot()					
						if startPlot1 and startPlot2 then
							--print ("------------------------------------------------------- ")
							--print ("trying to switch " .. tostring(playerConfig:GetPlayerName()) .. " with " .. tostring(playerConfig2:GetPlayerName()) )	
							player:SetStartingPlot(startPlot2)
							player2:SetStartingPlot(startPlot1)
							local actualdistanceScore = CalculateDistanceScore(cultureList, false)--, player_ID, player_ID2)
							if  actualdistanceScore < bestDistanceScore then
								--print ("------------------------------------------------------- ")
								--print ("Better score, confirming switching position of " .. tostring(playerConfig:GetPlayerName()) .. " with " .. tostring(playerConfig2:GetPlayerName()) .. " at new best score = " .. tostring(actualdistanceScore) )
								print ("Better score, switching position of " .. tostring(playerConfig:GetPlayerName()) .. " with " .. tostring(playerConfig2:GetPlayerName()) .. " at new best score = " .. tostring(actualdistanceScore) )
								bestDistanceScore = actualdistanceScore
							else
								--print ("------------------------------------------------------- ")
								--print ("No gain, restoring position of " .. tostring(playerConfig:GetPlayerName()) .. " and " .. tostring(playerConfig2:GetPlayerName()) .. " at current best score = " .. tostring(bestDistanceScore) )
								--print ("No gain, keeping position of " .. tostring(playerConfig:GetPlayerName()) .. " and " .. tostring(playerConfig2:GetPlayerName()) .. " at score = "..tostring(actualdistanceScore)..", current best score = " .. tostring(bestDistanceScore) )	
								player:SetStartingPlot(startPlot1)
								player2:SetStartingPlot(startPlot2)
							end
						end
					end
				end
			end
		end

		--print ("------------------------------------------------------- ")
		--print ("Brute Force Pass num " .. tostring(try) )
		print ("New global distance = " .. tostring(CalculateDistanceScore(cultureList)))
	end
	CalculateDistanceScore(cultureList)
	print ("------------------------------------------------------- ")
	print ("INITIAL DISTANCE SCORE = " .. tostring(initialDistanceScore))
	print ("------------------------------------------------------- ")
	print ("FINAL DISTANCE SCORE: " .. tostring(CalculateDistanceScore(cultureList)) )
	print ("------------------------------------------------------- ")
end

function CalculateDistanceScoreCityStates(bOutput)
	if bOutput then print ("------------------------------------------------------- ") end
	if bOutput then  print ("Calculating distance score for City States...") end
	local globalDistanceScore = 0
	
	for _, player_ID in ipairs(PlayerManager.GetAliveMinorIDs()) do
		local player = Players[player_ID]
		local playerConfig = PlayerConfigurations[player_ID]
		local distanceScore = 0
		local startPlot1 = player:GetStartingPlot()
		local civCulture = GameInfo.Civilizations[playerConfig:GetCivilizationTypeID()].Ethnicity		
		if not civCulture then
			-- print("WARNING : no Ethnicity defined for " .. playerConfig:GetPlayerName() ..", using EURO")
			civCulture = "ETHNICITY_EURO"
		end
		if startPlot1 ~= nil then

			if bOutput then  print ("    - player = " .. tostring(playerConfig:GetPlayerName())) end

			for _, player_ID2 in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
				local player2 = Players[player_ID2]
				local playerConfig2 = PlayerConfigurations[player_ID2]
				local civCulture2 = GameInfo.Civilizations[playerConfig2:GetCivilizationTypeID()].Ethnicity or "ETHNICITY_EURO"
				if  civCulture2 == civCulture then
					local startPlot2 = player2:GetStartingPlot()
					if startPlot2 then
						local distance = Map.GetPlotDistance(startPlot1:GetX(), startPlot1:GetY(), startPlot2:GetX(), startPlot2:GetY())
						if startPlot1:GetArea() ~= startPlot2:GetArea() then
							distance = distance + OVERSEA_PENALTY
						end
						distanceScore = distanceScore + Round(distance*SAME_GROUP_WEIGHT)
						if bOutput then print ("      - Distance to same culture (" .. tostring(playerConfig2:GetPlayerName()) .. ") = " .. tostring(distance) .. " (x".. tostring(SAME_GROUP_WEIGHT) .."), total distance score = " .. tostring(distanceScore) ) end
					else
						print("      - WARNING: no starting plot available for " .. tostring(playerConfig2:GetPlayerName()))
					end
				else
					local interGroupMinimizer = 1
					if g_CultureRelativeDistance[civCulture] and g_CultureRelativeDistance[civCulture2] then
						interGroupMinimizer = math.abs(g_CultureRelativeDistance[civCulture] - g_CultureRelativeDistance[civCulture2])
					else
						interGroupMinimizer = 8 -- unknown culture group, average distance
					end
					local startPlot2 = player2:GetStartingPlot()
					if startPlot2 then
						local distance = Map.GetPlotDistance(startPlot1:GetX(), startPlot1:GetY(), startPlot2:GetX(), startPlot2:GetY())
						distanceScore = distanceScore + Round(distance/interGroupMinimizer)
						if bOutput then print ("      - Distance to different culture (" .. tostring(playerConfig2:GetPlayerName()) .. ") = " .. tostring(distance) .. " (/".. tostring(interGroupMinimizer) .." from intergroup relative distance), total distance score = " .. tostring(distanceScore) ) end
					else
						print("      - WARNING: no starting plot available for " .. tostring(playerConfig2:GetPlayerName()))
					end
				end
			end
		end
		globalDistanceScore = globalDistanceScore + distanceScore
	end		
	if bOutput then print ("Global distance score = " .. tostring(globalDistanceScore)) end
	if bOutput then print ("------------------------------------------------------- ") end
	return globalDistanceScore
end

-- try to place city states closes to corresponding culture civs
function CulturallyLinkedCityStates(bForcePlacement)

	if (not bAllCivsPlaced) then
		if (not bForcePlacement) then
			print("Aborting cultural placement...")
			return
		else
			print("Force cultural placement for Civilizations with a Starting Location...")
		end
	end
	
	local bestDistanceScore = 9999999
	
	print ("------------------------------------------------------- ")
	print ("Set Culturally linked starting positions for City States... ")

	local initialDistanceScore = CalculateDistanceScoreCityStates()
	if  initialDistanceScore < bestDistanceScore then
		bestDistanceScore = initialDistanceScore
	end

	-- very brute force again
	for try = 1, BRUTE_FORCE_TRIES do 
		print ("------------------------------------------------------- ")
		print ("Brute Force Pass num = " .. tostring(try) )
		for _, player_ID in ipairs(PlayerManager.GetAliveMinorIDs()) do
			local player = Players[player_ID]
			local playerConfig = PlayerConfigurations[player_ID]
			local culture = GameInfo.Civilizations[playerConfig:GetCivilizationTypeID()].Ethnicity

			for _, player_ID2 in ipairs(PlayerManager.GetAliveMinorIDs()) do
				local player2 = Players[player_ID2]
				if player_ID ~= player_ID2 then
					local playerConfig2 = PlayerConfigurations[player_ID2]
					local startPlot1 = player:GetStartingPlot()
					local startPlot2 = player2:GetStartingPlot()
					--print ("  - Player = " .. tostring(playerConfig:GetPlayerName()) .. ", Start Plot = " .. tostring(startPlot1) )
					--print ("  - Player = " .. tostring(playerConfig2:GetPlayerName()) .. ", Start Plot = " .. tostring(startPlot2) )
					local culture2 = GameInfo.Civilizations[playerConfig2:GetCivilizationTypeID()].Ethnicity
					if (startPlot1 ~= nil) and (startPlot2 ~= nil) then
						if culture ~= culture2 then -- don't try to swith civs from same culture style, we can gain better score from different culture only...
							--print ("culture ~= culture2")
							--print ("------------------------------------------------------- ")
							--print ("trying to switch " .. tostring(playerConfig:GetPlayerName()) .. " with " .. tostring(playerConfig2:GetPlayerName()) )
							player:SetStartingPlot(startPlot2)
							player2:SetStartingPlot(startPlot1)
							local actualdistanceScore = CalculateDistanceScoreCityStates()
							if  actualdistanceScore < bestDistanceScore then
								bestDistanceScore = actualdistanceScore
								--print ("------------------------------------------------------- ")
								--print ("Better score, conforming switching position of " .. tostring(playerConfig:GetPlayerName()) .. " with " .. tostring(playerConfig2:GetPlayerName()) )
							else
								--print ("------------------------------------------------------- ")
								--print ("No gain, restoring position of " .. tostring(playerConfig:GetPlayerName()) .. " and " .. tostring(playerConfig2:GetPlayerName()) )								
								player:SetStartingPlot(startPlot1)
								player2:SetStartingPlot(startPlot2)
							end
						end
					end						
				end
			end			

		end
		print ("New global distance = " .. tostring(CalculateDistanceScoreCityStates()))
	end
	print ("------------------------------------------------------- ")
	print ("CS INITIAL DISTANCE SCORE = " .. tostring(initialDistanceScore))
	print ("------------------------------------------------------- ")
	print ("CS FINAL DISTANCE SCORE = " .. tostring(CalculateDistanceScoreCityStates()))
	print ("------------------------------------------------------- ")
end

------------------------------------------------------------------------------
-- Override/Backup functions
------------------------------------------------------------------------------

print ("Replacing ResourceBuilder.CanHaveResource by YnAMP_CanHaveResource...")
ResourceBuilder.OldCanHaveResource = ResourceBuilder.CanHaveResource
ResourceBuilder.CanHaveResource = YnAMP_CanHaveResource

------------------------------------------------------------------------------
-- Detailed Worlds replace MapUtilities.lua with a version missing IsAdjacentToLandPlot
-- We set a backup function here, only if the original is missing
function IsAdjacentToLandPlotBackup(x, y)
	-- Computes IsAdjacentToLand from the plot
	local plot = Map.GetPlot(x, y);
	if plot ~= nil then
		for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			local testPlot = Map.GetAdjacentPlot(x, y, direction);
			if testPlot ~= nil then
				if testPlot:IsWater() == false then -- Adjacent plot is land
					return true
				end
			end
		end
	end
	return false
end
IsAdjacentToLandPlot = IsAdjacentToLandPlot or IsAdjacentToLandPlotBackup

------------------------------------------------------------------------------
-- Override required to use limits on ice placement for imported maps
function FeatureGenerator:AddIceAtPlot(plot, iX, iY)

	local bNorth = iY > (self.iGridH/2)

	if not bNorth and (iIceSouth and (iIceSouth == 0 or iIceSouth < iY)) then
		return false;
	end
	
	if bNorth and iIceNorth and (iIceNorth == 0 or self.iGridH - iIceNorth > iY) then
		return false;
	end
	
	local bNoIceAdjacentToLand = MapConfiguration.GetValue("NoIceAdjacentToLand");
	if bNoIceAdjacentToLand and plot:IsAdjacentToLand() then
		return false;
	end

	local lat = math.abs((self.iGridH/2) - iY)/(self.iGridH/2)

	if Map.IsWrapX() and (iY == 0 or iY == self.iGridH - 1) then
		TerrainBuilder.SetFeatureType(plot, g_FEATURE_ICE);
	else
		local rand = TerrainBuilder.GetRandomNumber(100, "Add Ice Lua")/100.0;
		
		if(rand < 8 * (lat - 0.875)) then
			TerrainBuilder.SetFeatureType(plot, g_FEATURE_ICE);
			return true;
		elseif(rand < 4 * (lat - 0.75)) then
			TerrainBuilder.SetFeatureType(plot, g_FEATURE_ICE);
			return true;
		end
	end
	
	return false;
end

------------------------------------------------------------------------------
-- The original function was placing forest and marshs on every available plots in the south of the Europe map, maybe because all the first land plots tested were deserts ?
-- It has been changed here to randomize the order in which the land plots are tested for features placement.
function FeatureGenerator:AddFeatures(allow_mountains_on_coast)
	print("YnAMP : FeatureGenerator:AddFeatures() override")
	local flag = allow_mountains_on_coast or true;

	if allow_mountains_on_coast == false then -- remove any mountains from coastal plots
		for x = 0, self.iGridW - 1 do
			for y = 0, self.iGridH - 1 do
				local plot = Map.GetPlot(x, y)
				if plot:GetPlotType() == g_PLOT_TYPE_MOUNTAIN then
					if plot:IsCoastalLand() then
						plot:SetPlotType(g_PLOT_TYPE_HILLS, false, true); -- These flags are for recalc of areas and rebuild of graphics. Instead of recalc over and over, do recalc at end of loop.
					end
				end
			end
		end
		-- This function needs to recalculate areas after operating. However, so does 
		-- adding feature ice, so the recalc was removed from here and put in MapGenerator()
	end
	
	-- First pass, adds ice to water plots as appropriate and count land plots that can have a feature
	local availableLandPlots = {}
	for y = 0, self.iGridH - 1, 1 do
		for x = 0, self.iGridW - 1, 1 do			

			local i = y * self.iGridW + x;
			local plot = Map.GetPlotByIndex(i);
			if(plot ~= nil) then
				local featureType = plot:GetFeatureType();

				if(plot:IsImpassable() or featureType ~= g_FEATURE_NONE) then
					--No Feature
				elseif(plot:IsWater() == true) then
					if(TerrainBuilder.CanHaveFeature(plot, g_FEATURE_ICE) == true and IsAdjacentToRiver(x, y) == false) then
						self:AddIceAtPlot(plot, x, y);
					end
					
					local bIce = false;
					if(TerrainBuilder.CanHaveFeature(plot, g_FEATURE_ICE) == true and IsAdjacentToRiver(x, y) == false) then
						bIce = self:AddIceAtPlot(plot, x, y);
					end
					
					if(bIce == false and self.AddReefAtPlot and TerrainBuilder.CanHaveFeature(plot, g_FEATURE_REEF) == true ) then						
						self:AddReefAtPlot(plot, x, y);
					end
				else  -- mark this plot available for land feature
					self.iNumLandPlots = self.iNumLandPlots + 1
					table.insert(availableLandPlots, plot)
				end
			end
		end
	end
	
	-- second pass, add features to all land plots as appropriate based on the count and percentage of that type
	local aShuffledAvailablePlots =  GetShuffledCopyOfTable(availableLandPlots)
	for k, plot in ipairs(aShuffledAvailablePlots) do
		if(plot ~= nil) then
			local x, y = plot:GetX(), plot:GetY()
			if(TerrainBuilder.CanHaveFeature(plot, g_FEATURE_FLOODPLAINS) == true) then
				-- All desert plots along river are set to flood plains.
				TerrainBuilder.SetFeatureType(plot, g_FEATURE_FLOODPLAINS)
			elseif(TerrainBuilder.CanHaveFeature(plot, g_FEATURE_OASIS) == true and math.ceil(self.iOasisCount * 100 / self.iNumLandPlots) <= self.iOasisMaxPercent ) then
				if(TerrainBuilder.GetRandomNumber(4, "Oasis Random") == 1) then
					TerrainBuilder.SetFeatureType(plot, g_FEATURE_OASIS);
					self.iOasisCount = self.iOasisCount + 1;
				end
			end

			local featureType = plot:GetFeatureType()
			local bMarsh = false;
			local bJungle = false;
			if(featureType == g_FEATURE_NONE) then
				--First check to add Marsh
				bMarsh = self:AddMarshAtPlot(plot, x, y);

				if(featureType == g_FEATURE_NONE and  bMarsh == false) then
					--check to add Jungle
					bJungle = self:AddJunglesAtPlot(plot, x, y);
				end
				
				if(featureType == g_FEATURE_NONE and bMarsh== false and bJungle == false) then 
					--check to add Forest
					self:AddForestsAtPlot(plot, x, y);
				end
			end
		end
	end	
	
	print("Number of Forests: ", self.iForestCount);
	print("Number of Jungles: ", self.iJungleCount);
	print("Number of Marshes: ", self.iMarshCount);
	print("Number of Oasis: ", self.iOasisCount);
end


------------------------------------------------------------------------------
-- /end YnAMP
------------------------------------------------------------------------------


-- Used at L526 after fertility sort for minor civs
function shuffle_table(tbl)
  size = #tbl
  for i = size, 1, -1 do
    local rand = math.random(size)
    tbl[i], tbl[rand] = tbl[rand], tbl[i]
  end
  return tbl
end

function GetAllPlotsRandomized()
	plots = {}

	local iPlotCount = Map.GetPlotCount();
	for i = 0, iPlotCount - 1 do
		local plot = Map.GetPlotByIndex(i);		
		local valid = true;
		if(plot:IsWater() == true) then
			valid = false
		end
		if(plot:IsImpassable() == true) then
			valid = false;
		end
		if(valid == true) then
			table.insert (plots, plot);
		end
	end

	shuffle_table(plots);
	print("Returning ",#plots," plots");
	return plots
end
