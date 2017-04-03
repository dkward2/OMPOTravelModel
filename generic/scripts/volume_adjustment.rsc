/*
The macros in this script create an adjusted highway network at the
end of each model run (called during the "Summaries" step). There are two
adjustments:

1. Adjustment for base year model compared to counts.
This adjustment modifies model volumes based on model performance in the base
year. Adjustments are made by facility type and area type. For example, if the
model, on average, under-predicts volume on urban arterials by 5%, then a
future-year scenario will have urban arterial volumes adjusted up by 5%.

2. Adjustment for centroid spot loading
Centroids condense driveways, subdivision streets, etc into a single point
where traffic loads. The second adjustment is to spread the volume out around
the centroid connection. Total VMT is maintained.
*/

Macro "test va"
  shared path
  path = {, "C:\\projects\\Honolulu\\Version6\\OMPORepo\\scenarios\\test"}
  RunMacro("Volume Adjustment")
EndMacro

Macro "Volume Adjustment"

  RunMacro("Copy Highway Network")
  RunMacro("Yinan's Macro")
  RunMacro("Point Loading Adjustment")
EndMacro

/*
Create a copy of the highway network to be adjusted. Share the highway file name
with the other macros of this script. The variable "path" is how the main dbox
shares info with other macros.
*/

Macro "Copy Highway Network"
  shared path, hwy_dbd
  
  scen_dir = path[2]
  orig_hwy = scen_dir + "/inputs/network/Scenario Line Layer.dbd"
  output_dir = scen_dir + "/reports/volume_adjustment"
  // Create output_dir if it doesn't exist
  if GetDirectoryInfo(output_dir, "All") = null then CreateDirectory(output_dir)
  hwy_dbd = output_dir + "/adjusted_highway.dbd"
  CopyDatabase(orig_hwy, hwy_dbd)
EndMacro

/*
Volume adjustment based on base year model performance.
*/

Macro "Yinan's Macro"
  shared path, hwy_dbd
  
  scen_dir = path[2]
EndMacro

/*
Volume adjustment based on centroid loading.

SelectByLinks() / SelectByNodes()
*/

Macro "Point Loading Adjustment"
  shared hwy_dbd
  
  // Create a map of the highwa network
  map = RunMacro("G30 new map", hwy_dbd)
  {nlyr, llyr} = GetDBLayers(hwy_dbd)
  
  // Define centroids.
  // The arrays used below mean that any link with a 12 in either
  // "AB FACTYPE" or "BA FACTYPE" will be treated as a centroid.
  // Other facility types could be included - for example, you
  // may want to smooth out local street loading.
  a_type_fields = {"[AB FACTYPE]", "[BA FACTYPE]"}
  a_type_values = {12, 197}
  
  // Create selection set of centroids
  SetLayer(llyr)
  qry = "Select * where"
  for f = 1 to a_type_fields.length do
    field = a_type_fields[f]
    
    for v = 1 to a_type_values.length do
      value = a_type_values[v]
      
      if TypeOf(value) = "string" then value = "'" + value + "'"
      else value = String(value)
      
      if f + v = 2 then qry = qry + " " + field + " = " + value
      else qry = qry + " or " + field + " = " + value
    end
  end
  cc_set = "centroid connectors"
  SelectByQuery(cc_set, "several", qry)
  
  // Classify all nodes on network into centroid, intersection, and 
  // midblock selection sets
  {centroid_node_set, intersection_node_set, midblock_node_set} = 
    RunMacro("Classify Nodes", llyr, cc_set)

  // Create a set of midblock links. Select all links connected to midblock
  // nodes that are not members of the centroid connector set.
  SetLayer(llyr)
  midblock_link_set = CreateSet("midblock links")
  opts = null
  opts.[Source Not] = cc_set
  SelectByNodes(midblock_link_set, Several, midblock_node_set, opts)

  // Create continuous blocks of midblock links and smooth volumes.
  // Do this until no more midblock links remain.
  SetLayer(llyr)
  num_mbl = GetSetCount(midblock_link_set)
  while num_mbl > 0 do
    
    // Get the next midblock link id to start creating a block from
    a_lid = GetSetIDs(midblock_link_set)
    lid = a_lid[1]
    
    // Group all continuous midblock links into a block set
    // (removing them from midblock link set as you do so)
    block_set = CreateSet("block set")
    RunMacro(
      "Create Block", llyr, lid, midblock_link_set,
      block_set, midblock_node_set
    )
    Throw()
    
    num_mbl = GetSetCount(midblock_link_set)
  end
  
EndMacro

/*
Classifies nodes as either a centroid, midblock, or intersection.
Places them into selection sets of the same name.

Input
  llyr
    String
    Name of link layer
  cc_set
    String
    Name of CC link selection set
*/

Macro "Classify Nodes" (llyr, cc_set)

  SetLayer(llyr)
  nlyr = GetNodeLayer(llyr)
  v_nid = GetDataVector(nlyr + "|", "ID", )
  
  // Create node selection sets
  SetLayer(nlyr)
  centroid_node_set = CreateSet("centroid nodes")
  intersection_node_set = CreateSet("intersection nodes")
  midblock_node_set = CreateSet("midblock nodes")
  
  for n = 1 to v_nid.length do
    nid = v_nid[n]
    
    // Set node as current record and get connected links
    SetLayer(nlyr)
    rh = ID2RH(nid)
    SetRecord(nlyr, rh)
    a_links = GetNodeLinks(nid)
    
    // Array of CC and non-CC link IDs connected to the node
    SetLayer(llyr)
    cc = 0
    non_cc = 0
    for l = 1 to a_links.length do
      lid = a_links[l]
      
      rh = ID2RH(lid)
      if IsMember(cc_set, rh) then cc = cc + 1
      else non_cc = non_cc + 1
    end
    
    // Classify the node based on non-centroid count
    // Add them to the appropriate selection set
    SetLayer(nlyr)
    if non_cc = 0 then SelectRecord(centroid_node_set)
    else if non_cc = 1 then SelectRecord(intersection_node_set)
    else if non_cc = 2 then SelectRecord(midblock_node_set)
    else if non_cc > 2 then SelectRecord(intersection_node_set)
  end
  
  return({centroid_node_set, intersection_node_set, midblock_node_set})
EndMacro

/*
Recursive macro. Takes a starting link ID and adds it and all other connected
midblock_link_set links into block_set.

Inputs
llyr
  String
  Name of line layer
  
lid
  Integer
  Link ID
  
midblock_link_set
  String
  Set name of midblock links

block_set
  String
  Set name of the empty block_set to populate

midblock_node_set
  String
  Set name of midblock nodes
*/

Macro "Create Block" (llyr, lid, midblock_link_set,
  block_set, midblock_node_set)
  
  nlyr = GetNodeLayer(llyr)
  
  // Move link (lid) from midblock set to block set
  rh = ID2RH(lid)
  SetRecord(llyr, rh)
  SelectRecord(block_set)
  UnselectRecord(midblock_link_set)
  
  // Determine which of the link's nodes are midblock nodes
  SetLayer(llyr)
  a_nid2 = GetEndpoints(lid)
  SetLayer(nlyr)
  temp_set = CreateSet("lid's nodes")
  for n = 1 to a_nid2.length do
    nid = a_nid2[n]
    rh = ID2RH(nid)
    if IsMember(midblock_node_set, rh) then a_nid = a_nid + {nid}
  end

  // For each of the link's midblock nodes, create a set of all connected links
  for n = 1 to a_nid.length do
    a_connected_links = a_connected_links + GetNodeLinks(a_nid[n])
  end
  SetLayer(llyr)
  connected_set = CreateSet("connected links")
  for c = 1 to a_connected_links.length do
    clid = a_connected_links[c]
    rh = ID2RH(clid)
    SetRecord(llyr, rh)
    SelectRecord(connected_set)
  end
  
  // Intersect the two selection sets to determine connected midblock links
  SetLayer(llyr)
  connected_mb_set = "connected midblock links"
  n = SetAND(connected_mb_set, {connected_set, midblock_link_set})
  
  // If a connected midblock link is found, run "Create Block" on it, too.
  // This will recursively run until all connected midblock links are in
  // the same block set.
  if n > 0 then do
    a_next_links = GetSetIDs(connected_mb_set)
    for nl = 1 to a_next_links.length do
      nlid = a_next_links[nl]
      RunMacro(
        "Create Block", llyr, nlid, midblock_link_set,
        block_set, midblock_node_set
      )
    end
  end
EndMacro
