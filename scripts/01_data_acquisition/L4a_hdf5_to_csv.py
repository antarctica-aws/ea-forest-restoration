#!/usr/bin/env python
# coding: utf-8

# In[1]:


import h5py
import tabulate
import contextily as ctx
import numpy as np
import pandas as pd
import geopandas as gpd
import matplotlib.pyplot as plt
import rasterio
from datetime import datetime, timedelta
from IPython.display import HTML, display
from os import path
from shapely.geometry import Point
from matplotlib_scalebar.scalebar import ScaleBar
from matplotlib.lines import Line2D
from matplotlib import cm
from matplotlib.colors import ListedColormap
from scipy import stats
import time
import multiprocessing
from multiprocessing import Pool
from rasterio.plot import show
import functools


# In[2]:


import os
cwd = os.getcwd()
print(cwd)
from glob import glob
from os import path


# In[3]:


selectedvars=['agbd', 'agbd_pi_lower', 'agbd_pi_upper', 'agbd_se', 'agbd_t', 'agbd_t_se', 'algorithm_run_flag', 
              'beam','degrade_flag', 'delta_time', 'elev_lowestmode', 'l2_quality_flag', 'l4_quality_flag', 
              'lat_lowestmode', 'lon_lowestmode', 'predict_stratum','selected_algorithm', 'selected_mode', 
              'selected_mode_flag', 'sensitivity', 'shot_number', 'solar_elevation', 'surface_flag',
             'land_cover_data','agbd_prediction','geolocation']

group_vars=['agbd_a1','agbd_a2','agbd_a3','agbd_a4','agbd_a5','agbd_a6','agbd_a10',
         'agbd_se_a1','agbd_se_a2','agbd_se_a3','agbd_se_a4','agbd_se_a5','agbd_se_a6','agbd_se_a10',
        'landsat_treecover','landsat_water_persistence','leaf_off_doy','leaf_off_flag', 'leaf_on_cycle', 'leaf_on_doy',
        'pft_class','region_class', 'urban_focal_window_size','urban_proportion']


# In[4]:


def pointextract(gdf, rr):  #rr is the row number 
    point=gdf.iloc[rr]['geometry']
    x=point.xy[0][0]
    y=point.xy[1][0]
    row, col =biomr.index(x,y)
    return(biomr.read(1)[row,col])


# In[5]:


def h5file_extract_simp(subfileind):
    subfile=glob(path.join(outdir, 'GEDI04_A*.h5'))[subfileind]
    print(subfile)
    hf=h5py.File(subfile, 'r')

    alldf=pd.DataFrame()
    dt1 = datetime(2018, 1, 1, 0, 0, 0)
    groupKeys=['land_cover_data','agbd_prediction','geolocation']
    
    print("Step 1: extract variables for each beam")
    # loop over all base groups
    for var in list(hf.keys()):
        if var.startswith('BEAM'):

            # reading lat, lon, time
            beam = hf.get(var)
            var_names = []
            var_val = []
            for key, value in beam.items():
                if key in selectedvars:
                    if (key.startswith('xvar')):
    #                     print("xvar shape",value.shape)
                        for r in range(4):
                            var_names.append(key + '_' + str(r+1))
                            var_val.append(value[:, r].tolist())
                    elif key in groupKeys:
    #                     print("groupkey",key)
    #                     print(beam[key].items())
                        for k, v in beam[key].items():
    #                         print(k)
                            if k in group_vars:
    #                             print(k)
                                var_names.append(k)
                                var_val.append(v[:].tolist())

                    else:
                        var_names.append(key)
                        var_val.append(value[:].tolist())
            # create a pandas dataframe        
            beam_df = pd.DataFrame(map(list, zip(*var_val)), columns=var_names) 
            alldf=alldf.append(beam_df, ignore_index=True)
#             print(alldf.shape)
    print("Step 2: convert to gdf")
    #set the row index to shot number
    alldf=alldf.set_index("shot_number" ,append = True, drop = False)
    #convert the delta time to date time
    alldf['date_time'] =dt1 + pd.to_timedelta(alldf['delta_time'], unit='s')  
    # convert to a geopandas dataframe for plotting
    all_gdf = gpd.GeoDataFrame(alldf, geometry=gpd.points_from_xy(alldf.lon_lowestmode, alldf.lat_lowestmode))
    # assigning CRS of WGS84
    all_gdf.crs = "EPSG:4326"
    # turning fill values (-9999) to nan
    all_gdf = all_gdf.replace(-9999, np.nan)
    
    print("Step 3: extract wwfbiome")
    print("shape1",all_gdf.shape)
    
    tic = time.time()
    coord_list = [(x,y) for x,y in zip(all_gdf['geometry'].x , all_gdf['geometry'].y)] #extract at each shot the wwfbiom code
    all_gdf['biome'] = [x[0] for x in biomr.sample(coord_list)]  # [sample[0] for sample in src.sample(coords)]
    toc = time.time()
    print('Done in {:.4f} seconds'.format(toc-tic))
    print("dimension of the subset df", all_gdf.shape)

    #take care of some transformation
    print("Step 4: transforming NaN values")
    all_gdf['biome'] = all_gdf['biome'].astype(int)
    all_gdf=all_gdf.replace(-9223372036854775808, 0)
    
    print("Step 5: output file")
    dataset_path = outfolder + '/' + subfile.rsplit('/', 1)[1]
    all_gdf.drop('geometry',axis=1).to_csv(dataset_path+'.csv') 
    
#     return()
    


# In[6]:


outdir = 'data/l4a_subsets/forest_cube' ####!!![need to modify]!!!### #dodoma
outfolder= 'data/l4a_csv/forest_cube'####!!![need to modify]!!!###  #dodoma
fileLen=len(glob(path.join(outdir, 'GEDI04_A*.h5')))
print(fileLen)
# print(subfile)
biomr = rasterio.open('data/demo_data/ea_wwf_biomes.tif')


# In[ ]:


def main():
    tic = time.time()
    pool = Pool(processes=12)  # set the processes max number 3
    result = pool.map(h5file_extract_simp, range(0,fileLen))
    pool.terminate()
    pool.join()
    print(result)
    print('end')
    toc = time.time()
    print('Done in {:.4f} seconds'.format(toc-tic))

    
if __name__ == "__main__":
    main()


# In[ ]:




