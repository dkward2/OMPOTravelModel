// networkmanager.rsc
//
// TransCAD Macro used to extract a highway and transit network
// from a master line layer. Developed for OMPO, based on work
// by Ory for PTRM.
//
// 06December2007 [dto]
// 18January2008 [jef]
// 28October2009 [ARF]
//
Macro "Create Network"(path, Options, year)

//    RunMacro("TCB Init")
    // Set the Year
    currentYear = year

    // Set the folder name
    ScenarioDirectory = path[2]

    // Set the temporary directory
    tempDirectory = path[10]
    // Kyle: reset the temp directory to be inside the scenario directory
    tempDirectory = ScenarioDirectory + "/outputs/temp/"

    // Set the master network directory
    masterNetworkDirectory =path[4]

    // Set the turn penalty directory
    turnPenaltyDirectory = path[5]

    // Set the other inputs directory
    otherDirectory = path[6]

    // Set the programs directory
    programsDirectory = path[9]

    // Set the controls directory
    controlsDirectory = path[8]

    // Set the scripts directory
    scriptsDirectory = path[11]

    // Set the DTA directory
    DTADirectory = path[12]

    // Set the output network directory
    ModelDirectory=path[3]

    // Set the master highway line network
    masterLineFile="Oahu Network 102907.dbd"

    // Set the master route file
    masterRouteFile="Oahu Route System 102907.rts"

    // The scenario network directory is based on the folderName - could change this convention
    scenarioNetworkDirectory=ScenarioDirectory + "\\inputs\\network"

    // The scenario turn penalty directory is based on the folderName - could change this convention
    scenarioTurnsDirectory=ScenarioDirectory + "\\inputs\\turns"

    // The scenario other inputs directory is based on the folderName - could change this convention
    scenarioOtherDirectory=ScenarioDirectory + "\\inputs\\other"

    // The scenario programs directory is based on the folderName - could change this convention
    scenarioProgramsDirectory=ScenarioDirectory + "\\programs"

    // The scenario controls directory is based on the folderName - could change this convention
    scenarioControlsDirectory=ScenarioDirectory + "\\controls"

    // The scenario scripts directory is based on the folderName - could change this convention
    scenarioScriptsDirectory=ScenarioDirectory + "\\scripts"

     // The scenario DTA directory is based on the folderName - could change this convention
    scenarioDTADirectory=ScenarioDirectory + "\\DTA"

    // The scenario DTA directory is based on the folderName - could change this convention
    scenarioDTAfactorsDirectory=ScenarioDirectory + "\\DTA\\FactorTripTables"

    // Copy the Master line layer to a temporary location for safety
    originalMasterLine = masterNetworkDirectory + masterLineFile
    masterLine = tempDirectory + "Master Line Layer.dbd"
    CopyDatabase(originalMasterLine,masterLine)

    masterRoute = masterNetworkDirectory + masterRouteFile

    //copy turns
    RunMacro("Copy Files",turnPenaltyDirectory,scenarioTurnsDirectory)

    //copy other inputs
    RunMacro("Copy Files",otherDirectory,scenarioOtherDirectory)

    // Find the growth factor for the current year
    visitorGFTable = ScenarioDirectory + "\\inputs\\other\\Visitor Growth Factors.bin"
    visitorGF = OpenTable("visitorGF", "FFB", {visitorGFTable})
    SetView("visitorGF")
		rh = LocateRecord("visitorGF|", "Year", {currentYear}, )
		GF = GetRecordValues("visitorGF", rh, {"[Growth Factor]"})
		temp11 = GF[1][2]
    CloseView("visitorGF")

    // Modify the observed visitor trips based on the groth factors
    Opts = null
		Opts.Input.[Matrix Currency] = {ScenarioDirectory + "\\inputs\\other\\visobs.mtx", "Table 1", , }
		Opts.Global.Method = 5
		Opts.Global.[Cell Range] = 2
		Opts.Global.[Matrix Range] = 1
		Opts.Global.[Matrix List] = {"Table 1"}
		Opts.Global.[Value] = GF[1][2]
		Opts.Global.[Force Missing] = "Yes"

		ret_value = RunMacro("TCB Run Operation", "Fill Matrices", Opts)


    //copy programs
    RunMacro("Copy Files",programsDirectory,scenarioProgramsDirectory)

    //copy control files
    RunMacro("Copy Files",controlsDirectory,scenarioControlsDirectory)

    //copy scripts
    RunMacro("Copy Files",scriptsDirectory,scenarioScriptsDirectory)

    //copy DTA files
    RunMacro("Copy Files",DTADirectory,scenarioDTADirectory)

    //copy DTAfactors files
    RunMacro("Copy Files",DTADirectory +"\\FactorTripTables",scenarioDTAfactorsDirectory)

    //copy AQ files
    AQDirectory = DTADirectory + "\\..\\inputs\\aq"
    scenarioAQDirectory = ScenarioDirectory + "\\inputs\\aq"
    RunMacro("Copy Files",AQDirectory, scenarioAQDirectory)

    //check for directory of DTA output
    if GetDirectoryInfo(scenarioDTADirectory + "\\outputs", "Directory")=null then do
        CreateDirectory(scenarioDTADirectory + "\\outputs")
    end

    //check for directory of output network
    if GetDirectoryInfo(scenarioNetworkDirectory, "Directory")=null then do
        CreateDirectory( scenarioNetworkDirectory)
    end

    //check for directory of outputs
    if GetDirectoryInfo(ScenarioDirectory + "\\outputs", "Directory")=null then do
        CreateDirectory(ScenarioDirectory + "\\outputs")
    end

    //check for directory of reports
    if GetDirectoryInfo(ScenarioDirectory + "\\reports", "Directory")=null then do
        CreateDirectory(ScenarioDirectory + "\\reports")
    end

   // Set the location of the output network
    scenarioLineFile = scenarioNetworkDirectory + "\\"+"Scenario Line Layer.dbd"

    // Set the extraction parameters
    extractLineString = "not (year>"+String(currentYear)+" and [future link]='a') and not (year<="+String(currentYear)+" and [future link]='d')"

    CreateProgressBar("Creating Network","False")

    // Run the generic Create Highway Line Layer Macro
    UpdateProgressBar("Select from Master Line Layer",0)
    tempFile = RunMacro("Select from Master Line Layer",masterLine,extractLineString,tempDirectory)

    // Run the roadway project management library in gisdk_tools
    UpdateProgressBar("Update Project Links",0)
    RunMacro("Close All")
    proj_csv = ScenarioDirectory + "/HighwayProjectList.csv"
    opts = null
    opts.hwy_dbd = tempFile
    opts.proj_list = proj_csv
    opts.master_dbd = masterNetworkDirectory + masterLineFile
    RunMacro("Highway Project Management", opts)

    extractPNRString = "("+String(currentYear)+">=[Start Year_PNR Lot] & "+String(currentYear)+"<=[End Year_PNR Lot])"
    //Assign the parking lots based on the start and end year
    UpdateProgressBar("Assign PNR Lots",0)
    tempFile = RunMacro("Assign PNR Lots",tempFile,currentYear,extractPNRString)

    // Export the highway line layer with the fields I want
    UpdateProgressBar("Export Highway Line Layer",0)
    RunMacro("Export Highway Line Layer",tempFile,scenarioLineFile)

   // Select the transit routes, and copy the transit layer to the scenario directory
    UpdateProgressBar("Export Transit Routes",0)

    // Kyle: replaced the previous approach with the new, simplified transit
    // project manager.
    // https://github.com/pbsag/gisdk_tools/wiki/Transit-Manager
    RunMacro("Close All")
    opts = null
    opts.master_rts = masterRoute
    opts.scen_hwy = scenarioNetworkDirectory + "/Scenario Line Layer.dbd"
    opts.proj_list = ScenarioDirectory + "/TransitProjectList.csv"
    opts.centroid_qry = "[Zone Centroid] = 'Y'"
    opts.output_rts_file = "Scenario Route System.rts"
    RunMacro("Transit Project Management", opts)

    UpdateProgressBar("Fill Stop Attributes",0)
    hwyfile = scenarioLineFile
    RunMacro("Fill Stop Attributes" , hwyfile, scenarioNetworkDirectory+"\\Scenario Route System.rts", scenarioNetworkDirectory+"\\Scenario Route SystemS.bin")

    UpdateProgressBar("Copy Layer Settings",0)
    RunMacro("Copy Layer Settings", originalMasterLine,scenarioLineFile)

    DestroyProgressBar()

    Return(1)

EndMacro

Macro "Select from Master Line Layer" (masterLine,extractString,tempDirectory)

    // Check that the files exist
    //		- master line
    if GetFileInfo(masterLine) = null then do
        ShowMessage("File not found: " + masterLine)
        Return()
    end

    // Use the master line scope to create a temporary map
    dbInfo = GetDBInfo(masterLine)
    newmap = CreateMap("TempMap",{{"Scope",dbInfo[1]}})
    // Get the layer names
    dbLayers = GetDBLayers(masterLine)

    // Add the Nodes layer to the map and make it visible
    nodeLayer = AddLayer("TempMap","Nodes",masterLine,dbLayers[1])
    SetLayerVisibility(nodeLayer,"True")
    SetLayer(nodeLayer)

    // Prepare the node field names for the new geography
    nodeFields = GetFields(,"All")
    newNodeFields = null
    for j = 1 to nodeFields[1].length do
        newNodeFields = newNodeFields + {"Nodes." + (nodeFields[1][j])}
    end

    // Add the Network Roads layer to the map and make it visible
    lineLayer = AddLayer("TempMap","Links",masterLine,dbLayers[2])
    SetLayerVisibility(lineLayer,"True")
    SetLayer(lineLayer)

    // Prepare the field names for the new layer
    linkFields = GetFields(,"All")
    newLinkFields = null
    for j = 1 to linkFields[1].length do
        newLinkFields = newLinkFields + {"Links." + (linkFields[1][j])}
    end

    // Extract the projects for this year
    // Kyle: with new project management system, just export all links
    SetLayer(lineLayer)
    // queryString = "Select * where " + extractString
    // recordsReturned = SelectByQuery("YearSpecific","Several",queryString, )
    // Export Geography to a temporary file
    tempFile = tempDirectory + "temp.dbd"
    // ExportGeography(lineLayer+"|YearSpecific",tempFile,
    ExportGeography(lineLayer+"|",tempFile,
                  { {"Layer Name","Links"}, {"Field Spec",newLinkFields},
                  	{"Node Name","Nodes"}, {"Node Field Spec",newNodeFields} })

    CloseMap("TempMap")


    Return(tempFile)

EndMacro


Macro "Change Lanes" (tempFile, currentYear)

    // Check that the files exist
    //		- master line
    if GetFileInfo(tempFile) = null then do
        ShowMessage("File not found: " + tempFile)
        Return()
    end

   // Get the link layer
   {nodeLayer,linkLayer} = RunMacro("TCB Add DB Layers", tempFile,,)

    futureLink = GetDataVector(linkLayer+"|","[future link]",)
    year = GetDataVector(linkLayer+"|","year",)

    //AB_LANEA
    futureVector = GetDataVector(linkLayer+"|","[futureAB_LANEA]",)
    currentVector = GetDataVector(linkLayer+"|","[AB_LANEA]",)
    newVector = if ((futureLink='c' or futureLink='a' or futureLink='l')and (year<=currentYear)) then futureVector else currentVector
    SetDataVector(linkLayer+"|","[AB_LANEA]",newVector,)

    //BA_LANEA
    futureVector = GetDataVector(linkLayer+"|","[futureBA_LANEA]",)
    currentVector = GetDataVector(linkLayer+"|","[BA_LANEA]",)
    newVector = if ((futureLink='c' or futureLink='a' or futureLink='l')and (year<=currentYear)) then futureVector else currentVector
    SetDataVector(linkLayer+"|","[BA_LANEA]",newVector,)

    //AB_LANEM
    futureVector = GetDataVector(linkLayer+"|","[futureAB_LANEM]",)
    currentVector = GetDataVector(linkLayer+"|","[AB_LANEM]",)
    newVector = if ((futureLink='c' or futureLink='a' or futureLink='l')and (year<=currentYear)) then futureVector else currentVector
    SetDataVector(linkLayer+"|","[AB_LANEM]",newVector,)

    //BA_LANEM
    futureVector = GetDataVector(linkLayer+"|","[futureBA_LANEM]",)
    currentVector = GetDataVector(linkLayer+"|","[BA_LANEM]",)
    newVector = if ((futureLink='c' or futureLink='a' or futureLink='l')and (year<=currentYear)) then futureVector else currentVector
    SetDataVector(linkLayer+"|","[BA_LANEM]",newVector,)

    //AB_LANEP
    futureVector = GetDataVector(linkLayer+"|","[futureAB_LANEP]",)
    currentVector = GetDataVector(linkLayer+"|","[AB_LANEP]",)
    newVector = if ((futureLink='c' or futureLink='a' or futureLink='l')and (year<=currentYear)) then futureVector else currentVector
    SetDataVector(linkLayer+"|","[AB_LANEP]",newVector,)

    //BA_LANEP
    futureVector = GetDataVector(linkLayer+"|","[futureBA_LANEP]",)
    currentVector = GetDataVector(linkLayer+"|","[BA_LANEP]",)
    newVector = if ((futureLink='c' or futureLink='a' or futureLink='l')and (year<=currentYear)) then futureVector else currentVector
    SetDataVector(linkLayer+"|","[BA_LANEP]",newVector,)

    //AB_LIMITA
    futureVector = GetDataVector(linkLayer+"|","[future AB_LIMITA]",)
    currentVector = GetDataVector(linkLayer+"|","[AB_LIMITA]",)
    newVector = if ((futureLink='c' or futureLink='a' or futureLink='l')and (year<=currentYear)) then futureVector else currentVector
    SetDataVector(linkLayer+"|","[AB_LIMITA]",newVector,)

    //BA_LIMITA
    futureVector = GetDataVector(linkLayer+"|","[future BA_LIMITA]",)
    currentVector = GetDataVector(linkLayer+"|","[BA_LIMITA]",)
    newVector = if ((futureLink='c' or futureLink='a' or futureLink='l')and (year<=currentYear)) then futureVector else currentVector
    SetDataVector(linkLayer+"|","[BA_LIMITA]",newVector,)

    //AB_LIMITM
    futureVector = GetDataVector(linkLayer+"|","[future AB_LIMITM]",)
    currentVector = GetDataVector(linkLayer+"|","[AB_LIMITM]",)
    newVector = if ((futureLink='c' or futureLink='a' or futureLink='l')and (year<=currentYear)) then futureVector else currentVector
    SetDataVector(linkLayer+"|","[AB_LIMITM]",newVector,)

    //BA_LIMITM
    futureVector = GetDataVector(linkLayer+"|","[future BA_LIMITM]",)
    currentVector = GetDataVector(linkLayer+"|","[BA_LIMITM]",)
    newVector = if ((futureLink='c' or futureLink='a' or futureLink='l')and (year<=currentYear)) then futureVector else currentVector
    SetDataVector(linkLayer+"|","[BA_LIMITM]",newVector,)

    //AB_LIMITP
    futureVector = GetDataVector(linkLayer+"|","[future AB_LIMITP]",)
    currentVector = GetDataVector(linkLayer+"|","[AB_LIMITP]",)
    newVector = if ((futureLink='c' or futureLink='a' or futureLink='l')and (year<=currentYear)) then futureVector else currentVector
    SetDataVector(linkLayer+"|","[AB_LIMITP]",newVector,)

    //BA_LIMITP
    futureVector = GetDataVector(linkLayer+"|","[future BA_LIMITP]",)
    currentVector = GetDataVector(linkLayer+"|","[BA_LIMITP]",)
    newVector = if ((futureLink='c' or futureLink='a' or futureLink='l')and (year<=currentYear)) then futureVector else currentVector
    SetDataVector(linkLayer+"|","[BA_LIMITP]",newVector,)

    //AB_FNCLASS
    futureVector = GetDataVector(linkLayer+"|","[future AB funcclass]",)
    currentVector = GetDataVector(linkLayer+"|","[AB_FNCLASS]",)
    newVector = if ((futureLink='c' or futureLink='a' or futureLink='l')and (year<=currentYear)) then futureVector else currentVector
    SetDataVector(linkLayer+"|","[AB_FNCLASS]",newVector,)

    //BA_FNCLASS
    futureVector = GetDataVector(linkLayer+"|","[future BA funcclass]",)
    currentVector = GetDataVector(linkLayer+"|","[BA_FNCLASS]",)
    newVector = if ((futureLink='c' or futureLink='a' or futureLink='l')and (year<=currentYear)) then futureVector else currentVector
    SetDataVector(linkLayer+"|","[BA_FNCLASS]",newVector,)

    CloseView(linkLayer)
    CloseView(nodeLayer)
    Return(tempFile)

EndMacro

Macro "Export Highway Line Layer" (tempFile,scenarioFile)

   // Use the temp line scope to create a temporary map
   dbInfo = GetDBInfo(tempFile)
   newmap = CreateMap("TempMap",{{"Scope",dbInfo[1]}})
   // Add the Network Roads layer to the map and make it visible
   linkLayer = AddLayer("TempMap","NewLinks",tempFile,"Links")
   SetLayerVisibility(linkLayer,"True")
   SetLayer(linkLayer)

   // Prepare the line field names for the new geography
   newLinkFields = null
   fields = GetFields(,"All")
   for j = 1 to fields[1].length do

      fieldName = fields[1][j]

      // Exclude the year-specific fields
      temp = Position(fieldName,"future")

        //save the future link field
      if(fieldName="[future link]") then temp=0

      // Update the newFields array
      if temp=0 then newLinkFields = newLinkFields + {linkLayer+"." + (fields[1][j])}

   end

   // Add the Nodes layer to the map and make it visible
   nodeLayer = AddLayer("TempMap","Nodes",tempFile,"Nodes")
   SetLayerVisibility(nodeLayer,"True")
   SetLayer(nodeLayer)

   // Prepare the node field names for the new geography
   nodeFields = GetFields(,"All")

   // Export geography to the highway line layer
   ExportGeography("NewLinks|",scenarioFile,
                  { {"Layer Name","Oahu Links"}, {"Field Spec",newLinkFields},
                  	{"Node Name","Oahu Nodes"}, {"Node Field Spec",nodeFields[2]} })

   CloseMap("TempMap")


    Return(1)

EndMacro

Macro "Copy Layer Settings" (originFile,scenarioFile)

    path = SplitPath(originFile)
    originFiles = { path[1]+path[2]+path[3]+".st1",
                    path[1]+path[2]+path[3]+".sty" }

    path = SplitPath(scenarioFile)
    destFiles = { path[1]+path[2]+path[3]+".st1",
                  path[1]+path[2]+path[3]+".sty" }

    for i = 1 to originFiles.length do
        CopyFile(originFiles[i],destFiles[i])
    end

    arrayOpts = {
        "Alignment",                    //1
        "Color",                        //2
        "Font",                         //3
        "Framed",                       //4
        "Kern To Fill",                 //5
        "Left/Right",                   //6
        "Priority Expression",          //7
        "Rotation",                     //8
        "Set Priority",                 //9
        "Smart",                        //10
        "Uniqueness",                   //11
        "Visibility"                    //12
    }

    arrayOpts = {
        "Alignment",
        "Alternate Field",
        "Color",
        "Font",
        "Format",
        "Frame Border Style",
        "Frame Border Color",
        "Frame Border Width",
        "Frame Fill Color",
        "Frame Fill Style",
        "Frame Shield",
        "Frame Type",
        "Framed",
        "Kern To Fill",
        "Left/Right",
        "Line Length Limit",
        "Priority Expression",
        "Rotation",
        "Scale",
        "Set Priority",
        "Smart",
        "Uniqueness",
        "Visibility"
    }

    // Use the temp line scope to create a temporary map
    dbInfo = GetDBInfo(originFile)
    newmap = CreateMap("OriginMap",{{"Scope",dbInfo[1]}})
   // Get the layer names
    dbLayers = GetDBLayers(originFile)

    // Add the master Roads layer to the map and make it visible
    link_lyr = AddLayer("OriginMap","Links",originFile,dbLayers[2])
    // label_exp = GetLabelExpression(link_lyr+"|")
    // opts = GetLabelOptions(link_lyr+"|", arrayOpts)

    // Create a new map
    dbInfo_dest = GetDBInfo(scenarioFile)
    destmap = CreateMap("DestMap",{{"Scope",dbInfo_dest[1]}})
    dbLayers_dest = GetDBLayers(scenarioFile)

   // Add the scenario Roads layer to the map and make it visible
    link_lyr_dest = AddLayer("DestMap","Links",scenarioFile,dbLayers_dest[2])
    // SetLabels(link_lyr_dest+"|", label_exp, opts)
    // SetLabelOptions(link_lyr_dest+"|", opts)

    RunMacro("Close All")

    Return(1)
EndMacro

Macro "Export Transit Routes" (masterRouteFile,masterLineFile,scenarioLineFile,scenarioNetworkDirectory,extractString)

    // Add the transit layers
    {rs_lyr, stop_lyr, ph_lyr} = RunMacro("TCB Add RS Layers",masterRouteFile, "ALL",)

     // Make sure route system references master line layer
     // Kyle: Never modify the master networks from the script.  Instead, check and throw error.
     //       User must fix manually if there is an issue (so they know about the change).
    dbLayers = GetDBLayers(masterLineFile)
    a_rsInfo = GetRouteSystemInfo(masterRouteFile)
    if a_rsInfo[1] <> masterLineFile then do
        Throw("The master route system is not based on the master highway network. Use 'Route Systems' -> 'Utilities' -> 'Move' to fix. ")
    end

    // The new route file name
    scenarioRouteFile=scenarioNetworkDirectory+"\\Scenario Route System"

   // Create the selection set of relevant routes
    setname = "routesquery"
    queryString = "Select * where " + extractString
    n = SelectByQuery(setname,  "Several", queryString,)

    // Copy the selected routes in the transit layer to the new directory
    RunMacro("TC40 create Route System subset ex", rs_lyr, setname, null, null, 1, False, null, scenarioRouteFile)

     // Make sure route system references scenario line layer
    dbLayers = GetDBLayers(scenarioLineFile)
    ModifyRouteSystem(scenarioRouteFile, {{"Geography", scenarioLineFile, dbLayers[2]}})

    // close all maps
    maps = GetMapNames()
    for i = 1 to maps.length do
     CloseMap(maps[i])
    end

    // Add the transit layers
    {rs_lyr, stop_lyr, ph_lyr} = RunMacro("TCB Add RS Layers",scenarioRouteFile, "ALL",)

    n = SelectByQuery(setname,  "Several", "Select * where Route_ID>0",)
    n = SelectByQuery(setname,  "Less", queryString,)
    if n > 0 then DeleteRecordsInSet(setname)

    // close all maps
    maps = GetMapNames()
    for i = 1 to maps.length do
     CloseMap(maps[i])
    end

   //ShowMessage("Please reload scenario route system and verify to ensure that there are no errors!")

    Return(1)

EndMacro

Macro "Fill Stop Attributes" (hwyfile, rtsfile, rstopfile)

    // RunMacro("TCB Init")

    path = SplitPath(rtsfile)
    rtsfile1=path[1]+path[2]+path[3]+"R.bin"

    {node_lyr, link_lyr} = RunMacro("TCB Add DB Layers", hwyfile,,)
    {rte_lyr,stp_lyr,} = RunMacro("TCB Add RS Layers", rtsfile, "ALL", )

    rtsfile1_nm=ParseString(rtsfile1,"\\.")

    // Add fields to the stop layer
    a_fields = {
      {"RTE_NUMBER", "String", 30, ,,,,},
      {"RTE_NAME", "String", 30, ,,,,},
      {"MODE", "Integer", 10, ,,,,},
      {"EA_HEADWAY", "Integer", 10, ,,,,},
      {"AM_HEADWAY", "Integer", 10, ,,,,},
      {"MD_HEADWAY", "Integer", 10, ,,,,},
      {"PM_HEADWAY", "Integer", 10, ,,,,},
      {"EV_HEADWAY", "Integer", 10, ,,,,}
    }
    RunMacro("Add Fields", stp_lyr, a_fields)

    Opts = null
    Opts.Input.[Dataview Set] = {{stp_lyr, rtsfile1, {"Route_ID"}, {"Route_ID"}}, "joinedvw111"}
            Opts.Global.Fields = {stp_lyr+".RTE_NUMBER",
        	                    stp_lyr+".RTE_NAME",
        	                    stp_lyr+".MODE",
        	                    stp_lyr+".EA_HEADWAY",
        	                    stp_lyr+".AM_HEADWAY",
        	                    stp_lyr+".MD_HEADWAY",
        	                    stp_lyr+".PM_HEADWAY",
        	                    stp_lyr+".EV_HEADWAY"}                           // the field to fill
    Opts.Global.Method = "Formula"                                          // the fill method
    Opts.Global.Parameter = {"["+rtsfile1_nm[rtsfile1_nm.length-1]+"]"+".RouteNumber",
    	                       "["+rtsfile1_nm[rtsfile1_nm.length-1]+"]"+".Route_Name",
    	                       "["+rtsfile1_nm[rtsfile1_nm.length-1]+"]"+".Mode",
    	                       "["+rtsfile1_nm[rtsfile1_nm.length-1]+"]"+".EA_Headway",
     	                       "["+rtsfile1_nm[rtsfile1_nm.length-1]+"]"+".AM_Headway",
    	                       "["+rtsfile1_nm[rtsfile1_nm.length-1]+"]"+".MD_Headway",
    	                       "["+rtsfile1_nm[rtsfile1_nm.length-1]+"]"+".PM_Headway",
    	                       "["+rtsfile1_nm[rtsfile1_nm.length-1]+"]"+".EV_Headway"}


    ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
    if !ret_value then Throw()

    Opts = null

    Opts.Input.[Dataview Set] = {{stp_lyr, rtsfile1, {"Route_ID"}, {"Route_ID"}}, "joinedvw111"}
        Opts.Global.Fields = {stp_lyr+".Stop_Flag"}                           // the field to fill
    Opts.Global.Method = "Value"                                          // the fill method
    Opts.Global.Parameter = {1}                                // the column in the fspdfile

    ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
    if !ret_value then Throw()

    // close all maps
    maps = GetMapNames()
    for i = 1 to maps.length do
     CloseMap(maps[i])
    end

    Return(1)



EndMacro

Macro "Assign PNR Lots" (tempFile,currentYear,extractPNRString)

    // Check that the files exist
    //		- master line
    if GetFileInfo(tempFile) = null then do
        ShowMessage("File not found: " + tempFile)
        Return()
    end

		//currentYear = stringtoint(currentYear)

   // Get the Node layer
   {nodeLayer,linkLayer} = RunMacro("TCB Add DB Layers", tempFile,,)

    SetLayer(nodeLayer) //Node Layer
    queryString = "Select * where " + extractPNRString

    n1 = SelectByQuery("PNR", "Several", queryString,)
	    if n1 > 0 then do
            Opts = null
            Opts.Input.[Dataview Set] = {tempFile+"|"+nodeLayer, nodeLayer, "PNR"}
            Opts.Global.Fields = {"PNR"}
            Opts.Global.Method = "Value"
            Opts.Global.Parameter = {"1"}
            ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
            if !ret_value then Throw()
			end
    CloseView(linkLayer)
    CloseView(nodeLayer)
    Return(tempFile)




EndMacro



/*
Kyle: Major revision to the management of highway projects.  The new
system uses a csv of project IDs included in the scenario directory.
Links with the corresponding ID in field "ProjID" have their base
attributes updated with project attributes.  Finally, links are
deleted if they have zero lanes in all periods (except transit only).
*/
Macro"Update Project Links" (tempFile,year,ScenarioDirectory)

    // Get list of project IDs in this scenario
    projListCSV = ScenarioDirectory + "\\ProjectList.csv"
    projTbl = OpenTable("projTbl","CSV",{projListCSV})
    v_projIDs = GetDataVector(projTbl + "|","ProjID",)
    CloseView(projTbl)

    // Only continue if there were project IDs listed in the csv
    if v_projIDs.length > 0 then do

        // Add the scenario network to the workspace
        {nlayer,llayer} = GetDBLayers(tempFile)
        llayer = AddLayerToWorkspace(llayer,tempFile,llayer)

        // Create a selection set of links that will have their attributes
        // updated based on project info
        SetLayer(llayer)
        for i = 1 to v_projIDs.length do
            id = v_projIDs[i]

            qry = "Select * where ProjID = " + String(id)
            SelectByQuery("projlinks","more",qry)
        end

        // These arrays create the field names where project info is stored
        // In the highway network
        a_attributes = {"LANE","LIMIT","FNCLASS"}
        a_dir = {"AB","BA"}
        a_periods = {"A","M","P"}

        for a = 1 to a_attributes.length do
            attr = a_attributes[a]

            for d = 1 to a_dir.length do
                dir = a_dir[d]

                for p = 1 to a_periods.length do
                    per = a_periods[p]

                    // FNCLASS isn't by time period
                    if attr = "FNCLASS" then baseField = dir + " " + attr else
                    baseField = dir + " " + attr + per
                    projField = "f" + baseField

                    // Collect project info and set it into base year field
                    v_projInfo = GetDataVector(llayer + "|projlinks",projField,)
                    SetDataVector(llayer + "|projlinks", baseField,v_projInfo,)

                    // In addition, build a query to find 0-lane links
                    if attr = "LANE" then do
                        if delQry = null then delQry = "Select * where nz([" + baseField + "]) = 0"
                        else delQry = delQry + " and nz([" + baseField + "]) = 0"
                    end
                end
            end
        end

        // Delete links with 0 lanes throughout the day
        // that aren't transit-only links
        delQry = delQry + " and [AB FACTYPE] <> 14"
        n = SelectByQuery("toDelete","Several",delQry)
        if n > 0 then DeleteRecordsInSet("toDelete")
    end
    return(tempFile)
EndMacro
