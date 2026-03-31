####This script extracts covariates for FR areas, and matches treat and control pairs at 1km pixel level based on 
#####covariates on biophysical and socioeconomic conditions #############

setwd('.../EA_FR_data')
library(terra)
library(tidyr)
library(dplyr)
library(sf)
`%notin%` <- Negate(`%in%`)

#---------------load in the Urban pressure index, and extract----------
ui_files <- list.files(path = "covariates/rev_covars", pattern = "UI.*\\.tif$", full.names = TRUE) %>% 
  sort(.)
ui_stack <- rast(ui_files)
names(ui_stack)<-paste('UI', gsub(".*((19|20)\\d{2}).*", "\\1", basename(ui_files)),sep='_')
ui_stack_prj<- terra::project(ui_stack, "EPSG:4326", method='near')

#---------------load the MCWD-----------------
mcwd_files <- list.files(path = "covariates/rev_covars", pattern = "MCWD.*\\.tif$", full.names = TRUE) %>% 
  sort(.)
mcwd_stack <- rast(mcwd_files)
names(mcwd_stack)<- paste('MCWD_',gsub(".*((19|20)\\d{2}).*", "\\1", basename(mcwd_files)),sep='')

#---------------load the land cover-----------------
lc_files <- list.files(path = "covariates/rev_covars", pattern = "LCCS.*\\.nc$", full.names = TRUE) %>% 
  sort(.)

lc_class_layers <- lapply(lc_files, function(f) {
  terra::rast(f)$lccs_class
})

lc_stack <- rast(lc_class_layers)
names(lc_stack)<-paste('lc_',gsub(".*((19|20)\\d{2}).*", "\\1", basename(lc_files)),sep='')

lc_sorted <- lc_stack[[order(names(lc_stack))]]

#---------------load the fire burned area corresponds to the tile-----------------

tif_files <- list.files("covariates/rev_covars/burned_Area_annual", pattern = "_.*\\.TIF$", full.names = TRUE)
# Extract bbox from filenames (e.g., "N00E020.tif")
get_extent <- function(fname) {
  name <- str_extract(fname, "(?<=_)[NS]\\d{2}[EW]\\d{3}")
  lat <- as.numeric(str_sub(name, 2, 3))
  if (str_starts(name, "S")) lat <- -lat
  lon <- as.numeric(str_sub(name, 5, 7))
  if (str_sub(name, 4, 4) == "W") lon <- -lon
  terra::ext(lon, lon + 10, lat - 10, lat)
}


process_year <- function(yi) {
  # Subset files for this year
  year_files <- intersecting_files[grep(yi, intersecting_files)]
  # Read and process each file: crop and mask by the polygon
  cropped_list <- lapply(year_files, function(file) {
    r <- rast(file)
    r_crop <- terra::crop(r, poly)
    r_mask <- terra::mask(r_crop, poly)
    return(r_mask)
  })
  
  # Merge the overlapping parts of rasters
  if (length(cropped_list) == 1) {
    merged <- cropped_list[[1]]
  } else {
    merged <- do.call(merge, cropped_list)
  }
  
  return(merged)
}

# Check which tiles intersect the polygon
intersecting_files <- tif_files[
  sapply(tif_files, function(f) {
    print(f)
    tile_ext <- get_extent(f)
    tile_vect <-as.polygons(tile_ext, crs = terra::crs(poly))
    relate(tile_vect, poly, "intersects")[1]
    
  })]
years_ba<-unique(gsub(".*((19|20)\\d{2}).*", "\\1", basename(intersecting_files)))
ba_stack <- rast(lapply(years_ba, process_year))
names(ba_stack) <- paste('BA_',unique(gsub(".*((19|20)\\d{2}).*", "\\1", basename(intersecting_files))),sep='')


#---------------load the annual mean Max temp corresponds to the tile-----------------
aveMax_files <- list.files("covariates/rev_covars/terraClim_ea", pattern = "aveMax.*\\.tif$", full.names = TRUE)
print(aveMax_files)

aveMax_stack <- rast(aveMax_files)
names(aveMax_stack)<-  paste('aveMaxTemp_',gsub(".*((19|20)\\d{2}).*", "\\1", basename(aveMax_files)),sep='')

#---------------load the annual mean Min temp corresponds to the tile-----------------
aveMin_files <- list.files("covariates/rev_covars/terraClim_ea", pattern = "aveMin.*\\.tif$", full.names = TRUE)
print(aveMin_files)

aveMin_stack <- rast(aveMin_files)
names(aveMin_stack)<-  paste('aveMinTemp_',gsub(".*((19|20)\\d{2}).*", "\\1", basename(aveMin_files)),sep='')

#---------------load the annual mean precipitataion temp corresponds to the tile-----------------
avePr_files <- list.files("covariates/rev_covars/terraClim_ea", pattern = "precipitation.*\\.tif$", full.names = TRUE)
print(avePr_files)

avePr_stack <- rast(avePr_files)
names(avePr_stack)<-  paste('avePrec_', gsub(".*((19|20)\\d{2}).*", "\\1", basename(avePr_files)),sep='')

#---------------load the semi-decadal population density map-------------
ea <- vect('AOI/EA_one.geojson')

popd_files <- list.files(path = "covariates/rev_covars", pattern = "pop.*\\.tif$", full.names = TRUE) %>% 
  sort(.)
print(popd_files)

clipped_poprasters <- lapply(popd_files, function(file) {
  r <- rast(file)
  r_crop <- terra::crop(r, ea)
  r_mask <- terra::mask(r_crop, ea)
  return(r_mask)
})

popd_stack <- rast(clipped_poprasters)

names(popd_stack)<- paste('popden',gsub(".*((19|20)\\d{2}).*", "\\1", basename(popd_files)),sep='_')
names(popd_stack)

years <- as.numeric(gsub("[^0-9]", "", names(popd_stack)))
popd_stack_sorted <- popd_stack[[order(years)]]


#---------------load the soil categories corresponds to the tile-----------------

soiltexture<-rast('covariates/rev_covars/soiltext_EA.tif')[['soiltext_EA_2']]  #full gradient of soil texture 
names(soiltexture)<-'soilTexture'

soilClass<-rast('covariates/rev_covars/soilraster_EA.tif')  
names(soilClass)<-'soilClass'

#---------------load the tt2cites corresponds to the tile------------
tt2c_2000<-rast('covariates/rev_covars/tt2cities2000_ea.tif')
names(tt2c_2000)<-'travelTime_2000'

tt2c_2015<-rast('covariates/rev_covars/tt2cities2015_ea.tif')
names(tt2c_2015)<-'travelTime_2015'

#simple bias correction b/t two products
sys_bias<-mean(tt2c_2000[], na.rm=T)-mean(tt2c_2015[], na.rm=T)
tt2c_2015_v2<-tt2c_2015+sys_bias

#---------------load the topographic vars----------------------------------

topo<-rast('ancillary_vars/topo_stack_res2.tif')


#-------------starting to compile the covar for each site-------------------

covar_list<-list(ui_stack_prj,popd_stack_sorted,tt2c_2000, tt2c_2015_v2, soiltexture, 
                 soilClass, aveMin_stack, aveMax_stack,avePr_stack, lc_sorted,
                 mcwd_stack,topo, ba_stack)

tile_rasters <- lapply(covar_list, function(r) {
  r_crop <- terra::crop(r, poly)
  r_masked <- terra::mask(r_crop, poly)
  return(r_masked)
})

# Choose one raster as the reference (e.g., the first one)
ref_raster <-ba_stack[[1]]

system.time({  
  # Resample each raster to match the resolution and extent of the reference
  resampled_covar_list <- lapply(tile_rasters, function(r) {
    print(r)
    res_target <- res(ref_raster)
    fact<-res(r) / res_target
    if (any(round(fact)!=1)){
      if(any(startsWith(names(r), "UI") | startsWith(names(r), "BA")| startsWith(names(r), "lc")| startsWith(names(r), "soil"))){
        disaggr <- terra::disagg(r, fact = fact, method = "near")
        r_resamp<-resample(disaggr,ref_raster, method = "near")
      } else{
        disaggr <- terra::disagg(r, fact = fact, method = "bilinear")
        r_resamp<-resample(disaggr,ref_raster, method = "bilinear")
      }
    } else{
      disaggr<-r
      r_resamp<- resample(disaggr,ref_raster, method = "bilinear")
    }
    
  })
})

#export for easy reuse 
covar_stack2<-rast(resampled_covar_list)
# writeRaster(covar_stack2, paste('covariates/tile_covar_stack_sav/',poly$Name,"_covar_stack.tif",sep=''), overwrite=TRUE)

#-------------functions for calculate pre-treatment means-----------------------

get_before_treat_mean <- function(df, covar_prefix) {
  df %>%
    dplyr::select(row_id, treatment_year, starts_with(covar_prefix)) %>%
    pivot_longer(cols = starts_with(covar_prefix), names_to = "year_var", values_to = "value") %>%
    mutate(year = as.numeric(str_extract(year_var, "\\d{4}"))) %>%
    filter(year >= (treatment_year - 5) & year < treatment_year) %>% 
    group_by(row_id) %>%
    summarise(mean_value = mean(value, na.rm = TRUE), .groups = "drop") %>%
    rename(!!paste0(covar_prefix, "mean_5yrbefore_treatment") := mean_value) %>% 
    right_join(df[,c('treatment_year' ,'row_id')], by = "row_id")
}

get_before_treat_sum <- function(df, covar_prefix) {
  df %>%
    dplyr::select(row_id, treatment_year, starts_with(covar_prefix)) %>%
    pivot_longer(cols = starts_with(covar_prefix), names_to = "year_var", values_to = "value") %>%
    mutate(year = as.numeric(str_extract(year_var, "\\d{4}"))) %>%
    filter(year >= (treatment_year - 5) & year < treatment_year) %>% 
    group_by(row_id) %>%
    summarise(sum_value = sum(value, na.rm = TRUE), .groups = "drop") %>%
    rename(!!paste0(covar_prefix, "sum_5yrbefore_treatment") := sum_value) %>% 
    right_join(df[,c('treatment_year' ,'row_id')], by = "row_id")
}

get_mode <- function(x) {
  x <- na.omit(x)  # Remove NA values
  if (length(x) == 0) return(NA)  # Return NA if no valid data
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}

get_before_treat_mode <- function(df, covar_prefix) {
  df %>%
    dplyr::select(row_id, treatment_year, starts_with(covar_prefix)) %>%
    pivot_longer(cols = starts_with(covar_prefix), names_to = "year_var", values_to = "value") %>%
    mutate(year = as.numeric(str_extract(year_var, "\\d{4}"))) %>%
    filter(year >= (treatment_year - 5) & year < treatment_year) %>% 
    group_by(row_id) %>%
    summarise(mode_value = get_mode(value), .groups = "drop") %>%
    rename(!!paste0(covar_prefix, "mode_5yrbefore_treatment") := mode_value) %>% 
    right_join(df[,c('treatment_year' ,'row_id')], by = "row_id")
}

#-------------start to extract covars for one AOI----

aoi<-vect('data/demo_data/forest_cube.geojson')  
fr_site<- aoi
fr_site$treatment_year<-fr_site$year  
fr_site$id<-1:length(fr_site) 
attr<-c('id','treatment_year')  
fr_site<-fr_site[,attr]

#combine covar with the FR attributes
covar_stack2<-rast(paste('covariates/rev_covars/tile_covar_stack_sav/',poly$Name,"_covar_stack.tif",sep=''), overwrite=TRUE)

fr_covar_df<-terra::extract(covar_stack2, fr_site,method="simple", bind = FALSE, xy=TRUE)
poly_attrs <- as.data.frame(fr_site)
fr_covar_df2 <- cbind(fr_covar_df, poly_attrs[fr_covar_df$ID, ])
fr_covar_df2<-fr_covar_df2 %>% mutate(row_id = row_number())

tt_mean <- get_before_treat_mean(fr_covar_df2, "travelTime_")
popd_mean <- get_before_treat_mean(fr_covar_df2, "popden_")
mcwd_mean <- get_before_treat_mean(fr_covar_df2, "MCWD_")
aveMaxTemp_mean <- get_before_treat_mean(fr_covar_df2, "aveMaxTemp_")
aveMinTemp_mean <- get_before_treat_mean(fr_covar_df2, "aveMinTemp_")
avePr_mean <- get_before_treat_mean(fr_covar_df2, "avePrec_")

BA_sum <- get_before_treat_sum(fr_covar_df2, "BA_")
lc_mode <- get_before_treat_mode(fr_covar_df2, "lc_")
ui_mode <- get_before_treat_mode(fr_covar_df2, "UI_")


fr_covar_df3 <- fr_covar_df2 %>%  #combine each pre-treat covar mean 
  left_join(popd_mean, by = "row_id") %>%
  left_join(tt_mean, by = "row_id") %>%
  left_join(mcwd_mean, by = "row_id") %>%
  left_join(aveMaxTemp_mean, by = "row_id") %>%
  left_join(aveMinTemp_mean, by = "row_id") %>%
  left_join(avePr_mean, by = "row_id") %>%
  left_join(BA_sum, by = "row_id") %>%
  left_join(lc_mode, by = "row_id") %>%
  left_join(ui_mode, by = "row_id") %>%
  dplyr::select(-row_id) %>% 
  dplyr::select(names(.)[str_count(names(.), "\\.") <= 1])

#make a copy
aoi1_covar<-fr_covar_df3
aoi1_covar$treat<-1
rm(fr_site)
rm(fr_covar_df3)


#---------------Extract covars for NR / control site--------
covar_stack0<-rast(paste('covariates/tile_covar_stack_sav/',poly$Name,"_covar_stack.tif",sep=''), overwrite=TRUE)

aoi2<-vect('data/demo_data/forest_cube2.geojson')  
fr_site<-aoi2  ##[change to FR AOI]
fr_site$id<-1:length(fr_site)  
attr<-c('id',  'treatment_year')  
fr_site<-fr_site[,attr]

#combine covar with the FR attr
fr_covar_df<-terra::extract(covar_stack0, fr_site,method="simple", bind = FALSE, xy=T)
poly_attrs <- as.data.frame(fr_site)
fr_covar_df2 <- cbind(fr_covar_df, poly_attrs[fr_covar_df$ID, ])
fr_covar_df2<-fr_covar_df2 %>% mutate(row_id = row_number())

tt_mean <- get_before_treat_mean(fr_covar_df2, "travelTime_")
popd_mean <- get_before_treat_mean(fr_covar_df2, "popden_")
mcwd_mean <- get_before_treat_mean(fr_covar_df2, "MCWD_")
aveMaxTemp_mean <- get_before_treat_mean(fr_covar_df2, "aveMaxTemp_")
aveMinTemp_mean <- get_before_treat_mean(fr_covar_df2, "aveMinTemp_")
avePr_mean <- get_before_treat_mean(fr_covar_df2, "avePrec_")

BA_sum <- get_before_treat_sum(fr_covar_df2, "BA_")
lc_mode <- get_before_treat_mode(fr_covar_df2, "lc_")
ui_mode <- get_before_treat_mode(fr_covar_df2, "UI_")

fr_covar_df3 <- fr_covar_df2 %>%  #combine each pre-treat covar mean 
  left_join(popd_mean, by = "row_id") %>%
  left_join(tt_mean, by = "row_id") %>%
  left_join(mcwd_mean, by = "row_id") %>%
  left_join(aveMaxTemp_mean, by = "row_id") %>%
  left_join(aveMinTemp_mean, by = "row_id") %>%
  left_join(avePr_mean, by = "row_id") %>%
  left_join(BA_sum, by = "row_id") %>%
  left_join(lc_mode, by = "row_id") %>%
  left_join(ui_mode, by = "row_id") %>%
  dplyr::select(-row_id) %>%
  dplyr::select(names(.)[str_count(names(.), "\\.") <= 1])
names(fr_covar_df3)

#make a copy
aoi2_covar<-fr_covar_df3
aoi2_covar$treat<-0
rm(fr_covar_df3)
rm(fr_site)

#-------------------use cobalt for covar-balance assessment------------------------
library(cobalt)
library(ggplot2)
library(MatchIt)
library(fastDummies)

#-------------------biome1 nr and ar matching---------------
covars_oh0<-rbind(aoi1_covar, aoi2_covar)  
table(covars_oh0$treat)
covars_oh<- covars_oh0%>%
  mutate(trendMCWD=(MCWD_2008-MCWD_2003)/5,  #for AR that starts in 2009
         diffUI=(UI_2005-UI_2000),  #UI available every 5 years
         diffPopden=(popden_2000-popden_1990),  #popden available every 10 years
         travelTime_mean_5yrbefore_treatment=ifelse(is.na(travelTime_mean_5yrbefore_treatment), 
                                                    travelTime_2000, travelTime_mean_5yrbefore_treatment),
         trendPrec=(avePrec_2008-avePrec_2003)/5,
         trendMaxT=(aveMaxTemp_2008-aveMaxTemp_2003)/5,
         trendMinT=(aveMinTemp_2008-aveMinTemp_2003)/5)

f<-treat ~trendMCWD+ aspect+slope+diffUI + popden_mean_5yrbefore_treatment+
  travelTime_mean_5yrbefore_treatment + BA_sum_5yrbefore_treatment+aveMaxTemp_mean_5yrbefore_treatment

#filter out NA in covar
vars<-c(trendMCWD, aspect, slope, diffUI, popden_mean_5yrbefore_treatment,
          travelTime_mean_5yrbefore_treatment, BA_sum_5yrbefore_treatment, aveMaxTemp_mean_5yrbefore_treatment)
covars_oh<-covars_oh[complete.cases(covars_oh[, vars]), ]
covars_oh$p.score <- glm(f,data = covars_oh)$fitted.values


#filter for exact matching covars such as lc, soil texture
covars_oh2 <-covars_oh %>% #[need to change]
  group_by(soilTexture, lc_mode_5yrbefore_treatment) %>%
  filter(all(c(0, 1) %in% treat)) %>%
  ungroup()

bal.tab(f, data = covars_oh2,
        weights = "att.weights",
        # addl = ~ aspect+slope,
        int = TRUE, poly = 2)

table(covars_oh2$treat)

m.out <- MatchIt::matchit(f,
                          data = covars_oh2, 
                          method = "nearest",ratio =1,   #the ratio adjust how many controls get matched
                          replace = FALSE)
lp<-love.plot(m.out, thresholds = c(m = .25), drop.distance = F,title='Covariate balance for TSMBF NR and ANR')
lp
bal.tab(m.out)
matched_data <- MatchIt::match.data(m.out)
dim(matched_data)
# write.csv(matched_data, 'data/demo_data/biome1_AR_NT_matchedcells.csv')

