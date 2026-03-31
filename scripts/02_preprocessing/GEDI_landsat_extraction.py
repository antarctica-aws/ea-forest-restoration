#!/usr/bin/env python
# coding: utf-8



import h5py
import tabulate
import contextily as ctx
import numpy as np
import pandas as pd
import geopandas as gpd
import matplotlib.pyplot as plt
import rasterio
import random
import math
from datetime import datetime, timedelta
from os import path
from shapely.geometry import Point
from scipy import stats
import time
import multiprocessing
from multiprocessing import Pool
from rasterio.plot import show
import functools
from osgeo import ogr
from osgeo import gdal
import os
cwd = os.getcwd()
print(cwd)
from glob import glob
from os import path



topo = gdal.Open('.../data/demo_data/ancillary_vars/topo_stack.tif')
print(topo.GetRasterBand(3).GetDescription())



def get_raster_value(geo_x, geo_y, ds, band_index):
#     """Return raster value that corresponds to given coordinates."""
    forward_transform = ds.GetGeoTransform()
    pixel_width = forward_transform[1]
    pixel_height = -forward_transform[5]    
    reverse_transform = gdal.InvGeoTransform(forward_transform)
    pixel_coord = gdal.ApplyGeoTransform(reverse_transform, geo_x, geo_y)
    pixel_x = math.floor(pixel_coord[0])
    pixel_y = math.floor(pixel_coord[1])
    band = ds.GetRasterBand(band_index)
    val_arr = band.ReadAsArray(pixel_x, pixel_y, 1, 1) # Avoid reading the whole raster into memory - read 1x1 array
    if val_arr is None:
#         pass
#         print(out)
        return np.nan
    else:
        out=val_arr[0][0]
#         print(out)
        return out
def bname(ds, band_index):
    return  ds.GetRasterBand(band_index).GetDescription()

def getEx(pt, ds):
    from shapely.geometry import Polygon
    """ Return list of corner coordinates from a gdal Dataset """
    xmin, xpixel, _, ymax, _, ypixel = ds.GetGeoTransform()
    width, height = ds.RasterXSize, ds.RasterYSize
    xmax = xmin + width * xpixel
    ymin = ymax + height * ypixel
    
    poly=Polygon(((xmin, ymax), (xmax, ymax), (xmax, ymin), (xmin, ymin)))
    return poly.contains(pt)  #return true or false 

def ls_Extract(tileX, yr, biome, cornerInd):
    #tileX=tileX[0]
    print('tile', tileX)
    print('yr', yr)
    print('biome', biome)
    yr=str(yr)
    biome=str(biome)

    imageStack = "ls_lhs_medoid_"+tileX+"_"+yr+"_NBR_3by3_dur8_biome" + biome+ "_val_v2-"+'*.tif'  ####!!![need to modify]!!!###
    
    out="/tile"+tileX+"_cor"+str(cornerInd)+ '_biom'+biome+'_'+yr+'_topo_lhs_nbr_dur8.csv'  ####!!![need to modify]!!!###

    #preping the sample dataframe
    pdir= ".../data/landsat_comp/t"+tileX+'_1986-2021/'+yr   
    outdir = '.../data/ls_ltr_training/tile'+tileX+'_filtered_l4a_ls_output_corner'
    annual_pl= glob.glob(path.join(pdir, imageStack))[cornerInd]  

    samples= pd.read_csv('data/samples/aoi_gedi_samples_'+yr+'.csv')     ####!!![need to modify]!!!
    print('total samples', samples.shape)
    sample2020_min_1 = samples 
    print('sub samples', sample2020_min_1.shape)

    sample2020_min_1_gdf= gpd.GeoDataFrame(sample2020_min_1, 
                                           geometry=gpd.points_from_xy(sample2020_min_1.lon_lowestmode, sample2020_min_1.lat_lowestmode), 
                                           crs="EPSG:4326")

    sample2020_min_1_gdf_tile=sample2020_min_1_gdf
    print(sample2020_min_1_gdf_tile.shape)

    print('number of subset in tile: '+str(cornerInd))
    
    df = pd.DataFrame()
    for rcount in range(0,1):
        print('raster', rcount)
        src=gdal.Open(annual_pl)
        topo = gdal.Open('.../data/ancillary_vars/topo_stack.tif')
        i = 0
        while i < len(sample2020_min_1_gdf_tile):
            
            geo_x, geo_y = sample2020_min_1_gdf_tile.iloc[i]['lon_lowestmode'],sample2020_min_1_gdf_tile.iloc[i]['lat_lowestmode']
            geom =  sample2020_min_1_gdf_tile.iloc[i].geometry  #convert to point with geom for checking if its in the ras ex
            outlist = {}
            outlist['shot_number']=  sample2020_min_1_gdf_tile.iloc[i]['shot_number'].astype(str)
            outlist['agbd']=  sample2020_min_1_gdf_tile.iloc[i]['agbd']
            outlist['lon_lowestmode']=  sample2020_min_1_gdf_tile.iloc[i]['lon_lowestmode']
            outlist['lat_lowestmode']=  sample2020_min_1_gdf_tile.iloc[i]['lat_lowestmode']
            if getEx(geom, src):
#                 print('point in this subset')
                print(i)
                for b in range(0, src.RasterCount):
                    bind=b+1
                    out0=get_raster_value(geo_x, geo_y, ds=src, band_index=bind)

                    if out0 is None:
                        out0=np.nan

                    outlist[bname(src, bind)]=out0
                for t in range(0, topo.RasterCount):
                    tind=t+1
                    
                    out00= get_raster_value(geo_x, geo_y, ds=topo, band_index=tind)

                    if out00 is None:
                        out0=np.nan

                    outlist[bname(topo, tind)]=out00

                if not (all(np.isnan(value) for value in list(outlist.values())[4:])):
#                     print(all(np.isnan(value) for value in list(outlist.values())[1:]))
                    df = df.append(outlist, ignore_index=True)
                i+=1
            else: 
                i+=1
    print(df.shape)
    print(df)
    
    if len(df)>0:
        df = df[(df['ftv_ndvi_fit']!=0) & (df['GDMAG']!=0)]
        print(str(len(df))+" out of total "+ str(len(sample2020_min_1_gdf_tile))+" were extracted")
        df.to_csv(outdir+out, index=False)
        return(df)
    else:
        return df



import glob
wwfbiome=1
biomeTiles= ['tttttt']  #example tile name
yrs= ['2021', '2020','2019']

corners=range(0,12)
biome=str(wwfbiome)
# args = [(biomeTiles, yr, biome) for biomeTiles in biomeTiles]
args = [(biomeTiles, yr, biome, cornerInd) for biomeTiles in biomeTiles for yr in yrs for cornerInd in corners]
print(len(args))
print(args)
# parallel processing 
def main():
    tic = time.time()
    pool = Pool(processes=3)  # set the processes max number 3
    result = pool.starmap(ls_Extract, args)
    pool.terminate()
    pool.join()
    print(result)
    print('end')
    toc = time.time()
    print('Done in {:.4f} seconds'.format(toc-tic))

    
if __name__ == "__main__":
    main()


# In[ ]:




