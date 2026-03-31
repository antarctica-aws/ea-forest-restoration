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


# In[2]:


#load in the raster layer of WWFBIOME
from rasterio.plot import show
import rasterstats as rs
biomr = rasterio.open('ea_wwf_biomes.tif')

#load the study area aoi 
import geopandas as gpd
grsm_epsg4326=gpd.read_file("data/demo_data/forest_cube.geojson") ####!!![need to modify]!!!###  #Dodoma/Dodoma_merged4326.geojson")
print(grsm_epsg4326)

# In[3]:


from glob import glob
from os import path

indir = 'data/l4a_orig/forest_cube/'  ####!!![need to modify]!!!###
outdir = 'data/l4a_subsets/forest_cube/' ####!!![need to modify]!!!###  #'l4a_subsets/sub2'


alll4afiles=glob(path.join(indir, 'GEDI04_A*.h5'))
print(alll4afiles)
print(len(alll4afiles))


# In[4]:



# for infile in glob(path.join(indir, 'GEDI04_A*.h5'))[0:1]:
def extract_subset(n):
    infile = alll4afiles[n]
    print('processing of ',infile)
    name, ext = path.splitext(path.basename(infile))
    subfilename = "{name}_sub{ext}".format(name=name, ext=ext)
    outfile = path.join(outdir, path.basename(subfilename))
    print(outfile)
    hf_in = h5py.File(infile, 'r')
    hf_out = h5py.File(outfile, 'w')
    
    # copy ANCILLARY and METADATA groups
    var1 = ["/ANCILLARY", "/METADATA"]
    for v in var1:
        hf_in.copy(hf_in[v],hf_out)
    
    
    print(hf_in.keys())
    # loop through BEAMXXXX groups
    for v in list(hf_in.keys()):
        if v.startswith('BEAM'):
            beam = hf_in[v]
            print(beam)
            # find the shots that overlays the area of interest (GRSM)
            lat = beam['lat_lowestmode'][:]
            lon = beam['lon_lowestmode'][:]
            i = np.arange(0, len(lat), 1) # index
            geo_arr = list(zip(lat,lon, i))
            l4adf = pd.DataFrame(geo_arr, columns=["lat_lowestmode", "lon_lowestmode", "i"])
#             print(l4adf)
            l4agdf = gpd.GeoDataFrame(l4adf, geometry=gpd.points_from_xy(l4adf.lon_lowestmode, l4adf.lat_lowestmode))
            l4agdf.crs = "EPSG:4326"
            
            tic = time.time()
            l4agdf_gsrm = l4agdf[l4agdf['geometry'].within(grsm_epsg4326.geometry[0])]  
            toc = time.time()
            print('Done in {:.4f} seconds'.format(toc-tic))

            indices = l4agdf_gsrm.i

            # copy BEAMS to the output file
            for key, value in beam.items():
                if isinstance(value, h5py.Group):
                    for key2, value2 in value.items():
                        group_path = value2.parent.name
                        group_id = hf_out.require_group(group_path)
                        dataset_path = group_path + '/' + key2
                        hf_out.create_dataset(dataset_path, data=value2[:][indices])
                        for attr in value2.attrs.keys():
                            hf_out[dataset_path].attrs[attr] = value2.attrs[attr]
                else:
                    group_path = value.parent.name
                    group_id = hf_out.require_group(group_path)
                    dataset_path = group_path + '/' + key
                    hf_out.create_dataset(dataset_path, data=value[:][indices])
                    for attr in value.attrs.keys():
                        hf_out[dataset_path].attrs[attr] = value.attrs[attr]

    print("done subsetting",infile)
    hf_in.close()
    hf_out.close()


# In[5]:


alll4afiles=glob(path.join(indir, 'GEDI04_A*.h5'))
t=len(alll4afiles)
print(t)




def main():
    tic = time.time()
    pool = Pool(processes=12)  # set the processes max number 3
    result = pool.map(extract_subset, range(0,t))
    pool.terminate()
    pool.join()
    print(result)
    print('end')
    toc = time.time()
    print('Done in {:.4f} seconds'.format(toc-tic))

    
if __name__ == "__main__":
    main()
    
    




