# This script loads the necessary county, LAD, and MSOA GeoJSON files from the UK government API,
# simplifies them using the rmapshaper package, and saves the simplified versions to a specified directory.

# Load required libraries
library(sf)
library(rmapshaper)
library(jsonlite)
library(httr)

# Set tolerance for simplifying GeoJSON
tolerance <- 0.05

# Define parent directory
rootfolder <- strsplit(rstudioapi::getSourceEditorContext()$path, 'src')[[1]][1]
parent_dir <- file.path(rootfolder, "dashboard", "data", "processed_data")
parent_dir

# Function to fetch GeoJSON from REST API
fetch_geojson <- function(api_url, output_path) {
  response <- GET(api_url)
  if (status_code(response) == 200) {
    writeBin(content(response, "raw"), output_path)
    return(output_path)
  } else {
    stop("Failed to fetch GeoJSON: ", status_code(response))
  }
}

# GeoJSON with LAD22CD and LAD22NM simplified
lad22nm_api <- "https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/Local_Authority_Districts_December_2022_UK_BFC_V2/FeatureServer/0/query?outFields=*&where=1%3D1&f=geojson"
geojson_lad22nm_path <- file.path(parent_dir, "Local_Authority_Districts_December_2022_UK_BFC_V2.geojson")
simplified_geojson_lad22nm_path <- file.path(parent_dir, "simplified_geojson_lad22nm.geojson")
fetch_geojson(lad22nm_api, geojson_lad22nm_path)
geo <- st_read(geojson_lad22nm_path)
geo_simplified <- rmapshaper::ms_simplify(geo, keep = tolerance, keep_shapes = TRUE)
st_write(geo_simplified, simplified_geojson_lad22nm_path, driver = "GeoJSON")

# GeoJSON that matches df_loc_auth
county_api = "https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/Counties_and_Unitary_Authorities_December_2024_Boundaries_UK_BSC/FeatureServer/0/query?outFields=*&where=1%3D1&f=geojson"
geojson_county_path <- file.path(parent_dir, "Counties_and_Unitary_Authorities_December_2024_Boundaries_UK_BFC_3348038940373313033.geojson")
simplified_geojson_county_path <- file.path(parent_dir, "simplified_geojson_county.geojson")
fetch_geojson(county_api, geojson_county_path)
geo <- st_read(geojson_county_path)
geo_simplified <- rmapshaper::ms_simplify(geo, keep = tolerance, keep_shapes = TRUE)
st_write(geo_simplified, simplified_geojson_county_path, driver = "GeoJSON")

# GeoJSON with MSOA21CD
msoa_api = "https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/Middle_layer_Super_Output_Areas_December_2021_Boundaries_EW_BFC_V7/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json"
geojson_msoa_path <- file.path(parent_dir, "Middle_layer_Super_Output_Areas_December_2021_Boundaries_EW_BFC_V7_303696399389513507.geojson")
simplified_geojson_msoa_path <- file.path(parent_dir, "simplified_geojson_msoa.geojson")
fetch_geojson(msoa_api, geojson_msoa_path)
geo <- st_read(geojson_msoa_path)
geo_simplified <- rmapshaper::ms_simplify(geo, keep = tolerance, keep_shapes = TRUE)
st_write(geo_simplified, simplified_geojson_msoa_path, driver = "GeoJSON")
