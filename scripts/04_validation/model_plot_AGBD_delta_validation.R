### This script compares RS-based AGC to field-based AGBD###
### step 1- 3 pair RS-modelled with plot AGBD and calculate GABD change###
### step 3- 6 compares AGBD change and absolute AGBD from two sources

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
#read in the RS-based annual AGBD with uncertainties
predOut<-read.csv('validation/fp_lindi/lindi_xgboost_sqrt_agbd_annual_mt100.csv')

predOut %>% head()

##-----1. for each year's nboot prediction, calculate mean， median and sd------
predSum<-predOut %>% 
  rowwise() %>%
  mutate(pred2021_mean = mean(c_across(starts_with("pred2021_")), na.rm = TRUE),
         pred2021_median = median(c_across(starts_with("pred2021_")), na.rm = TRUE),
         pred2021_sd = sd(c_across(starts_with("pred2021_")), na.rm = TRUE),
         pred2018_mean = mean(c_across(starts_with("pred2018_")), na.rm = TRUE),
         pred2018_median = median(c_across(starts_with("pred2018_")), na.rm = TRUE),
         pred2018_sd = sd(c_across(starts_with("pred2018_")), na.rm = TRUE),
         pred2017_mean = mean(c_across(starts_with("pred2017_")), na.rm = TRUE),
         pred2017_median = median(c_across(starts_with("pred2017_")), na.rm = TRUE),
         pred2017_sd = sd(c_across(starts_with("pred2017_")), na.rm = TRUE),
         pred2012_mean = mean(c_across(starts_with("pred2012_")), na.rm = TRUE),
         pred2012_median = median(c_across(starts_with("pred2012_")), na.rm = TRUE),
         pred2012_sd = sd(c_across(starts_with("pred2012_")), na.rm = TRUE),
         pred2010_mean = mean(c_across(starts_with("pred2010_")), na.rm = TRUE),
         pred2010_median = median(c_across(starts_with("pred2010_")), na.rm = TRUE),
         pred2010_sd = sd(c_across(starts_with("pred2010_")), na.rm = TRUE),
         ) %>%
  ungroup()


##-----2. compare absolute AGBD for all model-plots pairs for measured years based on field data-----

predMean <- predSum %>% 
  dplyr::select(PlotID,ForestCompositionName,ForestEdaphicName,ForestElevationName,ForestStatusName,Altitude,ForestMoistureName,allom,
                year2010, year2012, year2017, year2018, year2021, ends_with('_mean') ) %>%
  pivot_longer(
    cols = c(year2010, year2012, year2017, year2018, year2021, ends_with('_mean') ),
    names_to = c('obs_Year'),
    values_to = "agbd"
  ) %>% 
  mutate(
    obsYear = str_extract(obs_Year, "\\d+"),
    obsType  = str_remove(obs_Year, "\\d+"),
    obsType=ifelse(obsType=='year', 'field','mean_icc')
  ) %>% select(-c(obs_Year)) %>% 
  pivot_wider(
    names_from = obsType,     # column to make new column names
    values_from = agbd     # column to fill those values
  )

#compare the plot vs. mean model estimated mean AGBD [for chave model]
predMean %>% dplyr::filter(allom=='Chave')->tchave# %>% 
#   dplyr::filter( !(ForestCompositionName %notin% c('Mixed forest') | ForestStatusName %in% c('Burned')))


#check for plots with different disturbance history
tchave_sub<-tchave %>% 
  dplyr::filter(ForestStatusName %in% c('Burned')&
                ForestCompositionName %in% c('Mixed forest'))

tchave_sub2<-tchave %>% 
  dplyr::filter(ForestStatusName %in% c('Secondary forest, young (<10yr)')&
                  ForestCompositionName %in% c('Mixed forest'))

tchave_sub3<-tchave[tchave$PlotID %notin% c(tchave_sub$PlotID, tchave_sub2$PlotID),]



#------3. compare AGBD change rates for all model-plot pairs for measured years-----

predRate <-predSum %>% 
  dplyr::select(PlotID,ForestCompositionName,ForestEdaphicName,ForestElevationName,ForestStatusName,Altitude,ForestMoistureName,allom,
                year2010, year2012, year2017, year2018, year2021, ends_with('_mean') ) %>% 
  dplyr::mutate(plot1012=(year2012-year2010)/2, plot1017=(year2017-year2010)/7,
                plot1018=(year2018-year2010)/8,plot1021=(year2021-year2010)/11,
                plot1217=(year2017-year2012)/5,plot1218=(year2018-year2012)/6,
                plot1221=(year2021-year2012)/9,plot1718=(year2018-year2017)/1,
                plot1721=(year2021-year2017)/4,plot1821=(year2021-year2018)/3,
                pred1012=(pred2012_mean-pred2010_mean)/2, pred1017=(pred2017_mean-pred2010_mean)/7,
                pred1018=(pred2018_mean-pred2010_mean)/8, pred1021=(pred2021_mean-pred2010_mean)/11,
                pred1217=(pred2017_mean-pred2012_mean)/5, pred1218=(pred2018_mean-pred2012_mean)/6,
                pred1221=(pred2021_mean-pred2012_mean)/9, pred1718=(pred2018_mean-pred2017_mean)/1,
                pred1721=(pred2021_mean-pred2017_mean)/4, pred1821=(pred2018_mean-pred2021_mean)/3
                ) %>% select(-c(ends_with('_mean'))) %>% 
  pivot_longer(
    cols = c(starts_with('plot', ignore.case = FALSE), starts_with('pred') ),
    names_to = c('rate_Year'),
    values_to = "agbdDelta"
  ) %>% 
  mutate(
    rateYear = str_extract(rate_Year, "\\d+"),
    rateType  = str_remove(rate_Year, "\\d+")
  ) %>% select(-c(rate_Year)) %>% 
  pivot_wider(
    names_from = rateType,     # column to make new column names
    values_from = agbdDelta     # column to fill those values
  )

# write.csv(predRate, 'validation/fp_lindi/model_plot_paired_change_rate.csv')

#------4.combine lindi and udz pairs for savannas & dry forests biome validation-----
# lindi_comp<-read.csv('validation/fp_lindi/model_plot_paired_change_rate.csv')
# udz_comp<-read.csv('validation/am_udzkilo/model_plot_paired_change_rate.csv')

lindi_comp$project<-'lindi'
udz_comp$project<-'udz'

comb_Chave<-lindi_comp[,c('rateYear','plot', 'pred','project')] %>% 
  rbind(udz_comp[,c('rateYear','plot', 'pred','project')] )
  

comb_Chave[complete.cases(comb_Chave[,c('plot','pred')]),]->comb
complete.cases(comb_Chave[,c('plot','pred')]) %>% sum()
cor(comb_Chave$plot, comb_Chave$pred,  use = "complete.obs")  # r=0.7655, n=22


model <- lm(plot ~ pred, data = lindi_comp)

summary_model <- summary(model)
r_squared <- summary_model$r.squared
print(r_squared)


# library(ggpmisc)
ggplot(data = comb_Chave, aes(x = plot, y = pred)) +
  geom_point()+
  stat_cor(label.y = 5)+ 
  stat_regline_equation(label.y = 4)+
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "red") +
  xlim(-5, 5) +
  ylim(-5, 5)

hist(comb_Chave$plot)
hist(comb_Chave$pred)

change_validation_group <- comb_Chave %>% 
  ggscatter(.,x='plot', y='pred',# facet.by = "Stratum2",
            add = "reg.line", conf.int = TRUE, # Add regressin line
            add.params = list(color = "blue", fill = "lightgray"))+ # Customize reg. line
  stat_regline_equation(label.x=10, label.y=28) +
  stat_cor(aes(label=..rr.label..), label.x=4, label.y=23)+
  stat_cor(method = "pearson", label.x = 4, label.y =16)+ylim(-10, 10)+
  labs(y= "Estimated average AGBD change rate (Mg/ha/yr)", x = "Plot average AGBD change rate (Mg/ha/yr)") 
change_validation_group


single_change<-comb_Chave %>% 
  ggscatter(.,x='plot', y='pred', 
            add = "reg.line",conf.int = TRUE,  # Add regressin line
            add.params = list(color = "blue", fill = "lightgray"))+ # Customize reg. line
  stat_regline_equation(label.x=1, label.y=8) +
  stat_cor(aes(label=..rr.label..), label.x=1, label.y=6)+
  stat_cor(method = "pearson", label.x = 1, label.y =4)+ylim(-10, 10)+xlim(-10, 10)+
  labs(y= "Estimated average AGB change rate (Mg/ha/yr)", x = "Plot average AGB change rate (Mg/ha/yr)") 
single_change


# ggsave(paste("Fig/rev_udz_lindi_agbd_chang_rate_chave_validation.png",sep=""), plot=single_change, 
#        width = 1800, height = 1800, units = "px")


#------5.change validation with overlapping historgam & combine w/ scatter --------

pdelta <- comb_Chave %>%
  dplyr::select(plot, pred, project) %>% 
  tidyr::pivot_longer(cols=c('plot','pred'),names_to ='type',values_to = 'agbd') %>% 
  ggplot( aes(x=agbd, fill=type)) +
  geom_histogram( color="#e9ecef", size=0.1, alpha=0.6, binwidth = 0.5) +
  scale_fill_manual(labels=c( "Plot AGB change rate", 'Predicted AGB change rate'),values=c('blue', 'green'))+
  labs(x = NULL)+
  theme_bw() +
  theme(legend.position = c(0.23, 0.8)) +xlim(c(-10,10))

pdelta

dist_scatter_change <- ggarrange(pdelta,single_change,
                                 labels = c("e)", "f)"),
                                 ncol = 1, nrow = 2)
dist_scatter_change

# ggsave(paste("Fig/rev_udz_lindi_dist_scatter_change_chave.png",sep=""), plot= dist_scatter_change, 
#        width = 1500, height = 2700, units = "px")


#------6.validation for absolute agbd------------

tchave_udz<-read.csv('validation/am_udzkilo/model_plot_paired_agbdicc_chave.csv') %>% 
  dplyr::mutate(mean_icc=mean, PlotID=PlotCode, project='udz')
tchave_lindi<-read.csv('validation/fp_lindi/model_plot_paired_agbd_chave.csv') %>% 
  dplyr::mutate(project='lindi')

cols<-c('PlotID','obsYear','field','mean_icc','project')
predAGBD<-tchave_lindi[names(tchave_lindi) %in% cols] %>% 
  rbind(tchave_udz[names(tchave_udz) %in% cols])

overlapHist <- predAGBD %>%
  dplyr::select(field, mean_icc, project, obsYear) %>% 
  tidyr::pivot_longer(cols=1:2,names_to ='type',values_to = 'agbd') %>% 
  ggplot( aes(x=agbd, fill=type)) +
  # facet_wrap(vars(project))+
  geom_histogram( color="#e9ecef", size=0.1, alpha=0.6, bins=50, position = 'identity') +
  scale_fill_manual(values=c("#69b3a2", "#404080"), labels=c("Plot AGBD",'Predicted AGBD')) +
  theme_bw() +theme(legend.position = c(0.7, 0.8))+
  labs(fill="")

overlapHist


agbdScatter <- ggscatter(predAGBD, x='field', y='mean_icc', #facet.by = "Stratum2",
                 add = "reg.line",  # Add regressin line
                 add.params = list(color = "blue", fill = "lightgray"), # Customize reg. line
                 conf.int = TRUE, xlab = "plot agbd", ylab = "pred agbd")+
  coord_cartesian(xlim =c(0,300), ylim = c(0, 300))+
  stat_regline_equation(label.x=3, label.y=280) +
  stat_cor(aes(label=..rr.label..), label.x=3, label.y=260)+
  stat_cor(method = "pearson", label.x = 3, label.y =230)+
  theme_bw()+
  theme( strip.background = element_blank(),strip.text = element_text(
    size = 12, face = "bold"), axis.text=element_text(size=11), 
    plot.title = element_text(size=12, face = "bold"))+
  labs(y= "Estimated AGB mean (Mg/ha)", x = "Plot AGB (Mg/ha)") 
agbdScatter


dist_scatter_agbd <- ggarrange(overlapHist,agbdScatter,
                                 labels = c("e)", "f)"),
                                 ncol = 1, nrow = 2)
dist_scatter_agbd

# ggsave(paste("Fig/rev_udz_lindi_", csvname, "_dist_scatter_agbd.png",sep=""), plot= dist_scatter_agbd, 
#        width = 1500, height = 2700, units = "px")
