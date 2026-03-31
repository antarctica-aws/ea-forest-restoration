##This script calculates the climate mitigation benefit from AR, ANR, and NR in three biomes 
###for 2030 and 2050, over suitable restoration areas (tested using different maps)
### but used the Griscom et al one because it matches the Cook-Patton et al 

setwd('.../EA_data')
library(tidyr)
library(ggplot2)
library(ggpubr)
library(terra)
library(did)
library(raster)
`%notin%` <- Negate(`%in%`)

#---------------Map 1: Martin Jung et al (2021) restor opportunity map only--------------######


rateMap2 <- raster('NCS_Refor11_map_with_description_zip/cookpatton_EA_reprj2.tif')

restorMap2 <- raster('NatureMap_prioritymaps/ea_reprj.tif')
restorMap2[restorMap2<50]<-NA
## reproject to equal area  [much faster in qgis]
prj <- '+proj=moll +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +units=m +no_defs'

poly <- vect('AOI/EA_one.shp') %>% 
  project(., CRS(prj))

#resample rate map to match 1km raster 
ras1km <- raster('NCS_Refor11_map_with_description_zip/wwf_ea_1km.tif')
rateMap2_res <- resample( rateMap2,ras1km, method='bilinear')
restorMap2_res <- resample( restorMap2,ras1km, method='bilinear')

# extract the NR rate over restoration areas 
rateMap2_res[is.na(values(restorMap2_res))] <- NA   

names(rateMap2_res) <- 'cookpatton_NR_rate'

print(sum(is.na(rateMap2_res[])))   
print(length(rateMap2_res[]))
print(length(rateMap2_res[])- sum(is.na(rateMap2_res[])))


#---------------Map 2: Griscom et al 2017 map only [choosen because match with Cook-Patton]-----------------######

rateMap2 <- raster('NCS_Refor11_map_with_description_zip/cookpatton_griscom_reprj.tif')

restorMap2 <- raster('NatureMap_prioritymaps/ea_reprj.tif')

# reproject to equal area 
prj <- '+proj=moll +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +units=m +no_defs'

poly <- vect('AOI/EA_one.shp') %>% 
  project(., CRS(prj))

#resample rate map to match 1km raster 
ras1km <- raster('NCS_Refor11_map_with_description_zip/wwf_ea_1km.tif')

rateMap2_res <- raster::resample( rateMap2,ras1km, method='bilinear')
restorMap2_res <- raster::resample( restorMap2,ras1km, method='bilinear')

names(rateMap2_res) <- 'cookpatton_NR_rate'

print(sum(is.na(rateMap2_res[]))) 
print(length(rateMap2_res[]))
print(length(rateMap2_res[])- sum(is.na(rateMap2_res[])))


#the same for the NR rate error ratio map

rateMap3 <- raster('NCS_Refor11_map_with_description_zip/cookpattonER_griscom_reprj.tif')

restorMap2 <- raster('NatureMap_prioritymaps/ea_reprj.tif')

## reproject to equal area  [much faster in qgis]
prj <- '+proj=moll +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +units=m +no_defs'

poly <-vect('AOI/EA_one.shp') %>% 
  project(., CRS(prj))

#resample rate map to match 1km raster 
ras1km <- raster('NCS_Refor11_map_with_description_zip/wwf_ea_1km.tif')

rateMap3_res <- raster::resample( rateMap3,ras1km, method='bilinear')
restorMap2_res <- raster::resample( restorMap2,ras1km, method='bilinear')

names(rateMap3_res) <- 'cookpatton_NR_rate_ER'

print(sum(is.na(rateMap3_res[])))   
print(length(rateMap3_res[]))
print(length(rateMap3_res[])- sum(is.na(rateMap3_res[])))

#####   stack rateMap2 & rateMap3   ###

rateMap2_res <- stack(rateMap2_res, rateMap3_res)

#---------------biome level dynamic rate calculation-----------------------------

biome1 <- vect('AOI/ea_tsmbf.geojson') %>% 
  project(., 'EPSG:6933')
biome7 <- vect('AOI/ea_tsgss.geojson') %>% 
  project(., 'EPSG:6933')
biome10 <- vect('AOI/ea_mf.geojson') %>% 
  project(., 'EPSG:6933')

rateMap2_res<-terra::project(rast(rateMap2_res),'EPSG:6933')

restorBiome1_v2<- terra::crop(rateMap2_res, biome1) %>% mask(.,biome1)
restorBiome7_v2 <- terra::crop(rateMap2_res, biome7) %>% mask(.,biome7)
restorBiome10_v2 <- terra::crop(rateMap2_res, biome10) %>% mask(.,biome10)


#calculate AGC per unit area for NR: unit area x NRrate
restorBiome1_df2 <- as.data.frame(restorBiome1_v2) %>% 
  dplyr::filter(!is.na(cookpatton_NR_rate)) %>% 
  dplyr::rename(NRrate = cookpatton_NR_rate) %>% 
  dplyr::mutate(NRrate = NRrate/0.47*0.456) %>% #biome specific conversion
  dplyr::mutate(NRse = NRrate*cookpatton_NR_rate_ER) %>% dplyr::select(-c(cookpatton_NR_rate_ER))
dim(restorBiome1_df2)

restorBiome7_df2 <- as.data.frame(restorBiome7_v2) %>% 
  dplyr::filter(!is.na(cookpatton_NR_rate)) %>%  
  dplyr::rename(NRrate =cookpatton_NR_rate) %>% 
  dplyr::mutate(NRrate = NRrate/0.47*0.457) %>% #biome specific conversion
  dplyr::mutate(NRse = NRrate*cookpatton_NR_rate_ER) %>% dplyr::select(-c(cookpatton_NR_rate_ER))
dim(restorBiome7_df2)

restorBiome10_df2 <- as.data.frame(restorBiome10_v2) %>% 
  dplyr::filter(!is.na(cookpatton_NR_rate)) %>%  
  dplyr::rename(NRrate = cookpatton_NR_rate) %>% 
  dplyr::mutate(NRrate = NRrate/0.47*0.465) %>%  #biome specific conversion
  dplyr::mutate(NRse = NRrate*cookpatton_NR_rate_ER) %>% dplyr::select(-c(cookpatton_NR_rate_ER))
dim(restorBiome10_df2)

### calculate C stock in NR ###
pixelSize2  <-  1.043275*1.043275*100 #correction for pixel size from the WRI products, unit is hectare, from sq km to ha
#biome 1 
cBiome1_df2 <- restorBiome1_df2 %>%  
  dplyr::mutate(NR_carbon_9yrs= NRrate * pixelSize2*9,  #unit is Mg
                NR_carbon_29yrs= NRrate * pixelSize2*29,
                NR_carbon_30yrs= NRrate * pixelSize2*30, 
                NR_carbonSE_9yrs= NRse * pixelSize2*9,  #unit is Mg
                NR_carbonSE_29yrs= NRse * pixelSize2*29,
                NR_carbonSE_30yrs= NRse * pixelSize2*30, 
                n=length(NRrate), biome='TSMBF')
cBiome1_df2 %>% head

cBiome1_v2 <- cBiome1_df2 %>% 
  dplyr::mutate(meanNRrate = mean(NRrate, na.rm=T),
                meanNRse = mean(NRse, na.rm=T),
                totalNR_C9yrs = sum(NR_carbon_9yrs)/1000000000,
                totalNR_C29yrs = sum(NR_carbon_29yrs)/1000000000,
                totalNR_C30yrs = sum(NR_carbon_30yrs)/1000000000,
                totalNRse_C9yrs = sum(NR_carbonSE_9yrs, na.rm=T)/1000000000,
                totalNRse_C29yrs = sum(NR_carbonSE_29yrs, na.rm=T)/1000000000,
                totalNRse_C30yrs = sum(NR_carbonSE_30yrs, na.rm=T)/1000000000,
                n = unique(n), 
                areaMillHa = n * pixelSize2/ 1000000, #unit is million hectare
                biome='TSMBF') %>% 
  dplyr::select(n, areaMillHa, biome,  meanNRrate,meanNRse, totalNR_C9yrs, totalNR_C29yrs, totalNR_C30yrs ,
                totalNRse_C9yrs, totalNRse_C29yrs, totalNRse_C30yrs) %>% dplyr::distinct()
cBiome1_v2

#biome 7 
cBiome7_df2 <- restorBiome7_df2 %>%  
  dplyr::mutate(NR_carbon_9yrs= NRrate * pixelSize2*9,  #unit is Mg
                NR_carbon_29yrs= NRrate * pixelSize2*29,
                NR_carbon_30yrs= NRrate * pixelSize2*30, 
                NR_carbonSE_9yrs= NRse * pixelSize2*9,  #unit is Mg
                NR_carbonSE_29yrs= NRse * pixelSize2*29,
                NR_carbonSE_30yrs= NRse * pixelSize2*30, 
                n=length(NRrate), biome ='TSGSS')
cBiome7_df2 %>% head
cBiome7_v2 <- cBiome7_df2 %>% 
  dplyr::mutate(meanNRrate = mean(NRrate, na.rm=T),
                meanNRse = mean(NRse, na.rm=T),
                totalNR_C9yrs = sum(NR_carbon_9yrs)/1000000000,
                totalNR_C29yrs = sum(NR_carbon_29yrs)/1000000000,
                totalNR_C30yrs = sum(NR_carbon_30yrs)/1000000000,
                totalNRse_C9yrs = sum(NR_carbonSE_9yrs, na.rm=T)/1000000000,
                totalNRse_C29yrs = sum(NR_carbonSE_29yrs, na.rm=T)/1000000000,
                totalNRse_C30yrs = sum(NR_carbonSE_30yrs, na.rm=T)/1000000000,
                n = unique(n), areaMillHa = n * pixelSize2/ 1000000, #unit is million hectare
                biome='TSGSS') %>% 
  dplyr::select(n, areaMillHa, biome,  meanNRrate,meanNRse, totalNR_C9yrs, totalNR_C29yrs, totalNR_C30yrs ,
                totalNRse_C9yrs, totalNRse_C29yrs, totalNRse_C30yrs) %>% dplyr::distinct()
cBiome7_v2

#biome10
cBiome10_df2 <- restorBiome10_df2 %>%  
  dplyr::mutate(NR_carbon_9yrs= NRrate * pixelSize2*9,  #unit is Mg
                NR_carbon_29yrs= NRrate * pixelSize2*29, 
                NR_carbon_30yrs= NRrate * pixelSize2*30, 
                NR_carbonSE_9yrs= NRse * pixelSize2*9,  #unit is Mg
                NR_carbonSE_29yrs= NRse * pixelSize2*29,
                NR_carbonSE_30yrs= NRse * pixelSize2*30, 
                n=length(NRrate),biome='MGS' )
cBiome10_df2 %>% head
cBiome10_v2 <- cBiome10_df2 %>% 
  dplyr::mutate(meanNRrate = mean(NRrate, na.rm=T),
                meanNRse = mean(NRse, na.rm=T),
                totalNR_C9yrs = sum(NR_carbon_9yrs)/1000000000,  #Gt
                totalNR_C29yrs = sum(NR_carbon_29yrs)/1000000000,
                totalNR_C30yrs = sum(NR_carbon_30yrs)/1000000000,
                totalNRse_C9yrs = sum(NR_carbonSE_9yrs, na.rm=T)/1000000000,
                totalNRse_C29yrs = sum(NR_carbonSE_29yrs, na.rm=T)/1000000000,
                totalNRse_C30yrs = sum(NR_carbonSE_30yrs, na.rm=T)/1000000000,
                n = unique(n), areaMillHa = n * pixelSize2/ 1000000, #unit is million hectare
                biome='MGS') %>% 
  dplyr::select(n, areaMillHa, biome,  meanNRrate,meanNRse, totalNR_C9yrs, totalNR_C29yrs, totalNR_C30yrs ,
                totalNRse_C9yrs, totalNRse_C29yrs, totalNRse_C30yrs) %>% dplyr::distinct()
cBiome10_v2

cEA2 <- rbind(cBiome1_v2, cBiome7_v2, cBiome10_v2) 


# calculate carbon per unit areas for AR and ARR 

ATTtable0 <- read.csv('ATT_calc/group_att_table.csv')  

ATTtable <- ATTtable0 %>%  #convert ATT from AGB to C
  mutate(across(
    .cols = 4:9,
    .fns  = ~ .x * case_when(
      biome == "TSMBF" ~ 0.456,
      biome == "TSGSS" ~ 0.457,
      biome == "MGS" ~ 0.465,
      TRUE ~ 1         # default
    )
  ))


ATT_imp <- ATTtable %>% dplyr::left_join(cEA2, by='biome') %>% #this is for aggregating the C for short- and long-term FR
  dplyr::mutate(aveFRrate= Average +meanNRrate,
                longtermFRrate = longTerm + meanNRrate, 
                shorttermFRrate = shortTerm + meanNRrate) %>% 
  dplyr::mutate(aveFRrate_se= Average_se + meanNRse,            #adding NR SE and AR/ANR SE for FR SE 
                longtermFRrate_se = longTerm_se + meanNRse, 
                shorttermFRrate_se = shortTerm_se + meanNRse) %>% 
  dplyr::mutate(aveFR_C9yrs = aveFRrate *9*(n*pixelSize2) /1000000000,   #Gt
                aveFR_C29yrs= aveFRrate *29*(n*pixelSize2) /1000000000,
                stFR_C9yrs= shorttermFRrate *9*(n*pixelSize2) /1000000000,
                ltFR_C29yrs= longtermFRrate *29*(n*pixelSize2) /1000000000,
                ltFR_C30yrs= longtermFRrate *30*(n*pixelSize2) /1000000000) %>% 
  dplyr::mutate(aveFR_C9yrs_se = aveFRrate_se *9*(n*pixelSize2) /1000000000,   #Gt
                aveFR_C29yrs_se= aveFRrate_se *29*(n*pixelSize2) /1000000000,
                stFR_C9yrs_se= shorttermFRrate_se *9*(n*pixelSize2) /1000000000,
                ltFR_C29yrs_se= longtermFRrate_se*29*(n*pixelSize2) /1000000000,
                ltFR_C30yrs_se= longtermFRrate_se *30*(n*pixelSize2) /1000000000) %>% 
  dplyr::select(biome, FR,n, stFR_C9yrs, ltFR_C29yrs, ltFR_C30yrs, stFR_C9yrs_se, ltFR_C29yrs_se, ltFR_C30yrs_se)

ATT_nr0 <- ATTtable %>% dplyr::left_join(cEA2, by='biome') %>% #getting the rates to compile Table 1
  dplyr::mutate(aveFRrate= Average +meanNRrate,
                longtermFRrate = longTerm + meanNRrate, 
                shorttermFRrate = shortTerm + meanNRrate) %>% 
  dplyr::mutate(aveFR_C9yrs = aveFRrate *9*(n*pixelSize2) /1000000000,   #Gt
                aveFR_C29yrs= aveFRrate *29*(n*pixelSize2) /1000000000,
                stFR_C9yrs= shorttermFRrate *9*(n*pixelSize2) /1000000000,
                ltFR_C29yrs= longtermFRrate *29*(n*pixelSize2) /1000000000,
                ltFR_C30yrs= longtermFRrate *30*(n*pixelSize2) /1000000000) %>% 
  dplyr::mutate(FR='NR') 

sum(unique(ATT_nr0$n)*pixelSize2 )  #getting total restoration area in hectare   


ATT_nr <- ATTtable %>% dplyr::left_join(cEA2, by='biome') %>% 
  dplyr::mutate(aveFRrate= Average +meanNRrate,
                longtermFRrate = longTerm + meanNRrate, 
                shorttermFRrate = shortTerm + meanNRrate) %>% 
  dplyr::mutate(aveFRrate_se= Average_se + meanNRse,            #adding NR SE and AR/ANR SE for FR SE 
                longtermFRrate_se = longTerm_se + meanNRse, 
                shorttermFRrate_se = shortTerm_se + meanNRse) %>% 
  dplyr::mutate(aveFR_C9yrs = aveFRrate *9*(n*pixelSize2) /1000000000,   #Gt
                aveFR_C29yrs= aveFRrate *29*(n*pixelSize2) /1000000000,
                stFR_C9yrs= shorttermFRrate *9*(n*pixelSize2) /1000000000,
                ltFR_C29yrs= longtermFRrate *29*(n*pixelSize2) /1000000000,
                ltFR_C30yrs= longtermFRrate *30*(n*pixelSize2) /1000000000) %>% 
  dplyr::mutate(aveFR_C9yrs_se = aveFRrate_se *9*(n*pixelSize2) /1000000000,   #Gt
                aveFR_C29yrs_se= aveFRrate_se *29*(n*pixelSize2) /1000000000,
                stFR_C9yrs_se= shorttermFRrate_se *9*(n*pixelSize2) /1000000000,
                ltFR_C29yrs_se= longtermFRrate_se*29*(n*pixelSize2) /1000000000,
                ltFR_C30yrs_se= longtermFRrate_se *30*(n*pixelSize2) /1000000000) %>% 
  dplyr::mutate(FR='NR') %>%    #up till here same, just select the NR-related columns
  dplyr::select(biome, FR, n, totalNR_C9yrs, totalNR_C29yrs, totalNR_C30yrs, totalNRse_C9yrs, totalNRse_C29yrs, totalNRse_C30yrs)


colnames(ATT_imp) <- colnames(ATT_nr)

ATT_comb <- ATT_imp %>% rbind(ATT_nr) %>% 
  pivot_longer(cols = c(totalNR_C9yrs, totalNR_C29yrs,  totalNR_C30yrs, totalNRse_C9yrs, totalNRse_C29yrs,  totalNRse_C30yrs),
               names_to = "time_horizon",
               values_to = "C_stock") %>% dplyr::distinct() %>% dplyr::arrange(biome) %>% data.frame() %>% 
  dplyr::mutate(value = ifelse(grepl('se',time_horizon, fixed = TRUE), 'C_SE','C_stock')) %>% 
  dplyr::mutate(time_horizon = sub("^[^_]*_", "", time_horizon)) %>% 
  pivot_wider(names_from = value, values_from= C_stock)

ATT_comb %>% data.frame()

#summing up short / long term by FR 
ATT_comb %>% dplyr::group_by(time_horizon, FR) %>% dplyr::summarise(biome=unique(biome),sumC =sum(C_stock), SE= sum(C_SE)) %>% 
  dplyr::arrange(biome) %>% print()   #total by FR x biome


ATT_comb %>% dplyr::group_by(time_horizon, biome) %>% dplyr::top_n(1, C_stock) %>% 
  dplyr::arrange(biome)%>% print()   #picking out the best by biome, right side of Table 1
  
ATT_comb %>% dplyr::group_by(time_horizon, biome) %>% dplyr::top_n(1, C_stock)%>%   #summing C for two time horizon using the best FR
  dplyr::group_by(time_horizon) %>% dplyr::summarise(sumC =sum(C_stock), seC = sum(C_SE))%>% print()

#---------------make stacked bar chart--------------
library(viridis)
library(hrbrthemes)
restoredC_dynamic <- ATT_comb %>% dplyr::filter(time_horizon %notin% c("C30yrs")) %>% 
  dplyr::mutate(time_horizon=factor(time_horizon, levels =c('C9yrs', 'C29yrs')),
                FR =factor(FR, levels=c('NR', 'ANR', 'AR')),
                biome=factor(biome,
                             labels = c('Montane shrublands & forests','Savannas & dry forests','Tropical moist forests'))) %>% 
  ggplot(., aes(fill=FR, y=C_stock, x=biome)) + 
  geom_bar(position="dodge", stat="identity", width = 0.8) +
  geom_errorbar( aes(x=biome, ymin=C_stock-C_SE, ymax=C_stock+C_SE), position=position_dodge(width = 0.8),
                 width=0.1, size=0.3, colour="black", alpha=0.9)+
  facet_wrap(vars(time_horizon), labeller = labeller(time_horizon = 
                                                       c("C9yrs" = "C removal capacity by restoring suitable areas by 2030",
                                                         "C29yrs" = "C removal capacity by restoring suitable areas by 2050") ))+
  scale_fill_manual(values = c("#159122", "#663695", "#1071f4" ),name='Forest restortaion stretagies', 
                    labels=c('Natural Regeneration','Assisted Natural Regeneration','Active Restoration'))+
  theme_bw()+ ylim(c(-0.1,1.6))+
  theme( plot.margin = margin(0,0,0,2, "cm"),panel.spacing = unit(1, "lines"))+
  theme(strip.background.x=element_blank() ,strip.background.y =element_rect(fill="grey", color='white'),
        strip.text = element_text(size=18,family = 'serif',face = "bold" ),
        axis.title.y = element_text( size =18, angle = 90, hjust = .5, vjust = 1,family = 'serif'),
        axis.text.y = element_text(size=16, vjust=1, hjust=1, family = 'serif'),
        axis.text.x = element_text(angle=16,size=16, vjust=1, hjust=1, family = 'serif'))+
  theme(legend.text=element_text(size=18,family = 'serif' ),legend.title=element_text(size=18,family = 'serif'))

restoredC_dynamic


tag_facet2 <-  function(p, open="", close = ")", tag_pool =letters, x = 0, y = 0.3, hjust = 0, vjust = 0.3,  
                        fontface = 2, family="serif",  tag_size = 14,...){
  gb <- ggplot_build(p)
  lay <- gb$layout$layout
  nm <- names(gb$layout$facet$params$rows)
  
  tags <- paste0(open,tag_pool[unique(lay$COL)],close)
  
  tl <- lapply(tags, grid::textGrob, x=x, y=y,
               hjust=hjust, vjust=vjust, gp=grid::gpar(fontface=fontface, family="serif", fontsize = tag_size))
  
  g <- ggplot_gtable(gb)
  g <- gtable::gtable_add_rows(g, grid::unit(1,"line"), pos = 0)
  lm <- unique(g$layout[grepl("panel",g$layout$name), "l"])
  g <- gtable::gtable_add_grob(g, grobs = tl, t=1, l=lm)
  grid::grid.newpage()
  grid::grid.draw(g)
  return(g)
}

t <- tag_facet2(restoredC_dynamic)

# ggsave('Fig/Fig4_carbon_implictaion_dynamic_SE_mt100.png',t,width =9000, height =4200, units = 'px', dpi=500 )


#---------------checking the C implictaion with average values ---------------

ATT_ave <- ATTtable %>% dplyr::left_join(cEA2, by='biome') %>% 
  dplyr::mutate(aveFRrate= Average +meanNRrate,
                longtermFRrate = longTerm + meanNRrate, 
                shorttermFRrate = shortTerm + meanNRrate) %>% 
  dplyr::mutate(aveFRrate_se= Average_se + meanNRse,            #adding NR SE and AR/ANR SE for FR SE 
                longtermFRrate_se = longTerm_se + meanNRse, 
                shorttermFRrate_se = shortTerm_se + meanNRse) %>% 
  dplyr::mutate(aveFR_C9yrs = aveFRrate *9*(n*pixelSize2) /1000000000,   #Gt
                aveFR_C29yrs= aveFRrate *29*(n*pixelSize2) /1000000000,
                aveFR_C30yrs= aveFRrate *30*(n*pixelSize2) /1000000000,
                stFR_C9yrs= shorttermFRrate *9*(n*pixelSize2) /1000000000,
                ltFR_C29yrs= longtermFRrate *29*(n*pixelSize2) /1000000000,
                ltFR_C30yrs= longtermFRrate *30*(n*pixelSize2) /1000000000) %>% 
  dplyr::mutate(aveFR_C9yrs_se = aveFRrate_se *9*(n*pixelSize2) /1000000000,   #Gt
                aveFR_C29yrs_se= aveFRrate_se *29*(n*pixelSize2) /1000000000,
                aveFR_C30yrs_se= aveFRrate_se *30*(n*pixelSize2) /1000000000,
                stFR_C9yrs_se= shorttermFRrate_se *9*(n*pixelSize2) /1000000000,
                ltFR_C29yrs_se= longtermFRrate_se*29*(n*pixelSize2) /1000000000,
                ltFR_C30yrs_se= longtermFRrate_se *30*(n*pixelSize2) /1000000000) %>% 
  dplyr::select(biome, FR,n,  aveFR_C9yrs, aveFR_C29yrs, aveFR_C30yrs, aveFR_C9yrs_se, aveFR_C29yrs_se, aveFR_C30yrs_se)

colnames(ATT_ave) <- colnames(ATT_nr)

ATT_comb2 <-ATT_ave %>% rbind(ATT_nr) %>% 
  pivot_longer(cols = c(totalNR_C9yrs, totalNR_C29yrs,  totalNR_C30yrs, totalNRse_C9yrs, totalNRse_C29yrs,  totalNRse_C30yrs),
               names_to = "time_horizon",
               values_to = "C_stock") %>% dplyr::distinct() %>% dplyr::arrange(biome) %>% data.frame() %>% 
  dplyr::mutate(value = ifelse(grepl('se',time_horizon, fixed = TRUE), 'C_SE','C_stock')) %>% 
  dplyr::mutate(time_horizon = sub("^[^_]*_", "", time_horizon)) %>% 
  pivot_wider(names_from = value, values_from= C_stock) 

ATT_comb2 %>% data.frame()

#summing up short / long term by FR 
ATT_comb2 %>% dplyr::group_by(time_horizon, FR) %>% dplyr::summarise(sumC =sum(C_stock), SE= sum(C_SE)) %>% print()   #total by FR x biome

ATT_comb2 %>% dplyr::group_by(time_horizon, biome) %>% dplyr::top_n(1, C_stock) %>% 
  dplyr::arrange(biome)%>% print()   #picking out the best by biome

ATT_comb2 %>% dplyr::group_by(time_horizon, biome) %>% dplyr::top_n(1, C_stock)%>%   #summing C for two time horizon using the best FR
  dplyr::group_by(time_horizon) %>% dplyr::summarise(sumC =sum(C_stock), seC = sum(C_SE))%>% print()

#--------plot the stacking charts---------
restoredC_ave <- ATT_comb2 %>% dplyr::filter(time_horizon %notin% c("C30yrs")) %>% 
  dplyr::mutate(time_horizon=factor(time_horizon, levels =c('C9yrs', 'C29yrs')),
                FR =factor(FR, levels=c('NR', 'ANR', 'AR')),
                biome=factor(biome,
                             labels = c('Montane shrublands & forests','Savannas & dry forests','Tropical moist forests'))) %>% 
  ggplot(., aes(fill=FR, y=C_stock, x=biome)) + 
  geom_bar(position="dodge", stat="identity", width = 0.8) +
  geom_errorbar( aes(x=biome, ymin=C_stock-C_SE, ymax=C_stock+C_SE), position=position_dodge(width = 0.8),
                 width=0.1, size=0.3, colour="black", alpha=0.9)+
  facet_wrap(vars(time_horizon), labeller = labeller(time_horizon = 
                                                       c("C9yrs" = "C removal capacity by restoring suitable areas by 2030",
                                                         "C29yrs" = "C removal capacity by restoring suitable areas by 2050") ))+
  scale_fill_manual(values = c("#159122", "#663695", "#1071f4" ),name='Forest restortaion stretagies', 
                    labels=c('Natural Regeneration','Assisted Natural Regeneration','Active Restoration'))+
  ylim(c(-0.1,1.6))+
  theme_bw()+ 
  xlab("")+ylab("C removal capacity (Gt C)")+
  theme( plot.margin = margin(0,0,0,2, "cm"),panel.spacing = unit(1, "lines"))+
  theme(strip.background.x=element_blank() ,strip.background.y =element_rect(fill="grey", color='white'),
        strip.text = element_text(size=18,family = 'serif',face = "bold" ),
        axis.title.y = element_text( size =18, angle = 90, hjust = .5, vjust = 1,family = 'serif'),
        axis.text.y = element_text(size=16, vjust=1, hjust=1, family = 'serif'),
        axis.text.x = element_text(angle=16,size=16, vjust=1, hjust=1, family = 'serif'))+
  theme(legend.text=element_text(size=18,family = 'serif' ),legend.title=element_text(size=18,family = 'serif'))

restoredC_ave


t2 <- tag_facet2(restoredC_ave)

ggsave('Fig/Fig4_carbon_implictaion_average_SE_mt100.png',t2,width =9000, height =4200, units = 'px', dpi=500 )

