
dbox "Oahu Model" 
      
//***************************This part of the code is for initial set up*************************************************************************
    right, center toolbox NoKeyboard
    title: "OAHU Model"


	init do
        Shared path, Options, year, seYear
        dim path[14]                      // path of the master network directories and the scenario directory
        dim Options[10]                    // OPtions in GUI, like Stop after each stage...
        Options[9] = "8"                    // Default value for max-iteration is 8
        Options[6] = "1"                    // Default value for iteration is 1
//        dim year                        // scenario year
		RunMacro("TCB Init")
		path[1] = "C:\\Projects\\Ompo\\Conversion\\Application\\"
//        LoadResourceFile(,"C:\\Projects\\Ompo\\Conversion\\Application\\scripts\\tazmanager.rsc",)
		enditem
	close do
		return()
		enditem
                        
    button  0, 0 icon: "bmp\\Oahu.bmp"
                        
//***************************This part of the code sets up the Scenario directory *************************************************************************
                        
    Frame 1, 8.5, 45, 6.2 Prompt: "Scenario Directory"	

//    Edit Int "num iter item" 25, 14, 10
//        prompt: "Enter the Scenario Year"
//    variable: parameter[3]

	text 3, 10, 35 variable: path[2] prompt: " " framed
//	text "                " 59, 15

	button ".." 41, 10 icons: "bmp\\buttons|114.bmp" do
	    on error, notfound, escape do
            goto nodir
        end
		path[2] = ChooseDirectory("Choose a Scenario Directory", {{"Initial Directory", "C:\\Projects\\Ompo\\Conversion\\Application\\generic\\"}})
		path[2] = path[2]
//		ShowMessage(path[1])
        nodir:
            on error, notfound, escape default
		enditem

	button "Scenario Manager" 3, 12, 41, 1.5 do
//        LoadResourceFile(, "tazmanager.rsc", )
	    RunMacro("SetDirectoryDefaults")
        RunDbox("Scenario Manager")
	enditem


//***************************This part of the code sets up the Options in the model*************************************************************************

//    Frame 1, 16.5, 45, 7 Prompt: "OPTIONS"	

    Frame 1, 14.7, 45, 9 Prompt: "OPTIONS"	

    Checkbox 3, 16.0 prompt: "Stop after each stage" variable: Options[1]

    Checkbox 3, 17.2 prompt: "Toll present" variable: Options[2]

    Checkbox 3, 18.4 prompt: "Fixed-Guideway present" variable: Options[3]

    Checkbox 3, 19.6 prompt: "Write User Benefits" variable: Options[4]

    Checkbox 3, 20.8 prompt: "Stop after each iteration" variable: Options[5]
        
    Checkbox 3, 22.0 prompt: "Cordon Pricing" variable: Options[10]
    

    Popdown Menu "num iter item" 40, 17.5, 4.5
        Editable
        prompt: "Start At Iter"
        list: {1,2,3,4,5,6,7,8}
    variable: Options[6]              
    
    Popdown Menu "num iter item" 40, 19.5, 4.5
        Editable
        prompt: "Max Iterations"
        list: {1,2,3,4,5,6,7,8}
    variable: Options[9]              
        
  	
  	
//***************************This part of the code sets up the Stages of the model*************************************************************************
	
    Frame 1, 24, 45, 32 Prompt: "STAGES"	
	
	button  3, 25.5 icon: "bmp\\plannetwork.bmp"
	button "Prepare Network" 18, 25.5, 26, 1.5 do
	    jump = "UpdateLineLayer"
	    RunMacro("OMPO6", path, Options, jump)
	enditem
    
    button  3, 28 icon: "bmp\\planskim.bmp"
	button "Create Highway Skims" 18, 28, 26, 1.5 do
	    jump = "HighwaySkim"
	    RunMacro("OMPO6", path, Options, jump)
	enditem
    
    button  3, 30.5 icon: "bmp\\TS.bmp" do
	 	     maps = GetMapNames()
	 	     views = GetViewNames()
	 	     if((maps <> null) or (views <> null)) then do 
	 	         ret_value = RunMacro("Close All")
				 end
				 else do
	 	 	 	      	// add the hwyfile, and make the route system refer to it
            		hwyfile=path[2]+ "\\inputs\\network\\Scenario Line Layer.dbd"
            		rtsfile=path[2]+ "\\inputs\\network\\Scenario Route System.rts"
	 	 	 	      	baselyrs = GetDBLayers(hwyfile)
	 	 	 	      	ModifyRouteSystem(rtsfile, {{"Geography", hwyfile, baselyrs[2]}, {"Link ID", "ID"}})    
	 	 	 	      	// create a map and add the route system layer to it, change some display settings
	 	 	 	      	aa = GetDBInfo(hwyfile)
	 	 	 	      	cc = CreateMap("bb",{{"Scope",aa[1]}})
	 	 	 	      	lyrs=AddRouteSystemLayer(cc, "Route System", rtsfile,{})
	 	 	 	      	RunMacro("Set Default RS Style", lyrs, "True", "True")
	 	 	 	      	if getlayervisibility(lyrs[5])= "Off" then SetLayerVisibility(lyrs[5], "True")
	 	 	 	      	SetLayerVisibility(lyrs[4], "True")   
	 	 	 	 end
     enditem    

	button "Create Transit Skims" 18, 30.5, 26, 1.5 do
	    jump = "TransitSkim"
	    RunMacro("OMPO6", path, Options, jump)
	enditem
    
    button  3, 33 icon: "bmp\\plantripgen.bmp" do
	 	     maps = GetMapNames()
	 	     views = GetViewNames()
	 	     if((maps <> null) or (views <> null)) then do 
   	 	         ret_value = RunMacro("Close All")
				 end
				 else do
                scenarioTAZFile = path[2] + "\\inputs\\taz\\Scenario TAZ Layer.DBD"
                dbInfo = GetDBInfo(scenarioTAZFile)
                dbLayers = GetDBLayers(scenarioTAZFile)
                newmap = CreateMap("TempMap",{{"Scope",dbInfo[1]}})
                tazLayer=AddLayer("TempMap","Oahu_TAZs",scenarioTAZFile,dbLayers[1])
                SetLayerVisibility(tazLayer,"True")
                
                //path[2] + "\\inputs\\taz\\hdistrib.ASC"
                fptr = OpenFile(path[2] + "\\inputs\\taz\\hdistrib.ASC", "r")


                //path[2] + "\inputs\taz\Scenario TAZ Layer.ASC"
                //HDistrib  = OpenTable("FutureYearData", "FFB", {HDistrib,null}, {{"Shared", "True"}})   
    						//baseYearDistrib = OpenTable("BaseYearDistrib", "FFB", {baseYearHHFile,null}, {{"Shared", "True"}})

				end
	 enditem	
	button "Special Market Models" 18, 33, 26, 1.5 do
	    jump = "SpecialMarket"
	    RunMacro("OMPO6", path, Options, jump)
	enditem
    
    button  3, 35.5 icon: "bmp\\plantripdist.bmp"
	button "Tour-Based Models" 18, 35.5, 26, 1.5 do
	    jump = "TourBasedModels"
	    RunMacro("OMPO6", path, Options, jump)
	enditem
    
    button  3, 38 icon: "bmp\\TOD.bmp"
	button "Time of Day" 18, 38, 26, 1.5 do
	    jump = "TimeOfDay"
	    RunMacro("OMPO6", path, Options, jump)
	enditem
    
    button  3, 40.5 icon: "bmp\\planassign.bmp"
	button "Highway Assignment" 18, 40.5, 26, 1.5 do
	    jump = "HighwayAssign"
	    RunMacro("OMPO6", path, Options, jump)
	enditem
    
    button  3, 43 icon: "bmp\\TA.bmp"
	button "Transit Assignment" 18, 43, 26, 1.5 do
	    jump = "TransitAssign"
	    RunMacro("OMPO6", path, Options, jump)
	enditem
            
    button  3, 45.5 icon: "bmp\\planmatrix.bmp"
	button "Summaries" 18, 45.5, 26, 1.5 do
	    jump = "Summaries"
	    RunMacro("OMPO6", path, Options, jump)
	enditem
	
	button  3, 48 icon: "bmp\\DTA.bmp"
	button "Run DTA" 18, 48, 26, 1.5 do
	    jump = "DTArun"
	    RunMacro("OMPO6", path, Options, jump)
	enditem

//**********************************************************************************************************************************************************************

	button "Quit" 10, 53, 24, 1.5 cancel do
		//ShowMessage(" Exit")
		Return() 
	enditem

    text "                " 1, 54.1
    
    
EndDbox


Dbox "Scenario Manager"

	init do
        Shared path, Options, year, seYear
	selection = 1
		enditem
	close do
		return()
		enditem
    
    Frame 1, .5, 65, 4.25 Prompt: "INPUTS"	
    
    Edit Int "rdwy year item" 15, 1.75, 10, 1
        prompt: "Transit Year"
    variable: year
    Edit Int "rdwy year item" same, after, 10, 1
        prompt: "SE Year"
    variable: seYear
    button "?" 26, 1.75, 3 do
        ShowMessage("The transit routes and PNR lots\nhave a start and stop year.")
        ShowMessage("The highway projects are controlled\nwith the ProjectList.csv")
    enditem
	button "Inputs" 34, 2, 29, 1.5 do
	    RunDbox("Inputs")
	enditem
    
    Frame 1, 5.5, 65, 3.5 Prompt: "Scenario Directory"
	text 16, 7.2, 43 variable: path[2] prompt: " " framed
    button "Copy" 3, 7, 10, 1.5 do
        RunDbox("Copy_Scenario")     
	enditem
	
	button ".." 61, 7.2 icons: "bmp\\buttons|114.bmp" do
	    on error, notfound, escape do
            goto nodir
        end    
		path[2] = ChooseDirectory("Choose a Scenario Directory",{{"Initial Directory", "C:\\Projects\\Ompo\\Conversion\\Application\\generic\\"}} )
		path[2] = path[2]
        nodir:
            on error, notfound, escape default
		enditem

Radio List 1, 9.5, 66, 3.5 Prompt: "TAZ Data" Variable: selection
Radio Button 2, 10.5 Prompt: "Use Data from Excel"
Radio Button 2, 12 Prompt: "Use Data From Urbansim"


	button "Create TAZ Data" 32, 10.5, 31, 2 do
		if selection = 2 then do
			Showmessage("Insert the UrbanSIM model here")
		end
		if selection = 1 then do
        		RunMacro("Create TAZ File")
		end     
	enditem

	button "Create Network" 3, 14, 61, 2 do
	    RunMacro("Create Network", path, Options, year)
        ShowMessage("Network Created")
	enditem

//*************************This part of the code is for Navigation**************************************************************************************************************************


	button "OK" 7, 17.5, 20, 2 do
		//ShowMessage(" Exit")
		Return() 
	enditem

	button "Cancel" 38, 17.5, 20, 2 cancel do
		//ShowMessage(" Exit")
		Return() 
	enditem
 
    text "                " 1, 18.5
    

EndDbox

//Macro "TAZ"
//    RunProgram('rscc -c -u "C:\\Projects\\Ompo\\Conversion\\Application\\scripts\\tazmanager.dbd", "C:\\Projects\\Ompo\\Conversion\\Application\\scripts\\tazmanager..rsc" ', )
//EndMacro

Dbox "Inputs"

//***************************This part of the code is for initial set up*************************
    Left, center toolbox NoKeyboard
    title: "OAHU Model"
        
	init do
        Shared path, Options, year, seYear
		enditem
	close do
		return()
		enditem

//	Text "Please specify the directories" 5, 0.5
	button "Set all directories to default" 5, 0.8, 31, 1.2 do
        RunMacro("SetDirectoryDefaults")
	enditem

	button "Set Directories using Generic" 5, 6.1, 55, 1.2 do
//	    ShowMessage("This will fill all the directory paths with the default paths")
        if path[3] <> "" then do
    	    path[4] = path[3] + "inputs\\master_network\\"
    	    path[5] = path[3] + "inputs\\turn penalties\\"
	        path[6] = path[3] + "inputs\\other\\"
	        path[7] = path[3] + "inputs\\taz\\"
    	    path[8] = path[3] + "controls\\"
	        path[9] = path[3] + "programs\\"
	        path[10] =path[3] + "temp\\"
	        path[11] =path[3] + "scripts\\"
	        path[12] =path[3] + "DTA\\"
	    end
	enditem
    
    button "Re-Set All the Directories" 40, 0.8, 21, 1.2 do
    //	    ShowMessage("This will clear all the directory paths")
        path[3] = ""
	    path[4] = ""
	    path[5] = ""
	    path[6] = ""
	    path[7] = ""
	    path[8] = ""
	    path[9] = ""
	    path[10] = ""
	    path[11] = ""
	    path[12]= ""
	enditem
	
	Frame 1, 2.3, 65, 2.9 Prompt: "Generic Directory"	
	text 3, 3.5, 55 variable: path[3] prompt: " " framed
	button ".." 61, 3.5 icons: "bmp\\buttons|114.bmp" do
	    on error, notfound, escape do
            goto nodir
        end
		path[3] = ChooseDirectory("Specify the Generic directory",{{"Initial Directory", "C:\\Projects\\Ompo\\Conversion\\Application\\generic\\"}} )
		if path[3] <> "" then do
		    path[3] = path[3] + "\\"
		end
        nodir:
            on error, notfound, escape default
		enditem
    
	Frame 1, 7.6, 65, 2.9 Prompt: "Master Line Layer Directory"	
	text 3, 8.8, 55 variable: path[4] prompt: " " framed
	button ".." 61, 8.8 icons: "bmp\\buttons|114.bmp" do
	    on error, notfound, escape do
            goto nodir
        end
		path[4] = ChooseDirectory("Specify the Master line layer directory", )
		    path[4] = path[4] + "\\"
        nodir:
            on error, notfound, escape default
		enditem
    
    Frame 1, 11.1, 65, 2.9 Prompt: "Turns Directory"	
	text 3, 12.3, 55 variable: path[5] prompt: " " framed
	button ".." 61, 12.3 icons: "bmp\\buttons|114.bmp" do
	    on error, notfound, escape do
            goto nodir
        end
		path[5] = ChooseDirectory("Specify the Turns directory", )
		path[5] = path[5] + "\\"
        nodir:
            on error, notfound, escape default
		enditem

   Frame 1, 14.6, 65, 2.9 Prompt: "Other Inputs Directory"	
	text 3, 15.8, 55 variable: path[6] prompt: " " framed
	button ".." 61, 15.8 icons: "bmp\\buttons|114.bmp" do
	    on error, notfound, escape do
            goto nodir
        end
		path[6] = ChooseDirectory("Specify the Other Inputs directory", )
		path[6] = path[6] + "\\"
        nodir:
            on error, notfound, escape default
		enditem

   Frame 1, 18.1, 65, 2.9 Prompt: "TAZ Data Directory"	
	text 3, 19.3, 55 variable: path[7] prompt: " " framed
	button ".." 61, 19.3 icons: "bmp\\buttons|114.bmp" do
	    on error, notfound, escape do
            goto nodir
        end
		path[7] = ChooseDirectory("Specify the TAZ Data Directory", )
		path[7] = path[7] + "\\"
        nodir:
            on error, notfound, escape default
		enditem

   Frame 1, 21.6, 65, 2.9 Prompt: "Controls Directory"	
	text 3, 22.8, 55 variable: path[8] prompt: " " framed
	button ".." 61, 22.8 icons: "bmp\\buttons|114.bmp" do
	    on error, notfound, escape do
            goto nodir
        end
		path[8] = ChooseDirectory("Specify the Controls Directory", )
		path[8] = path[8] + "\\"
        nodir:
            on error, notfound, escape default
		enditem

   Frame 1, 25.1, 65, 2.9 Prompt: "Programs Directory"	
	text 3, 26.3, 55 variable: path[9] prompt: " " framed
	button ".." 61, 26.3 icons: "bmp\\buttons|114.bmp" do
	    on error, notfound, escape do
            goto nodir
        end
		path[9] = ChooseDirectory("Specify the Programs Directory", )
		path[9] = path[9] + "\\"
        nodir:
            on error, notfound, escape default
		enditem

   Frame 1, 28.6, 65, 2.9 Prompt: "Temp Directory"	
	text 3, 29.8, 55 variable: path[10] prompt: " " framed
	button ".." 61, 29.8 icons: "bmp\\buttons|114.bmp" do
	    on error, notfound, escape do
            goto nodir
        end
		path[10] = ChooseDirectory("Specify the Temp Directory", )
		path[10] = path[10] + "\\"
        nodir:
            on error, notfound, escape default
		enditem

   Frame 1, 32.1, 65, 2.9 Prompt: "Scripts Directory"	
	text 3, 33.3, 55 variable: path[11] prompt: " " framed
	button ".." 61, 33.3 icons: "bmp\\buttons|114.bmp" do
	    on error, notfound, escape do
            goto nodir
        end
		path[11] = ChooseDirectory("Specify the Scripts Directory", )
		path[11] = path[11] + "\\"
        nodir:
            on error, notfound, escape default
		enditem
		
	Frame 1, 35.6, 65, 2.9 Prompt: "DTA Directory"	
	text 3, 36.8, 55 variable: path[12] prompt: " " framed
	button ".." 61, 36.8 icons: "bmp\\buttons|114.bmp" do
	    on error, notfound, escape do
            goto nodir
        end
		path[11] = ChooseDirectory("Specify the DTA Directory", )
		path[11] = path[12] + "\\"
        nodir:
            on error, notfound, escape default
		enditem

	button "OK" 7, 39, 20, 2 do
		//ShowMessage(" Exit")
		Return() 
	enditem

	button "Cancel" 38, 39, 20, 2 cancel do
		//ShowMessage(" Exit")
		Return() 
	enditem

   text "                " 1, 38

EndDbox

DBox "Copy_Scenario"

	init do
        Shared path
		enditem
	close do
		return()
		enditem
		
	Frame 1, 1, 48, 5 Prompt: "Copy Scenario Directory"	
    text "Copy File" 3, 2.5
	text 15, 2.5, 25 variable: path[12] prompt: " " framed
	button ".." 42, 2.5 icons: "bmp\\buttons|114.bmp" do
	    on error, notfound, escape do
            goto nodir
        end
		path[12] = ChooseDirectory("Specify the Model directory", )
		if path[12] = "" then do
		    Return()
		end
        nodir:
            on error, notfound, escape default
		enditem
//		enditem

    text "Copy To" 3, 4.5
	text 15, 4.5, 25 variable: path[13] prompt: " " framed
	button ".." 42, 4.5 icons: "bmp\\buttons|114.bmp" do
	    on error, notfound, escape do
            goto nodir
        end
		path[13] = ChooseDirectory("Specify the Model directory", )
		if path[13] = "" then do
		    //path[13] = path[13] + "\\"
		end
        nodir:
            on error, notfound, escape default
		enditem
//		enditem
	button "OK" 7, 8, 14, 1.5 do
		//ShowMessage(" Exit")
  		RunProgram("cmd.exe /c xcopy "+path[12]+" "+path[13]+"/s/e/i",)
		Return() 
	enditem

	button "Cancel" 28, 8, 14, 1.5 cancel do
		//ShowMessage(" Exit")
		Return() 
	enditem

    text "                " 1, 9.5
    
EndDbox
    

// Kyle: added this
Macro "SetDirectoryDefaults"
    shared path
    
    uiDir = GetInterface()
    a_temp = SplitPath(uiDir)
    // Don't use the ".." parent directory notation because it causes problems when
    // comparing path strings later in the model.
    // genericDir = a_temp[1] + a_temp[2] + "..\\"
    a_split = ParseString(a_temp[2],"\\")
    for i = 1 to a_split.length - 1 do
        string = string + "\\" + a_split[i]
    end
    genericDir = a_temp[1] + string + "\\"
    
    path[3] = genericDir
    path[4] = genericDir + "inputs\\master_network\\"
    path[5] = genericDir + "inputs\\turn penalties\\"
    path[6] = genericDir + "inputs\\other\\"
    path[7] = genericDir + "inputs\\taz\\"
    path[8] = genericDir + "controls\\"
    path[9] = genericDir + "programs\\"
    path[10] =genericDir + "..\\temp\\"
    path[11] =genericDir + "scripts\\"
    path[12] =genericDir + "DTA\\"
EndMacro
