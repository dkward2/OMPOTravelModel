/*

*/

dBox "EJ"

  toolbox NoKeyboard
  title: "EJ Analysis Toolbox"

  init do
    shared scen_dir, path, ej_dir, output_dir

    // Set the scen_dir to the currently selected scenario
    // if there is one.
    scen_dir = path[2]
    if scen_dir <> null then do
      if !RunMacro("Is Scenario Run?", scen_dir)
        then scen_dir = null
        else output_dir = scen_dir + "/reports/ej"
    end

    // Determine UI location, initial search dir, and ej dir
    uiDBD = GetInterface()
    a_path = SplitPath(uiDBD)
    ui_dir = a_path[1] + a_path[2]
    init_dir = ui_dir + "../../scenarios"
    init_dir = RunMacro("Resolve Path", init_dir)
    ej_dir = ui_dir + "/../ej"
    ej_dir = RunMacro("Resolve Path", ej_dir)
  enditem

  // Explanatory text
  button 50, 1 prompt: " ? " do
    message = "This tool will re-assign trips stratified by\n" +
      "race and income. The scenario chosen must already have\n" +
      "been run through the standard model (with full feedback)."
    ShowMessage(message)
  enditem

  // Scenario folder (and report directory)
  text 1, 3, 35 variable: scen_dir prompt: "Scenario Directory" framed
  button ".." after, same icons: "bmp\\buttons|114.bmp" do
    on error, notfound, escape goto nodir
    opts = null
    opts.[Initial Directory] = init_dir
    scen_dir = ChooseDirectory("Choose the directory to analyze.", opts)
    output_dir = scen_dir + "/reports/ej"
    if !RunMacro("Is Scenario Run?", scen_dir) then do
      scen_dir = null
      output_dir = null
    end
    nodir:
    on error, notfound, escape default
  enditem

  // Analyze Button
  button "Perform Analysis" 7, 7 do
    if scen_dir = null
      then ShowMessage("Select a scenario")
      else do
        CreateProgressBar("Performing EJ Analysis", "False")
        RunMacro("EJ Analysis")
        DestroyProgressBar()
        ShowMessage("EJ Analysis Complete")
      end
  enditem

  // Quit button
  button "Quit" after, same, 15 do
    return()
  enditem
EndDbox

Macro "Is Scenario Run?" (scen_dir)

  test_file = scen_dir + "/reports/VMT and Speeds by FT and AT.csv"
  if GetFileInfo(test_file) = null
    then do
      ShowMessage(
        "Selected scenario has not been run\n" +
        "(File: 'VMT and Speeds by FT and AT.csv' does not exist.)"
      )
      return("False")
    end else return("True")
EndMacro

/*

*/

Macro "EJ Analysis"

  RunMacro("Create EJ Trip Table")
  RunMacro("EJ CSV to MTX")
  RunMacro("EJ Assignment")
  RunMacro("EJ Mapping")
EndMacro

/*

*/

Macro "Create EJ Trip Table"
  shared scen_dir, ej_dir, output_dir
  UpdateProgressBar("Create EJ Trip Table", 0)

  // Create output_dir if it doesn't exist
  if GetDirectoryInfo(output_dir, "All") = null then CreateDirectory(output_dir)

  // Read in the ej param files
  mode_df = CreateObject("df")
  mode_df.read_csv(ej_dir + "/mode_codes.csv")
  period_df = CreateObject("df")
  period_df.read_csv(ej_dir + "/period_codes.csv")
  race_df = CreateObject("df")
  race_df.read_csv(ej_dir + "/race_codes.csv")

  // Read in the households csv
  a_fields = {"household_id", "income"}
  house_df = CreateObject("df")
  house_df.read_csv(scen_dir + "/inputs/taz/households.csv", a_fields)

  // Read in the persons csv
  a_fields = {"household_id", "pums_pnum", "race"}
  person_df = CreateObject("df")
  person_df.read_csv(scen_dir + "/inputs/taz/persons.csv", a_fields)

  // Read in the trip csv
  a_fields = {
    "hh_id", "person_id", "tripMode", "period",
    "originTaz", "destinationTaz", "expansionFactor"
  }
  trip_df = CreateObject("df")
  trip_df.read_csv(scen_dir + "/outputs/trips.csv", a_fields)

  // Join tables (and filter to AM)
  trip_df.left_join(period_df, "period", "Period")
  trip_df.rename("Value", "period2")
  trip_df.filter("period2 = 'AM'")
  trip_df.left_join(
    person_df,
    {"hh_id", "person_id"},
    {"household_id", "pums_pnum"}
  )
  trip_df.rename("race", "race_num")
  trip_df.left_join(house_df, "hh_id", "household_id")

  // Join the race description table
  trip_df.left_join(race_df, "race_num", "Race")
  trip_df.rename("Value", "race")

  // Calculate income group field
  trip_df.mutate(
    "IncGroup",
    if (trip_df.tbl.income < 25000) then "Low" else "NotLow"
  )

  // Remove any records missing income/race info
  trip_df.filter("race_num <> null")
  trip_df.filter("income <> null")

  // write final table to csv
  trip_df.write_csv(output_dir + "/ej_am_trips.csv")

  RunMacro("Close All")
EndMacro

/*

*/

Macro "EJ CSV to MTX"
  shared scen_dir, ej_dir, output_dir
  UpdateProgressBar("EJ CSV to MTX", 0)

  // Open the long-format trip table
  csv_file = output_dir + "/ej_am_trips.csv"
  vw_long = OpenTable("ej_long", "CSV", {csv_file})

  // For race and income separately
  a_type = {"race", "IncGroup"}
  for t = 1 to a_type.length do
    type = a_type[t]

    // read in the trip table and spread by type
    trip_df = CreateObject("df")
    opts = null
    opts.view = vw_long
    trip_df.read_view(opts)
    trip_df.spread(type, "expansionFactor", 0)
    csv_file = output_dir + "/ej_am_trips_by_" + type + ".csv"
    trip_df.write_csv(csv_file)
    vw = OpenTable("ej_" + type, "CSV", {csv_file})

    // Create a copy of the resident am matrix
    in_file = scen_dir + "/outputs/residentAutoTrips_AM.mtx"
    out_file = output_dir + "/ej_od_by_" + type + ".mtx"
    CopyFile(in_file, out_file)

    // Create an array of cores to remove
    mtx = OpenMatrix(out_file, )
    cores_to_remove = GetMatrixCoreNames(mtx)

    // Create a vector of unique groups
    vec = GetDataVector(vw_long + "|", type, )
    opts = null
    opts.Unique = "True"
    opts.[Omit Missing] = "True"
    a_groups = V2A(SortVector(vec, opts))

    // add a core for each unique group
    for i = 1 to a_groups.length do
      AddMatrixCore(mtx, a_groups[i])
    end

    // Remove the original cores
    for i = 1 to cores_to_remove.length do
      DropMatrixCore(mtx, cores_to_remove[i])
    end

    // Update the new cores with the trips
    SetView(vw)
    opts = null
    opts.[Missing is zero] = "True"
    UpdateMatrixFromView(
      mtx,
      vw + "|",
      "originTaz",
      "destinationTaz",
      ,
      a_groups,
      "Add",
      opts
    )

    CloseView(vw)
  end

  RunMacro("Close All")
EndMacro

/*
The settings are intended to mirror those found in highwayAssign.rsc
for the AM period.
*/

Macro "EJ Assignment"
  shared scen_dir, ej_dir, output_dir
  UpdateProgressBar("EJ Assignment", 0)

  // Input files and link exclusion
  hwy_dbd = scen_dir + "/inputs/network/Scenario Line Layer.dbd"
  {nlyr, llyr} = GetDBLayers(hwy_dbd)
  net = scen_dir + "/outputs/hwyAM.net"
  turn_pen = scen_dir + "\\inputs\\turns\\am turn penalties.bin"
  ab_limit = "[AB_LIMITA]"
  ba_limit = "[BA_LIMITA]"
  // Using the SOV link exclusion query for all matrix cores
  validlink = "(([AB FACTYPE]  between 1 and 13 ) or ([BA FACTYPE] between 1 and 13))"
  excl_qry = "Select * where !"+validlink+" or !(("+ab_limit+"=0 | "+
    ab_limit+"=1 | "+ab_limit+"=6 | "+ba_limit+"=0 | "+ba_limit+"=1 | "+
    ba_limit+"=6)" + ")"
  Opts = null
  Opts.Input.Database = hwy_dbd
  Opts.Input.Network = net
  excl_set = {hwy_dbd + "|" + llyr, llyr, "SOV -FREE", excl_qry}


  // VDF options
  Opts.Field.[VDF Fld Names] = {"*_FFTIME", "*_CAPACITY", "*_ALPHA",  "None"}  // JL Added for Conical Function
  Opts.Global.[Load Method] = "NCFW"
  if (Opts.Global.[Load Method] = "NCFW") then Opts.Global.[N Conjugate] = 2
  if (Opts.Global.[Load Method] = "NCFW") then do
      Opts.Global.[N Conjugate] = 2
      Opts.Global.[T2 Iterations] = 100
  end
  Opts.Global.[Loading Multiplier] = 1
  Opts.Global.Convergence = 0.0001
  Opts.Global.Iterations = 300
  Opts.Global.[Cost Function File] = "emme2.vdf"
  Opts.Global.[VDF Defaults] = {, , 4, }

  // Settings that vary depending on the matrix used
  a_type = {"race", "IncGroup"}
  for t = 1 to a_type.length do
    type = a_type[t]

    // set od matrix
    od_mtx = output_dir + "/ej_od_by_" + type + ".mtx"
    mtx = OpenMatrix(od_mtx, )
    a_cores = GetMatrixCoreNames(mtx)
    core_name = a_cores[1]
    mtx = null
    Opts.Input.[OD Matrix Currency] = {od_mtx, core_name, , }

    // Exclusion set array
    Opts.Input.[Exclusion Link Sets] = null
    for i = 1 to a_cores.length do
      Opts.Input.[Exclusion Link Sets] = Opts.Input.[Exclusion Link Sets] +
        {excl_set}
    end

    // Class information
    a_class_num = null
    a_class_pce = null
    a_class_voi = null
    a_toll = null
    a_turn = null
    for i = 1 to a_cores.length do
      a_class_num = a_class_num + {i}
      a_class_pce = a_class_pce + {1}
      a_class_voi = a_class_voi + {.25}
      a_toll = a_toll + {"*_COST_DANT"}
      a_turn = a_turn + {"PENALTY"}
    end
    Opts.Field.[Vehicle Classes] = a_class_num
    Opts.Global.[Number of Classes] = a_cores.length
    Opts.Global.[Class PCEs] = a_class_pce
    Opts.Global.[Class VOIs] = a_class_voi
    Opts.Field.[Fixed Toll Fields] = a_toll
    Opts.Field.[Turn Attributes] = a_turn

    // output file
    Opts.Output.[Flow Table] = output_dir + "/ej_am_flow_by_" + type + ".bin"

    ret_value = RunMacro("TCB Run Procedure", 1, "MMA", Opts, &Ret)
    if !ret_value then do
        Throw("Highway assignment failed.")
    end
  end
EndMacro

/*
Create a map showing EJ origins and flows.
*/

Macro "EJ Mapping"
  shared scen_dir, ej_dir, output_dir
  UpdateProgressBar("EJ Mapping", 0)

  // Open the ej trip table
  trip_df = CreateObject("df")
  trip_df.read_csv(output_dir + "/ej_am_trips.csv")

  // Create summary tables by o/d and race/income
  a_od = {"origin", "destination"}
  a_ej = {"race", "IncGroup"}
  for e = 1 to a_ej.length do
    ej = a_ej[e]

    // Determine Categories
    if ej = "race" then do
      race_df = CreateObject("df")
      race_df.read_csv(ej_dir + "/race_codes.csv")
      a_cats = V2A(race_df.tbl.Value)
    end else a_cats = {"Low", "NotLow"}

    for o = 1 to a_od.length do
      od = a_od[o]

      // Create a summary table of trip origins by category by TAZ
      temp_df = trip_df.copy()
      temp_df.group_by({od + "Taz", ej})
      agg = null
      agg.expansionFactor = {"sum"}
      temp_df.summarize(agg)
      temp_df.spread(ej, "sum_expansionFactor", 0)
      temp_df.group_by({od + "Taz"})
      agg = null
      sum_names = null
      for c = 1 to a_cats.length do  // set array of category fields to agg
        agg.(a_cats[c]) = {"sum"}
        sum_names = sum_names + {"sum_" + a_cats[c]}
      end
      temp_df.summarize(agg)
      temp_df.rename(sum_names, a_cats)
      csv = output_dir + "/" + od + "s_by_" + ej + ".csv"
      temp_df.write_csv(csv)

      // Create a map
      if od = "origin" then RunMacro("EJ Map Helper", od, ej, a_cats)
    end
  end
EndMacro

/*
Middle-man macro between "EJ Mapping" and the gisdk_tools macro
"Create Chart Theme". Creaets a map and sets up the options before calling
chart macro for tazs and links.

od
  String "origin" or "destination"
  Whether the TAZ origins or destinations will be mapped

ej
  String "race" or "IncGroup"
  Which ej category will be mapped
*/

Macro "EJ Map Helper" (od, ej, a_cats)
  shared scen_dir, output_dir, ej_dir

  // Determine which ej files to map
  orig_tbl = output_dir + "/" + od + "s_by_" + ej + ".csv"
  flow_tbl = output_dir + "/ej_am_flow_by_" + ej + ".bin"

  // Create Map
  hwy_dbd = scen_dir + "/inputs/network/Scenario Line Layer.dbd"
  taz_dbd = scen_dir + "/inputs/taz/Scenario TAZ Layer.dbd"
  {nlyr, llyr} = GetDBLayers(hwy_dbd)
  {tlyr} = GetDBLayers(taz_dbd)
  map = RunMacro("G30 new map", hwy_dbd)
  MinimizeWindow(GetWindowName())
  AddLayer(map, tlyr, taz_dbd, tlyr)
  RunMacro("G30 new layer default settings", tlyr)

  // Create pie chart theme on the TAZ layer of origins by category
  orig_tbl = OpenTable("origins", "CSV", {orig_tbl})
  taz_jv = JoinViews("jv", tlyr + ".TAZ", orig_tbl + ".originTaz", )
  SetLayer(tlyr)
  a_cat_specs = V2A(taz_jv + "." + A2V(a_cats))
  opts = null
  opts.layer = tlyr
  opts.field_specs = a_cat_specs
  opts.type = "Pie"
  opts.Title = "Trip " + od + "s by " + ej
  RunMacro("Create Chart Theme", opts)

  // Summarize the assignment table to combine ab/ba
  flow_tbl = OpenTable("flow", "FFB", {flow_tbl})
  df = CreateObject("df")
  opts = null
  opts.view = flow_tbl
  df.read_view(opts)
  a_dir = {"AB", "BA"}
  v_fields = ("tot_" + A2V(a_cats) + "_flow")
  for f = 1 to v_fields.length do
    field_name = v_fields[f]
    cat = a_cats[f]

    df.mutate(
      field_name,
      df.tbl.("AB_Flow_" + cat) + df.tbl.("BA_Flow_" + cat)
    )
  end
  df.select(v_fields)
  df.update_view(flow_tbl)

  // Create pie chart of flow
  link_jv = JoinViews("jv_link", llyr + ".ID", flow_tbl + ".ID1", )
  SetLayer(llyr)
  a_cat_specs = V2A(link_jv + ".tot_" + A2V(a_cats) + "_flow")
  opts = null
  opts.layer = llyr
  opts.field_specs = a_cat_specs
  opts.type = "Pie"
  opts.Title = "Flow by " + ej
  RunMacro("Create Chart Theme", opts)

  MaximizeWindow(GetWindowName())
  RedrawMap(map)
  SaveMap(map, output_dir + "/ej map by " + ej + ".map")
  CloseMap(map)
EndMacro