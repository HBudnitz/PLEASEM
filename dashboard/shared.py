from pathlib import Path
from urllib.request import urlopen
import json
import os

import pandas as pd

# define path to the app directory
app_dir = Path(__file__).parent

# Navigate up one level from the dashboard folder, then into data/processed_data
data_folder = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'data', 'processed_data')

# define fleet data
df_county = pd.read_csv(os.path.join(data_folder, "df_county.csv"))
df_lad = pd.read_csv(os.path.join(data_folder, "df_lad.csv"))
df_msoa = pd.read_csv(os.path.join(data_folder, "df_msoa.csv"))

# define shape file for LAD22NM
gdf_lad22nm_path = os.path.join(data_folder, 'simplified_geojson_lad22nm.geojson')
with open(gdf_lad22nm_path) as response:
    gdf_lad22nm = json.load(response)

# define shape file for MSOA21CD
gdf_msoa_path = os.path.join(data_folder, 'simplified_geojson_msoa.geojson')
with open(gdf_msoa_path) as response:
    gdf_msoa = json.load(response)

# define shape file for local authorities
gdf_county_path = os.path.join(data_folder, 'simplified_geojson_county.geojson')
with open(gdf_county_path) as response:
    gdf_county = json.load(response)
