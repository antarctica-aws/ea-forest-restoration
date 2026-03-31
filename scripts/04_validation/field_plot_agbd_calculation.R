#description: 
#PART1 handles plot level AGBD calculation using monitoring data for the Lindi set from ForestPlots.net, 
#PART2 process plot level measurements into format for calculating AGBD change
#testing using the region specific allometry from 
###*plot crs epsg is 21096*###
setwd('.../EA_data')
require(geoR)
require(pls)
require(caret)
require(parallel)
require(doParallel)
require(raster)
require(sp)
require(data.table)
require(ggplot2)
require(ggpubr)
require(BIOMASS)
library(tidyr)
library(dplyr)
`%notin%` <- Negate(`%in%`)

#---------load functions-------------------------------------

fill_height <- function(data, metadata) {
  
  ii <- is.na(data$h.t) & !is.na(data$d.stem) & (data$d.stem > 0)
  if ( any(ii, na.rm=TRUE) ) {
    jj <- !is.na(data$d.stem) & !is.na(data$h.t) & (data$d.stem > 0) & (data$h.t > 0)
    if ( any(jj, na.rm=TRUE) ) {
      if ( "Height model" %in% metadata$Item ) {
        HDmodel <- BIOMASS::modelHD(D=data$d.stem[jj], H=data$h.t[jj], useWeight=TRUE,
                                    method=metadata$Value[metadata$Item == "Height model"])
        HDest <- BIOMASS::retrieveH(D=data$d.stem, model=HDmodel)
        data$h.t.mod <- HDest$H
        errH <- HDest$RSE
      } else {
        errH <- NA
      }
    } else {
      errH <- NA
    }
  } else {
    errH <- NA
    data$h.t.mode <- NA
  }
  
  list(data=data,HtModelRSE=errH)
}

treeAGB_localHD <- function (cleanDF){
  
  metadata <- data.frame(Item ='Height model', Value ='log1')
  
  ffdf_nah_filled <- cleanDF%>% dplyr::filter(!is.na(d.stem)) %>% fill_height(., metadata) %>% .$data
  ffdf_nah_filled$h_source  <-  ifelse(is.na(ffdf_nah_filled$h.t), 'modelled', 'original')
  ffdf_nah_filled$h.t  <-  ifelse(is.na(ffdf_nah_filled$h.t), ffdf_nah_filled$h.t.mod, ffdf_nah_filled$h.t)
  
  #after the gap filling steps before, recaluclate the AGB for the whole datfarame with the h.t
  aa <- ffdf_nah_filled #%>% dplyr::filter(DeadTree.1 %notin% c('dead tree (long ago)', 'recently dead tree'))
  aa$allom.name <-  c('chave2014a')
  aa$m.agb <- NA
  
  aa <-  aa %>% separate(Species, c("genus", "species"), " ", extra='drop')
  wsg <-  getWoodDensity(
    family = aa$Family,
    genus = aa$genus,
    species = aa$species,
    verbose = TRUE
  )
  aa$wsg <- wsg$meanWD
  
  ii <- is.na(aa$m.agb) & (aa$allom.name %in% c("chave2014a","chave2014b"))  
  if ( all(ii, na.rm=TRUE) ) {
    # print(ii)
    h.t.tmp <- aa$h.t[ii]
    jj <- is.na(h.t.tmp) | (h.t.tmp <= 0)
    h.t.tmp[jj] <- aa$h.t.mod[ii][jj]
    aa$m.agb[ii] <- BIOMASS::computeAGB(aa$d.stem[ii], aa$wsg[ii],coord=  coord)
    aa$allom.key[ii] <- 2
    aa$m.agb_local2[ii] <- exp(-1.881+2.561*log(aa$d.stem[ii])+0.909*log(aa$wsg[ii]))/1000 #the allometric equation calcs in kg 
  }
  return(aa)
}


treeAGB_DCoord <- function (aa, dColumn){
  aa <-  aa %>% separate(Species, c("genus", "species"), " ", extra='drop')
  wsg <-  getWoodDensity(
    family = aa$Family,
    genus = aa$genus,
    species = aa$species,
    verbose = TRUE
  )
  wsg <- wsg$meanWD
  m.agb <- BIOMASS::computeAGB(aa[,c(dColumn)]/10, wsg,coord= coord)
  m.agb_local2 <- exp(-2.73481+2.41305*log(aa[,c(dColumn)]/10))/1000 #the allometric equation resultss in kg, for all dry and shrub
  m.agb_local <- 0.1027*((aa[,c(dColumn)]/10)**2.4798)/1000 #the allometric equation results in kg, convert to mg, fo miobmo 
  agb_sub<-cbind(m.agb, m.agb_local, m.agb_local2)
  colnames(agb_sub)<-paste(dColumn, colnames(agb_sub),sep="_")
  return(agb_sub)
  
}


#-----------PART1: calculate tree-level AGB and plot-level AGBD-----------------------------

#all plots with the coordinates for tree-level AGB predictions 
plot_coords<-read.csv('validation/fp_lindi/all_plots_coords.csv') %>% 
  dplyr::mutate(PlotCode=as.character(PlotCode))

ps_files<-list.files('validation/fp_lindi', pattern='_FS', full.names = TRUE)

for (f in 1:length(ps_files)){   #this calculates tree-level AGB
  print(f)
  plotCode<-ps_files[f] %>% stringr::str_extract( "[A-Za-z_]{4}\\d+") %>%  gsub("_", "-", .)
  print(plotCode)
  plot_info<-plot_coords[plot_coords$PlotCode==plotCode,]
  coord<-c(plot_info$Logitude_2dp, plot_info$Latitude_2dp)
  #get the coordinates with the plot code
  df<-read.csv(ps_files[f])
  # Function to process strings
  process_strings <- function(x) {
    if (is.na(x)) {
      return("no_data")
    } else if (grepl("\\d+", x)) {  # Check if string contains numbers
      year_value <- gsub(".*?(\\d+).*", "year\\1", x)  # Extract numbers and add "year" in front
      return(year_value)
    } else {
      return(gsub(" ", "_", x))  # Replace spaces with underscores
    }
  }
  colnames_ori <- lapply(df[1,], as.character, as.is = TRUE)
  # Apply function to each element
  processed_colnames<- sapply(colnames_ori, process_strings)
  colnames(df)<-processed_colnames
  df <- df[-1, , drop = FALSE]#drop the first row 
  df <- df %>%
    dplyr::mutate(across(4:ncol(df), as.character)) %>% dplyr::mutate(across(4:ncol(df), as.numeric))  #change the factor to numerics
  
  print(head(df))
  df$PlotCode<- plot_info$PlotCode
  numeric_colnames <- grep("[0-9]", colnames(df), value = TRUE)
  
  for (n in numeric_colnames){
    print(n)
    t<-treeAGB_DCoord(df, n) %>% as.data.frame()
    df <-cbind(df, t)
    
    #summarizing the plot level agb and calc agbd density, and add to the plot_info entry 
    plot_totalAGB <- colSums(t, na.rm=TRUE)
    plot_agbd<- as.data.frame(plot_totalAGB/1)  #unit is mg/ha
    names(plot_agbd)<-n
    rownames(plot_agbd)<-c('Chave', 'local_miombo','local_dryforest')
    plot_agbd$allom <- rownames(plot_agbd)
    rownames(plot_agbd) <- NULL
    plot_info<-cbind(plot_info, plot_agbd)
    
  }

  # write.csv(plot_info, paste('validation/fp_lindi/', unique(plot_info$PlotCode),'_plotlevel_agbd_3allometry_rfmt.csv',sep=''))
  print(paste('finish calculating tree-level agb and plot-level agbd'))
  
}


#--------------Part 2: reorganize the plot-level agbd with different measure years into one csv ----------------
plot_agbd_f<-list.files('validation/fp_lindi', pattern='_rfmt.csv', full.names = TRUE)
plot_df<-read.csv(plot_agbd_f[1]) %>% dplyr::select(-c(allom.1, FirstName, LastName)) %>% 
  dplyr::mutate(year2017=NA, year2018=NA, year2021=NA)  #adding place holder columns since plots are measured at differet years


for (pa in 2:length(plot_agbd_f)){
  print(pa)
  pagbd<-read.csv(plot_agbd_f[pa])%>% dplyr::select(-c(contains("."), FirstName, LastName))

  missingcol<- setdiff(colnames(plot_df), colnames(pagbd))
  for (m in missingcol){
    print(m)
    pagbd[,m]<-NA
  }
  pagbd<-pagbd %>% dplyr::select(names(plot_df))
  
  plot_df<-rbind(plot_df, pagbd)
  
  
}

write.csv(plot_df,'validation/fp_lindi/plot_level_agbd_rfmt_by_year_3allometry.csv')
