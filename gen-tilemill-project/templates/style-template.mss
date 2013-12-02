  #@SHP_FILE@ {
  marker-allow-overlap:true;
  marker-line-color:black;
  marker-line-opacity:1;
  //marker-width:12;
  marker-line-width: 2;
  [BLDG_COUNT > 0.00001] [BLDG_COUNT <= 1] {
      marker-fill:#c9e4ec;
    }
    [BLDG_COUNT > 1] [BLDG_COUNT <= 2] {
      marker-fill:#c9e4ec;
    }
    [BLDG_COUNT > 2] [BLDG_COUNT <= 6] {
      marker-fill:#bcdee8;
    }
    [BLDG_COUNT > 6] [BLDG_COUNT <= 20]  {
      marker-fill:#afd8e4;
    }
    [BLDG_COUNT > 20] [BLDG_COUNT <= 40] {
      marker-fill:#a2d2df;
    }
    [BLDG_COUNT > 40] [BLDG_COUNT <= 60] {
      marker-fill:#96cbdb;
    }
    [BLDG_COUNT > 60] [BLDG_COUNT <= 80] {
      marker-fill:#89c5d7;
    }
    [BLDG_COUNT > 80] [BLDG_COUNT <= 100] {
      marker-fill:#7cbfd2;
    }
    [BLDG_COUNT > 100] [BLDG_COUNT <= 150] {
      marker-fill:#63b3ca;
    }
    [BLDG_COUNT > 150] [BLDG_COUNT <= 200] {
      marker-fill:#4aa6c1;
    }
    [BLDG_COUNT > 200] [BLDG_COUNT <= 250] {
      marker-fill:#3b94ae;
    }
    [BLDG_COUNT > 250] [BLDG_COUNT <= 300] {
      marker-fill:#337e94;
    }
    [BLDG_COUNT > 300] [BLDG_COUNT <= 350] {
      marker-fill:#2a697b;
    }
    [BLDG_COUNT > 350] [BLDG_COUNT <= 400] {
      marker-fill:#215362;
    }
    [BLDG_COUNT > 400] [BLDG_COUNT <= 500] {
      marker-fill:#193e48;
    }
    [BLDG_COUNT > 500] [BLDG_COUNT <= 600] {
      marker-fill:#14333c;
    }
    [BLDG_COUNT > 600] [BLDG_COUNT <= 700] {
      marker-fill:#14333c;
    }
    [BLDG_COUNT > 700] [BLDG_COUNT <= 2300] {
      marker-fill:#0c1d22;
    }
 
 
  ////////////////
  /////zoom 8/////
  ////////////////
  [zoom <= 8] {
    marker-line-opacity: 0.5;
    marker-line-width: 0.3;
    marker-file: url(maki/src/square-18.svg);
    marker-width: 2;
    [BLDG_COUNT = 0] {
      marker-line-opacity: 0;
      marker-line-width: 0;
      marker-fill-opacity: 0;
    }
  }
 
  ////////////////
  /////zoom 9/////
  ////////////////
  [zoom = 9] {
    marker-line-opacity: 0.5;
    marker-line-width: 8;
    marker-width: 4;
    marker-file: url(maki/src/square-18.svg);
    [BLDG_COUNT = 0] {
      marker-line-opacity: 0;
      marker-line-width: 0;
      marker-fill-opacity: 0;
    }
   
  }
  ////////////////
  /////zoom 10////
  ////////////////
  [zoom = 10] {
    marker-line-opacity: 0.6;
    marker-line-width: 3;
    marker-file: url(maki/src/square-18.svg);
    marker-width: 9;
    [BLDG_COUNT = 0] {
      marker-line-opacity: 0;
      marker-line-width: 0;
      marker-fill-opacity: 0;
    }
   
  }
 
  ////////////////
  /////zoom 11////
  ////////////////
 
  [zoom = 11] {
    marker-file: url(maki/src/square-18.svg);
    marker-line-opacity: 0.65;
    marker-line-width: 4;
    marker-width: 16;
    [BLDG_COUNT = 0] {
      marker-line-opacity: 0;
      marker-line-width: 0;
      marker-fill-opacity: 0;
    }
  }
 
  ////////////////
  /////zoom 12////
  ////////////////
 
  [zoom = 12] {
    marker-line-opacity: 0.65;
    marker-line-width: 4;
    marker-width: 31;
    marker-file: url(maki/src/square-18.svg);
    [BLDG_COUNT = 0] {
      marker-line-opacity: 0;
      marker-line-width: 0;
      marker-fill-opacity: 0;
    }
  }
  /*
  [total_area >= 0] [total_area <= 290] {marker-width: 2;}
  [total_area > 290] [total_area <= 900] {marker-width: 3;}
  [total_area > 900] [total_area <= 2000] {marker-width: 4;}
  [total_area > 2000] [total_area <= 5450] {marker-width: 5;}
  [total_area > 5450] [total_area <= 20000] {marker-width: 6;}
  [total_area > 20000] [total_area <= 800000] {marker-width: 7;}
  [total_area > 800000] [total_area <= 2500000] {marker-width: 8;}
*/
}
