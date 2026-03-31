##This script estimate the ATT for AR/ANR as treated group and NR as control for a given biome 
##using did by Callaway & Sant'Anna 2025  https://bcallaway11.github.io/did/articles/did-basics.html
setwd('.../EA_FR_data')
library(tidyr)
library(ggplot2)
library(ggpubr)
library(terra)
library(did)

#read in AGBD estimates extracted for matched cells
pxAGBD_mt <- read.csv('data/demo_data/matchedAOI_pixel_level_annual_agbd_mt.csv')

#-------1. calculate pixel-level AGBD change------------
library(zoo)
`%notin%` <- function(x, y) !(x %in% y)
excludeYear<-c(paste0('predYear',c(1986)))

pxAGBD_mt %>%   #[*key function*]
  dplyr::mutate(predYear=as.character(predYear)) %>% 
  dplyr::filter(predYear %notin% excludeYear) %>%
  dplyr::mutate(tname= as.numeric(str_extract(predYear, "\\d+")), manage_stratum =as.character(year)) %>% 
  dplyr::mutate(manage_stratum= sub("^","Plant year ", manage_stratum)) %>%
  arrange(loc, predYear) %>%
  group_by(loc) %>%  #cell id is more accurate than loc
  mutate(    #this step can be changed to AGBD from other iteration 
    agbd_change = ifelse(is.na(predAGBD_mean) | is.na(lag(predAGBD_mean)),NA,
                         predAGBD_mean - lag(predAGBD_mean)),
    agbd_change_3yr_avg = rollmean(agbd_change, k =3, fill = NA, align = "center"),  
    pre_agbd_mean = mean(predAGBD_mean[tname < year[1]], na.rm = TRUE),
    agbd_to_prev= ((predAGBD_mean - pre_agbd_mean) / pre_agbd_mean) * 100,
    nVal=sum(!is.na(agbd_change))) %>% 
  ungroup() %>% 
  mutate(first.treat=year) %>% 
  mutate(first.treat = case_when(
    first.treat == 1990 ~ 0,
    first.treat %in% c(2000:2002) ~ 2002,
    first.treat %in% c(2003:2005) ~ 2005,
    first.treat %in% c(2010:2012) ~ 2012,
    TRUE ~ first.treat  # Optional: handles unmatched cases
  ))->t



pxAGBD_meandf<-t %>% dplyr::select(c( "loc" ,"x","y" ,"year","predYear","predAGBD_mean",'first.treat','BA_1995',
                                      "manage_stratum","agbd_change",'agbd_to_prev',"agbd_change_3yr_avg",'travelTime_2000',
                                      'slope','dem','MCWD_2013','MCWD_mean_5yrbefore_treatment','popden_2000','aspect','aveMinTemp_2005','aveMaxTemp_2005')) %>% 
  mutate(tname= as.numeric(str_extract(predYear, "\\d+")),  loc2=as.numeric(as.factor(loc)))


#-------2. estimate group-time average treatment effects with mean AGBD-----

set.seed(1814)
example_attgt <- att_gt(yname = "agbd_change_3yr_avg",
                        tname = "tname",
                        idname = "loc2",
                        gname = "first.treat",
                        xformla = ~1,
                        control_group = "nevertreated",
                        allow_unbalanced_panel=TRUE,
                        print_details=TRUE,bstrap=T,cband=T,
                        data = pxAGBD_meandf,pl=TRUE, cores = 8, biters = 5000
)
summary(example_attgt)
ggdid(example_attgt)

agg.gs <- aggte(example_attgt, type = "group", na.rm = TRUE)
summary(agg.gs)
ggdid(agg.gs)

agg.simple <- aggte(example_attgt, type = "simple", na.rm = TRUE)
summary(agg.simple)

#dynamic aggregate
agg.es <- aggte(example_attgt, type = "dynamic", na.rm = TRUE)  #anticipation = 1 removves the outlier forgroupsbefore2019
summary(agg.es)
ggdid(agg.es)



#-------3. below is a function for running ATT with 100 AGBD estimates------

excludeYear<-paste0('predYear',c(1986)) 

ATTinter<-function(df, keepIter){   
  pattern <- 'predAGBD_'
  
  drop_indices <- grep(pattern, names(df), value = TRUE)
  keep <- paste0(pattern,"", keepIter)
  
  to_drop <- setdiff(drop_indices, keep)
  
  df_new <- dplyr::select(df, -all_of(to_drop)) %>% 
    rename(predAGBD_iterX = all_of(keep))
  
  df_new %>%  
    dplyr::mutate(predYear=as.character(predYear)) %>% 
    dplyr::filter(predYear %notin% excludeYear) %>%
    dplyr::mutate(tname= as.numeric(str_extract(predYear, "\\d+")), manage_stratum =as.character(year)) %>% 
    dplyr::mutate(manage_stratum= sub("^","Plant year ", manage_stratum)) %>%
    arrange(loc, predYear) %>%
    group_by(loc) %>%  #cell id is more accurate than loc
    mutate(    #this step can be changed to AGBD from other iteration 
      agbd_change = ifelse(is.na(predAGBD_iterX) | is.na(lag(predAGBD_iterX)),NA,
                           predAGBD_iterX - lag(predAGBD_iterX)),
      agbd_change_3yr_avg = rollmean(agbd_change, k = 3, fill = NA, align = "center"),  #right align is also more conservation, because untreated is lump into treated; also not too sensitive to the choice 
      pre_agbd_mean = mean(predAGBD_iterX[tname < year[1]], na.rm = TRUE),
      agbd_to_prev= ((predAGBD_iterX - pre_agbd_mean) / pre_agbd_mean) * 100,
      nVal=sum(!is.na(agbd_change))) %>%#[this filter does not affect TS length, just filter out pixels]
    ungroup() %>% 
    mutate(first.treat=year) %>% 
    mutate(first.treat = case_when(
      first.treat == 1990 ~ 0,
      first.treat %in% c(2000:2002) ~ 2002,
      first.treat %in% c(2003:2005) ~ 2005,
      first.treat %in% c(2010:2012) ~ 2012,
      TRUE ~ first.treat  # Optional: handles unmatched cases
    ))->t0
  
  set.seed(1814)
  
  pxAGBD_meandf_sub<-t0 %>% dplyr::select(c( "loc" ,"x","y" ,"year","predYear","predAGBD_iterX",'first.treat','BA_1995',
                                        "manage_stratum","agbd_change",'agbd_to_prev',"agbd_change_3yr_avg",'travelTime_2000',
                                        'slope','dem','MCWD_2013','MCWD_mean_5yrbefore_treatment','popden_2000','aspect','aveMinTemp_2005','aveMaxTemp_2005')) %>% 
    mutate(tname= as.numeric(str_extract(predYear, "\\d+")),  loc2=as.numeric(as.factor(loc)))
  
  #run the ATT and return the results in a datfarme
  example_attgt <- att_gt(yname = "agbd_change_3yr_avg",
                          tname = "tname",
                          idname = "loc2",
                          gname = "first.treat",
                          xformla = ~1,
                          control_group = "nevertreated",
                          allow_unbalanced_panel=TRUE,
                          print_details=TRUE,bstrap=T,cband=T,
                          data = pxAGBD_meandf_sub,pl=TRUE, cores = 8, biters = 5000
  )
  summary(example_attgt)
  # ggdid(example_attgt)
  
  # aggregate 
  agg.simple <- aggte(example_attgt, type = "simple", na.rm = TRUE)
  summary(agg.simple)
  
  #dynamic aggregate
  agg.es <- aggte(example_attgt, type = "dynamic", na.rm = TRUE)
  summary(agg.es)
  # print(ggdid(agg.es))
  
  #group aggregate
  agg.gs <- aggte(example_attgt, type = "group", na.rm = TRUE)
  summary(agg.gs)
  # print(ggdid(agg.gs))
  group_overall<-data.frame(iter=keepIter, groups= paste(agg.gs$egt[1],agg.gs$egt[length(agg.gs$egt)],sep='-' ),
                            overallATT= agg.gs$overall.att, 
                            overallSE=agg.gs$overall.se, pval=agg.gs$crit.val.egt, 
                            overCIlow= agg.gs$overall.att- agg.gs$crit.val.egt*agg.gs$overall.se,
                            overCIhigh= agg.gs$overall.att+ agg.gs$crit.val.egt*agg.gs$overall.se)
  
  groupATTdf<-data.frame(iter=keepIter,groupT=agg.gs$egt, groupATT= agg.gs$att.egt,groupSE=agg.gs$se.egt, 
                         pval=agg.gs$crit.val.egt,  n=table(pxAGBD_meandf_sub$first.treat)[as.character(agg.gs$egt)],
                         groupCIlower=agg.gs$att.egt-agg.gs$crit.val.egt*agg.gs$se.egt,
                         groupCIupper=agg.gs$att.egt+agg.gs$crit.val.egt*agg.gs$se.egt) %>% 
    dplyr::mutate(sig=ifelse((groupCIlower <= 0 & groupCIupper >= 0),  "-", "*"))
  
  outlist<-list(group_overall, groupATTdf)
  return(outlist)
  
}   

pxAGBD_mt_mod<-pxAGBD_mt %>% 
  rename_with(.cols = matches("^iter\\d+"), 
              .fn = ~ paste0("predAGBD_", .))
nboot<-100
allOut<-data.frame()  #the mean ATT seems to equate to if you run with the mean values
overallOut<-data.frame()
for (i in 1:nboot){
  print(i)
  keepI<-paste0('iter',i)
  out<-ATTinter(pxAGBD_mt_mod, keepI)
  overallOut<-rbind(overallOut, out[[1]])
  allOut<-rbind( allOut, out[[2]])
  
}


saveRDS(allOut, "ATT_results_save/AR_NR_group_ATT_results_MT100.RDS")
saveRDS(overallOut, "ATT_results_save/rev_ATT/AR_NR_overall_ATT_results_MT100.RDS")

medianATT<-ATTinter(pxAGBD_mt,'median' )
meanATT<-ATTinter(pxAGBD_mt,'mean' )

saveRDS(medianATT, "ATT_results_save/rev_ATT/AR_NR_group_ATT_results_MT100_median.RDS")
saveRDS(meanATT, "ATT_results_save/rev_ATT/AR_NR_group_ATT_results_MT100_mean.RDS")


#-------4. plot the ATT and the MT100 uncertainty----------------- 

allOut<- readRDS("ATT_results_save/rev_ATT/AR_NR_group_ATT_results_MT100.RDS")
overallOut<-readRDS("ATT_results_save/rev_ATT/AR_NR_overall_ATT_results_MT100.RDS")

allOut2<- readRDS("ATT_results_save/rev_ATT/AR_NR_group_ATT_results_MT100_mean.RDS")


mtATT<-allOut %>% rbind(allOut2[[2]]) %>% 
  group_by(groupT) %>% 
  dplyr::summarise(meanATT=mean(groupATT), meanSE=mean(groupSE),meanCIlow=mean(groupCIlower),
                   meanCIup=mean(groupCIupper )) %>% 
  dplyr::mutate(LT=ifelse(groupT<2012,'Long-term','Short-term'), 
                groupT=2021-groupT) 



library(forcats)
ggplot(mtATT, aes(fct_rev(factor(groupT)), meanATT)) +
  geom_pointrange(
    aes(ymin = meanCIlow, ymax = meanCIup, color=LT),
    position = position_dodge(0.3), width = 0.4
  )+
  geom_point(aes(color = LT), position = position_dodge(0.3)) +
  scale_color_manual(name = "Time frame",,values = c("#238443",'#addd8e')) +
  
  geom_hline(yintercept = 0, color = "#d7301f", linetype = "dashed", size = 0.5)+
  coord_flip()+theme_minimal()+ylab('ATT MT100 mean (Mg/ha/year)')+xlab('Time since treated')+
  labs(title = "Biome1 forest AR")+
  theme_classic(base_size = 14, base_family = "Times")+
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),plot.title = element_text(hjust = 0.5))




