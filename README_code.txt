%%%% How to run


%%% Generate SBARC AIS subset data 

1.  getShipsAIS_CINMS_B_180820.m

    Edit:
        siteB ( default is nominal position CINMS_B_30_00 )
        boundd_m ( distance from siteB to edge of lat/lon bounding box )
        idir ( input directory )
        odir ( output directory )

        
%%% Generate AIS text output/wav data/plots
        
1.  getXWAVTimes_CINMS_B.m - 

    generates mat file with xwav start/end times if disk
    has not been used before or mount point changed.
   
    Saves the hassle of generating times more than once
    
    Edit 
        dbFindFiles regexp/mount point
        diskLabel 
        odir 
        
2. CINMS_B_dbQuery.m - 

    Generates a mat file with deployment info queried from the HARP database
    
    Edit
        exDeps ( deployments to exclude from lookup )
        offn ( output filename for saved deployment info )
        
3.  getSiteBLoc.m - 

    Looks up HARP deployment info for a given time 
    
    Edit
        filename and path of CINMS_B_dbQuery.m output
        
4.  getCINMS_B_df20_180821.m - 

    Uses precached xwav locations/times to return xwav data
    
    Edit
        xwavTimes - full path filenames pointing to the output of getXWAVTimes_CINMS_B.m
  
    
3.  getShipPass_CINMS_B_180831

    Edit: 
        idir        ( input directory of AIS subset data )
        odir        ( output directory )
        mincpa_m    ( minimum CPA required to include ship pass ) 
        irad1_m     ( distance from CPA in shiptrack to include ) 
        maxDelt     ( maximum time in seconds to include around CPA point )
        minDelt     ( minimum time in seconds to include around CPA point ) 
        tfilemax    ( max ouput wav time in seconds )
        tfilemin    ( min output wav time in seconds )
        
        