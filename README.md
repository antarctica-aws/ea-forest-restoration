# Time-Varying Effects of Forest Restoration Shape Climate Mitigation Outcomes in East Africa


## Contact

Corresponding author: Mengyu Liang ([mliang77\@stanford.edu](mailto:mliang77@stanford.edu))

## Overview

This repository contains the data and code developed for the manuscript on assessing forest restoration stretagies' climate mitigation potential in East Africa.

## Methods Summary

The product generation and analysis of this project were conducted using a combination of programming languages to optimize computation efficiency and improve data visualization:

-   **GEDI data processing, machine learning model development, and aboveground biomass map generation**: Python 3.7
-   **Landsat data processing and predictor variable derivation**: Google Earth Engine
-   **Econometric analysis (staggered difference-in-difference)**: R 3.6
-   **Data visualization**: R 3.6 and QGIS 3.28.14

## Repository Structure

```         
├── data/
│   └── boundaries/          # Study area boundary files (GeoJSON, shapefiles)
├── scripts/
│   ├── 01_data_acquisition/ # GEDI data download and subsetting
│   ├── 02_preprocessing/    # Data preparation, Landsat extraction, and covariate-based matching
│   ├── 03_modeling/         # XGBoost biomass modeling notebooks
│   ├── 04_validation/       # Model validation scripts (R)
│   └── 05_analysis/         # Statistical analysis and figure generation
└── docs/                    # Additional documentation when needed
```

## Workflow Documentation

### 01_data_acquisition

1.  Search for GEDI L4A footprints within the area of interest (AOI)
2.  Subset GEDI orbits over the AOI
3.  Convert GEDI HDF5 files to tabular CSV format
4.  Search for GEDI L2A and L2B products over the AOI
5.  Subset L2A and L2B products over the AOI

### 02_preprocessing

1.  Landsat preprocessing using Google Earth Engine
2.  Extraction of Landsat predictors at GEDI footprint locations
3.  Statistical matching and preparation of modeling inputs

### 03_modeling

1.  Development of tile-level XGBoost biomass models
2.  Model application and Monte Carlo simulation for uncertainty propagation

### 04_validation

1.  Field plot-based biomass calculation
2.  Validation of modeled aboveground biomass against field observations

> **Note:** Field plot biomass data used for validation were obtained from
> [ForestPlots.net](https://www.forestplots.net) as well as through collaborators under a data sharing agreement
> and cannot be publicly redistributed. The validation scripts are provided for
> transparency but cannot be run without obtaining independent access to the
> field data. Researchers may request access directly through ForestPlots.net.
> Validation outputs are shown in the supplementary section of the manuscript.

### 05_analysis

1.  Site-level AGBD extraction and visualization
2.  Average Treatment Effect on the Treated (ATT) analysis for paired sites within biomes
3.  Policy-relevant scenario analysis

## Covariates

| Covariate | Time | Original Resolution | Details and Sources |
|----|----|----|----|
| Biome | Static | 30m | WWF Terrestrial Ecoregions Of The World (Olson et al., 2001) |
| Soil Type | Static | 250m | Africa Soil Profiles Database (AfSP) v1.2 |
| Land Cover | 1992-2020 (yearly) | 300m | ESA CCI |
| Travel Time to Cities | 2000, 2015 | 1km | Nelson, A. (2008) Travel time to major cities: A global map of Accessibility. <DOI:10.2788/95835> |
| Urbanization Intensity Index | 1975-2020 (5-year interval) | 1km | European Commission, Joint Research Centre (JRC) |
| Population Density | 1980-2020 (10-year interval) | 30 arc-seconds | Center for International Earth Science Information Network - CIESIN |
| Burned Area Fraction (BAF) | 1986-2021 (yearly) | 0.5° | Guo & Li, 2024 |
| Maximum Cumulative Water Deficit (MCWD) | 1986-2021 (annual average) | 0.05° | Global CHIRPS |
| Temperature | 1986-2021 (annual max and min) | 30 arc-seconds | WorldClim V1 Bioclimatic variables |
| Precipitation | 1986-2021 (annual max and min) | 30 arc-seconds | WorldClim V1 Bioclimatic variables |
| Elevation | Static | 30m | NASA SRTM Digital Elevation |
| Slope | Static | 30m | NASA SRTM Digital Elevation |
| Aspect | Static | 30m | NASA SRTM Digital Elevation |

## System Requirements

### Operating System
Tested on macOS (13+) and Linux (Ubuntu 20.04+). Windows is not officially supported.

### Python
- Python 3.7 or higher
- See `requirements.txt` for full package list. Key dependencies:
  - `numpy >= 1.19`, `pandas >= 1.1`, `scipy >= 1.5`
  - `scikit-learn >= 0.23`, `xgboost >= 1.2`
  - `geopandas >= 0.8`, `rasterio >= 1.1`, `h5py >= 2.10`

### R
- R 3.6 or higher
- Required R packages:
  - Data wrangling: `tidyr`, `dplyr`, `data.table`, `zoo`, `stringr`, `fastDummies`
  - Spatial: `terra`, `raster`, `sf`, `sp`
  - Statistics / econometrics: `did`, `MatchIt`, `cobalt`, `caret`, `pls`, `geoR`
  - Allometry: `BIOMASS`
  - Visualization: `ggplot2`, `ggpubr`, `viridis`, `hrbrthemes`
  - Parallel computation: `parallel`, `doParallel`

### Google Earth Engine
A registered Google Earth Engine account is required for Landsat predictor variable generation (`02_preprocessing/GEE_script_Landsat_predictor_generations.txt`).

### Non-standard hardware
No specialized hardware is required for most steps. The XGBoost model application with Monte Carlo uncertainty estimation (`03_modeling/GEDI-Landsat_XGBoost_Model_application_100MT_uncertainty.ipynb`) is computationally intensive and benefits from multi-core CPUs (tested on 16–32 cores). A high-memory node (≥ 64 GB RAM) is recommended for full-extent map generation.

## Typical Processing Times

Approximate runtimes on a standard desktop (8-core CPU, 32 GB RAM) unless noted.

| Step | Script | Estimated Time |
|------|--------|----------------|
| GEDI data acquisition & subsetting | `01_data_acquisition/` | 2–4 hours (depends on download speed) |
| Landsat predictor generation | `02_preprocessing/GEE_script_Landsat_predictor_generations.txt` | 1–3 hours (GEE cloud job) |
| GEDI–Landsat covariate extraction & matching | `02_preprocessing/GEDI_landsat_extraction.py`, `FR_covar_extraction_matching.R` | 1–2 hours |
| XGBoost model training (tile-level) | `03_modeling/Localized_GEDI-Landsat_XGBoost_Model.ipynb` | 30–60 minutes |
| XGBoost model application + Monte Carlo (100 iterations) | `03_modeling/GEDI-Landsat_XGBoost_Model_application_100MT_uncertainty.ipynb` | 4–8 hours (HPC recommended) |
| Field plot validation | `04_validation/field_plot_agbd_calculation.R` | < 10 minutes |
| Model AGBD validation | `04_validation/model_plot_AGBD_delta_validation.R` | < 10 minutes |
| ATT estimation (DiD) | `05_analysis/biome_ATT_estimation.R` | 10–30 minutes |
| Climate mitigation scenarios | `05_analysis/biome_climate_mitigation_by_time_horizon.R` | < 10 minutes |
| Site-level AGBD extraction & figures | `05_analysis/AOI_annual_AGBD_extraction_plotting.R` | 10–20 minutes |

## Installation Guide

### Python environment

```bash
# Create and activate a virtual environment (recommended)
python3 -m venv ea_fr_env
source ea_fr_env/bin/activate  # macOS/Linux

# Install dependencies
pip install -r requirements.txt
```

Typical install time on a standard desktop: **5–10 minutes** (depending on network speed).

### R packages

```r
install.packages(c(
  "tidyr", "dplyr", "data.table", "zoo", "stringr", "fastDummies",
  "terra", "raster", "sf", "sp",
  "did", "MatchIt", "cobalt", "caret", "pls", "geoR",
  "BIOMASS",
  "ggplot2", "ggpubr", "viridis", "hrbrthemes",
  "parallel", "doParallel"
))
```

Typical install time on a standard desktop: **10–20 minutes**.

### Google Earth Engine

Register for a free account at [earthengine.google.com](https://earthengine.google.com) and authenticate via the Python API:

```bash
pip install earthengine-api
earthengine authenticate
```

## Demo

Demo data are provided in `data/demo_data/` to allow users to run the analysis scripts without access to the full dataset.

Three large demo files (> 100 MB) are hosted on Zenodo due to GitHub file size limits:
**DOI: [10.5281/zenodo.19361480](https://zenodo.org/records/19361480)**

Download and place these files in `data/demo_data/` before running the demo:
- `aoi_pixel_level_annual_agbd_mt.csv`
- `matchedAOI_pixel_level_annual_agbd_mt.csv`
- `tiletttttt_l24a_all_topo_ls_lhs_nbr_dur8.csv`

| Demo file | Used by | Description |
|-----------|---------|-------------|
| `matchedAOI_pixel_level_annual_agbd_mt.csv` *(Zenodo)* | `05_analysis/biome_ATT_estimation.R` | Subset of matched treatment/control pixels with AGBD time series for ATT estimation |
| `aoi_pixel_level_annual_agbd_mt.csv` *(Zenodo)* | `05_analysis/AOI_annual_AGBD_extraction_plotting.R` | AOI-wide annual AGBD estimates |
| `tiletttttt_l24a_all_topo_ls_lhs_nbr_dur8.csv` *(Zenodo)* | `03_modeling/Localized_GEDI-Landsat_XGBoost_Model.ipynb` | GEDI–Landsat features for one tile |
| `biome1_AR_NT_matchedcells.csv` | `02_preprocessing/FR_covar_extraction_matching.R` | Example matched cell covariates for one biome |
| `ea_wwf_biomes.tif` | `05_analysis/` | Biome raster for the study region |
| `forest_cube.geojson`, `forest_cube2.geojson` | `05_analysis/` | Demo forest restoration site boundaries |

### Running the demo

The recommended entry point for the demo is the ATT estimation script using the matched panel data:

1. Open `scripts/03_modeling/Localized_GEDI-Landsat_XGBoost_Model.ipynb.R`
2. Update the `setwd()` path at the top of the script to point to your local copy of the repository
3. Update input file paths to point to the files in `data/demo_data/`
4. Run the script in R

**Expected output:** model objects for deriving annual AGBD maps.

## Instructions for Use

### Running on your own data

1. **Update working directories**: All scripts contain hardcoded paths (noted at the top of each file). Replace these with absolute paths to your local data directory before running.

2. **Follow the workflow in order**: Scripts are numbered `01` through `05` and must be run sequentially — each step produces outputs consumed by the next.

3. **GEDI data acquisition** (`scripts/01_data_acquisition/`): Define your AOI as a GeoJSON or shapefile (see `data/boundaries/` for examples). Run `L4a_search_AOI.ipynb` to identify relevant GEDI orbits, then `gedi_subsetter_AOI_parallel.py` to download and subset, followed by `L4a_hdf5_to_csv.py` to convert to CSV.

4. **Landsat preprocessing** (`scripts/02_preprocessing/`): Copy the contents of `GEE_script_Landsat_predictor_generations.txt` into the Google Earth Engine code editor and run to generate Landsat predictor composites. Then run `GEDI_landsat_extraction.py` to extract predictors at GEDI footprint locations, followed by `FR_covar_extraction_matching.R` for statistical matching.

5. **Biomass modeling** (`scripts/03_modeling/`): Run `Localized_GEDI-Landsat_XGBoost_Model.ipynb` to train tile-level models, then `GEDI-Landsat_XGBoost_Model_application_100MT_uncertainty.ipynb` to generate biomass maps with Monte Carlo uncertainty (HPC recommended).

6. **Validation** (`scripts/04_validation/`): Requires independent access to field plot data from [ForestPlots.net](https://www.forestplots.net). See note in Workflow Documentation above.

7. **Analysis** (`scripts/05_analysis/`): Run `AOI_annual_AGBD_extraction_plotting.R` for site-level time series, `biome_ATT_estimation.R` for DiD ATT estimation, and `biome_climate_mitigation_by_time_horizon.R` for scenario analysis.

### Reproduction instructions

To reproduce the main quantitative results in the manuscript:

1. Complete steps 1–5 above to generate AGBD map outputs for all tiles
2. Run `scripts/05_analysis/biome_ATT_estimation.R` with the full matched panel dataset to reproduce ATT estimates (Table 1 and Extended Data figures)
3. Run `scripts/05_analysis/biome_climate_mitigation_by_time_horizon.R` to reproduce climate mitigation scenario projections (Figure 4)
4. Run `scripts/05_analysis/AOI_annual_AGBD_extraction_plotting.R` to reproduce site-level AGBD trajectories (Figures 2–3)

Pre-computed ATT results and climate mitigation outputs are available in `data/ATT_group.xlsx` and `data/Climate_mitigation.xlsx` for reference.

## Requirements

See `requirements.txt` for Python dependencies.

## Data Availability

All covariate datasets used in this study are publicly available (see Covariates table above for sources). One field plot dataset used for model validation is from [ForestPlots.net](https://www.forestplots.net) and subject to the data sharing terms of that network. The three other field plot datasets described in the methods section subject to data sharing agreement with data collection organizations/ parties.

Restoration site boundaries are available through [Verra's project registry](https://registry.verra.org). All other project-level data (site characteristics, intervention records, and matched panel data) are subject to data sharing agreements with the respective project organizations.

## Note

The code has not been amended for wider use and still contains hardcoded working directories. You will need to modify file paths for the scripts to run on your system.

## License

See LICENSE file for details.
