from pathlib import Path
from urllib.request import urlopen
import json
import os

import pandas as pd

# Navigate up one level from the dashboard folder, then into data/processed_data
data_folder = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'data', 'processed_data')

# define fleet data
df_county = pd.read_csv(data_folder / "df_county.csv")
df_lad = pd.read_csv(data_folder / "df_lad.csv")
df_msoa = pd.read_csv(data_folder / "df_msoa.csv")

# define path to the app directory
app_dir = Path(__file__).parent

# define shape file for LAD22NM
gdf_lad22nm_path = os.path.join(app_dir, 'cleaned_data', 'simplified_geojson_lad22nm.geojson')
with open(gdf_lad22nm_path) as response:
    gdf_lad22nm = json.load(response)

# define shape file for MSOA21CD
gdf_msoa_path = os.path.join(app_dir, 'cleaned_data', 'simplified_geojson_msoa.geojson')
with open(gdf_msoa_path) as response:
    gdf_msoa = json.load(response)

# define shape file for local authorities
gdf_lad24cd_path = os.path.join(app_dir, 'cleaned_data', 'simplified_geojson_loc_auth.geojson')
with open(gdf_lad24cd_path) as response:
    gdf_lad24cd = json.load(response)
