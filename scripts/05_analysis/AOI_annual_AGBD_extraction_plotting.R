##This script extracts RS-derived annual AGBD for an AOI and plot overall trends and site-level trajectories
setwd('.../EA_data')
library(tidyr)
library(ggplot2)
library(ggpubr)
library(terra)
library(raster)

# load in the AOI: for restoration area, for validation plot locations, and for matched pixels
aoi<-vect('data/demo_data/forest_cube.geojson') 

# function for extraction
options(digits = 6)
AGBD_extract<-function(matchingR, dir){
  
  all_results <- list()
  pt1_files <- list.files(path = dir, pattern = "^agbd_.*100pt1", full.names = TRUE) #100 AGBD predictions are splitted into two tifs
  pt2_files <- list.files(path = dir, pattern = "^agbd_.*100pt2", full.names = TRUE)
  
  for (i in seq_along(pt1_files)) {
    pt1 <- rast(pt1_files[i])
    pt2 <- rast(pt2_files[i])
    
    names(pt1) <- paste0(
      'predYear', str_extract(names(pt1), "\\d{4}"),
      '_iter', sub(".*_(\\d+)$", "\\1", names(pt1))
    )
    names(pt2) <- paste0(
      'predYear', str_extract(names(pt2), "\\d{4}"),
      '_iter', as.numeric(sub(".*_(\\d+)$", "\\1", names(pt2))) + 50
    )
    
    # Extract using matchingR
    pairs_pt1 <- terra::extract(pt1, vect(matchingR), method = "simple", xy = TRUE, cells = TRUE, bind = TRUE)
    pairs_pt2 <- terra::extract(pt2, vect(matchingR), method = "simple", xy = TRUE, cells = TRUE, bind = TRUE)
    
    # Combine: avoid duplicate columns from bind
    pairs <- cbind(pairs_pt1, pairs_pt2[, !names(pairs_pt2) %in% names(pairs_pt1)])
    
    # Reshape to long format
    pairs2 <- values(pairs) %>%
      pivot_longer(cols = starts_with("pred"), names_to = "predYear", values_to = "predAGBD")
    
    pairs2$iter <- sub(".*_(.*)$", "\\1", pairs2$predYear)
    pairs2$predYear <- sub("^(.*)_.*$", "\\1", pairs2$predYear)
    
    # Reshape to wide format by iteration
    pairs3 <- pairs2 %>%
      pivot_wider(names_from = iter, values_from = predAGBD)
    
    # Add identifier for source file (optional)
    pairs3$source_file <- basename(pt1_files[i])
    
    # Store outputs
    all_results[[i]] <- pairs3
    print(paste("Processed:", basename(pt1_files[i]), "Rows:", nrow(pairs3)))
  }
  
  final_df <- dplyr::bind_rows(all_results)
  
  return(final_df)
  
}   #model prediction dir

#------run extraction over AOI-----------
pxAGBD_mt100<- AGBD_extract(aoi, 'agbd_predictions/aoi_ts_out_pred/')   

#calc mean and median from 100predictions for each year
pxAGBD_mt100$predAGBD_median<-apply(pxAGBD_mt0[, grep("^iter", names(pxAGBD_mt0))], 1, median, na.rm = TRUE)
pxAGBD_mt100$predAGBD_mean<-apply(pxAGBD_mt0[, grep("^iter", names(pxAGBD_mt0))], 1, mean, na.rm = TRUE)
pxAGBD_mt100$loc<-paste(pxAGBD_mt100$x, pxAGBD_mt100$y, sep="_")
# write.csv(pxAGBD_mt100,'data/demo_data/aoi_pixel_level_annual_agbd_mt.csv')

#-----1. visualize mean/median AGBD trend for each tretament year---------
 
pxAGBD_mt<-read.csv('data/demo_data/aoi_pixel_level_annual_agbd_mt.csv')

centralTrend<-pxAGBD_mt %>% 
  dplyr::mutate(manage_stratum =as.character(year)) %>% 
  dplyr::mutate(manage_stratum= sub("^","Plant year ", manage_stratum)) %>% 
  dplyr::group_by(manage_stratum, predYear) %>%   #can change which iteration you are plotting
  dplyr::summarise(meanAGBD=mean(predAGBD_mean,na.rm=T), medianAGBD=median(predAGBD_mean,na.rm=T), sd_agbd=sd(predAGBD_mean,na.rm=T)) %>% 
  pivot_longer(names_to='statistics', cols =c(meanAGBD, medianAGBD)) %>% 
  ggplot(data=., aes(x=predYear, y=value, group=statistics)) +
  facet_wrap(vars(manage_stratum))+
  geom_line(color='grey',linetype="dashed", size=0.7)+
  geom_point(aes(color=statistics), size=1)+
  theme_bw()+theme(legend.position = c(0.9, 0.08)) +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1))

centralTrend


#-----2. plot the agbd ts for each pixel and add the mean ts -----------------
library(dplyr)
stratum_stats <- pxAGBD_mt %>% 
  dplyr::group_by(predYear) %>% 
  dplyr::summarise(meanAGBD=mean(predAGBD_mean,na.rm=T), medianAGBD=median(predAGBD_mean,na.rm=T), 
                   sd_agbd=sd(predAGBD_mean,na.rm=T)) %>%ungroup()

site_stats <- pxAGBD_mt %>%  
  dplyr::select( predYear, predAGBD_mean, loc) %>% 
  dplyr::left_join(stratum_stats, by = c('predYear')) %>% 
  dplyr::mutate(type='Model_estimate')

library(stringr)
site_ts <-site_stats %>% 
  mutate( predYear= as.numeric(str_extract(predYear, "\\d+"))) %>% 
          # treatYear = as.numeric(str_extract(manage_stratum, "\\d+")),  #if the AOI are the matched pairs or restoration areas
          # manage_stratum=ifelse(treat==0,'NR', paste('AR started in', treatYear, sep=' '))) %>% 
  ggplot(., aes(x = predYear)) +
  geom_line(aes(y = predAGBD_mean*0.457, group = loc), color = "gray70", alpha = 0.5) +  #C conversion for this biome
  geom_line(aes(y = meanAGBD*0.457, group=1), color = "red", size = 1.2) +
  labs(x = "Year of Estimation", y = "Estimated AGC (Mg C /ha)",
       title='AOI pixel level AGC') +
  theme_bw()+
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
        text = element_text(family = 'serif' , size=12),plot.title = element_text(size = 14))+
  theme(strip.background =element_rect(fill="white"))+
  # geom_vline( aes(xintercept = treatYear), label = "Treatment start", color = "cyan", linetype = "dashed")+
  ylim(c(0,200))

site_ts

# ggsave('data/Fig/agbd_ts_pixel/site_level_trends_AOI.png',site_ts,
       # width =5000, height =5600, units = 'px', dpi=500 )