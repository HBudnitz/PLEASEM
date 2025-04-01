# Note, you need to be in the dashboard path to call any of the below (..BUDNITZ_RA\dashboard, so my command line says mads@MacBook-Pro-7 dashboard %)
# Note also, requirements.txt lists library requorements and runtime.txt notes the python version
# Note also, the data is stored in the cleaned_data folder and the shared.py file is used to import the data (automatically called when running the below commands)

# run app locally via command line command: shiny run --reload --launch-browser app.py
# update app in server (i.e., https://car-club-potential.shinyapps.io/dashboard/) via command line command: rsconnect deploy shiny -n car-club-potential .

import seaborn as sns
import pandas as pd
import plotly.express as px
from plotly.colors import sample_colorscale, sequential
from faicons import icon_svg
from shinywidgets import render_plotly
import numpy as np

# Import data from shared.py
from shared import app_dir, df_county, df_lad, df_msoa, gdf_lad22nm, gdf_msoa, gdf_lad24cd

from shiny import App, reactive
from shiny.express import input, render, ui

ui.tags.head(
    ui.tags.style("""
        body {
            min-height: 2250px;
        }
    """)
)

lad_cd_list = [gdf_lad24cd['features'][i]['properties']['CTYUA24CD'] for i in range(len(gdf_lad24cd['features']))]
level_dic = {'LAD22NM': 'Local Authority District', 'MSOA21CD': 'Middle Layer Super Output Area'}

ui.page_opts(title="PLEASEM: PLace-based Estimated Advantages of Shared Electric Mobility", fillable=True)

with ui.sidebar():

    ui.card_header("Filter Controls", class_="fs-3")

    # Overall total car per local authority filter
    ui.markdown("*Filter for national averages (National Average Tiles)*")
    ui.input_slider("AvgMil", "Avg. Mileage per Car per County", min=int(df_county['pCarAnnMile'].min()), max=int(df_county['pCarAnnMile'].max()), value=[int(df_county['pCarAnnMile'].min()),int(df_county['pCarAnnMile'].max())])
    ui.markdown("<br>*Variable controls for maps*")

    with ui.accordion(id="acc", open=False):

        with ui.accordion_panel("CO2e emission reduction potential panel"):
            ui.markdown("This section contains the filter controls for the CO2e emission reduction potential panel.<br>")

            # Panel 1 input
            ui.input_select(
                "metric1",
                "",
                {'reduceCO2pBEVcc': 'CO2e emission reduction potential per BEV car club vehicle (kg)', 'reduceCO2pHyVc': 'CO2e emission reduction potential per Hybrid car club vehicle (kg)'},
                selected='reduceCO2pBEVcc',
            )

        with ui.accordion_panel("Car ownership change panel"):
            ui.markdown("This section contains the filter controls for the car ownership change panel.<br>")

            # Panel 2 input
            ui.input_select(
                "level2",
                "Geographic Unit",
                level_dic,
                selected='MSOA21CD',
            ),
            ui.input_select(
                "metric2",
                "Car Ownership Change Type",
                {'ChangeEVuptake': 'Increase in EV uptake due to car club (cars)', 'CCredCarOwn': 'Reduction in car ownership due to car club (cars)'},
                selected='ChangeEVuptake',
            )

with ui.layout_column_wrap(fill=False):

    with ui.card():
        ui.card_header("About", class_="text-center fs-3")

        ui.markdown(
            """**PLEASEM** is an open-source tool designed to help you **assess the potential benefits of electric car clubs** wherever you live.
            By leveraging open data on vehicle emissions, mileage, and car ownership, PLEASEM **estimates carbon savings and changes in EV adoption** from replacing private cars with shared electric vehicles. 
            Unlike traditional models based on urban car-sharing schemes, this tool **highlights the place-specific impact** of shared electric mobility, making it particularly useful for rural and suburban areas where data has been scarce. 
            **Users can adjust parameters** to benchmark conservative estimates of emission reductions and policy outcomes, providing data-driven insights for sustainable transport planning.<br><br>
            For any queries, please email: hannah.budnitz@ouce.ox.ac.uk (please use 'PLEASEM' in the subject line).
            """
        )

with ui.layout_column_wrap(fill=False):

    with ui.card():
        ui.card_header("National Average Tiles", class_="text-center fs-5")

with ui.layout_column_wrap(fill=False):

    with ui.value_box(showcase=icon_svg("car")):
        "Avg. Mileage per Car"

        @render.text
        def count():
            weighted_avg = (filtered_df()['pCarAnnMile'] * filtered_df()['TotalCars']).sum() / filtered_df()['TotalCars'].sum()
            return int(weighted_avg)

    with ui.value_box(showcase=icon_svg("car-battery")):
        "Share of Electric and Hybrid vehicles in Car Fleet"

        @render.text
        def ev_prop():
            total_cars = filtered_df()['TotalCars'].sum()
            total_alt = filtered_df()['BEV2024Q2'].sum() + filtered_df()['PHEV2024Q2'].sum() + filtered_df()['Hybrid2024Q2'].sum()
            alt_prop = (total_alt / total_cars)*100
            return f"{round(alt_prop,2)}%"

    with ui.value_box(showcase=icon_svg("leaf")):
        "Avg. emission reduction potential per Car Club BEV"

        @render.text
        def em_red_pot():
            weighted_avg = (filtered_df()['reduceCO2pBEVcc'] * filtered_df()['TotalCars']).sum() / filtered_df()['TotalCars'].sum()
            return f"{int(weighted_avg)}kg CO2e"

with ui.layout_column_wrap(fill=False):

    with ui.card():
        ui.card_header("CO2e emission reduction potential per car club vehicle (by county and vehicle type)", class_="text-center fs-5")

# maps and pie charts
with ui.layout_columns(col_widths=[8, 4]):

    with ui.card(full_screen=True):

        @render_plotly
        def co2_red_map():

            # define variables
            plot_var = input.metric1()
            if plot_var == 'reduceCO2pBEVcc':
                label = 'CO2e reduction potential (kg)<br>per car club BEV'
                fig_trace_lab = "BEV"
            elif plot_var == 'reduceCO2pHyVc':
                label = 'CO2e reduction potential (kg)<br>per car club Hybrid'
                fig_trace_lab = "Hybrid"

            loc_var = 'Local.Authority.Code'
            geojson_loc_var = 'properties.CTYUA24CD'
            hover_vars = ['Local.Authority', 'TotalCars', 'BEV', 'Hybrid', 'pCarAnnMile', plot_var]
            hover_data = {col: True for col in hover_vars}
            data = df_county.copy()
            data = data.dropna(subset=plot_var)
            data['BEV'] = data['BEV'].fillna(0)*100
            data['Hybrid'] = data['Hybrid'].fillna(0)*100

            # plot map
            fig = px.choropleth_mapbox(
                data,
                geojson=gdf_lad24cd,
                locations=loc_var,
                color=plot_var,
                featureidkey=geojson_loc_var,
                color_continuous_scale="Viridis",
                mapbox_style="carto-positron",
                center={"lat": 55.09621, "lon": -4.0286298},
                zoom=4.75,
                hover_data={col: True for col in hover_vars},
                custom_data=hover_vars,
                labels={plot_var: label},
            )

            fig.update_layout(margin={"r":0,"t":0,"l":0,"b":0}, width=750, height=750)

            fig.update_traces(
                marker_line_width=0.1,
                hovertemplate=(
                    "<b>%{customdata[0]}</b><br>" +
                    "Total # of Cars: %{customdata[1]}<br>" +
                    "Share of BEVs in overall car fleet: %{customdata[2]:.3f}%<br>" +
                    "Share of Hybrid vehicles in overall car fleet: %{customdata[3]:.3f}%<br>" +
                    "Avg. Annual Mileage per car: %{customdata[4]:.0f}<br>" +
                    f"CO2 reduction potential<br>per car club {fig_trace_lab} introduced:" + " %{customdata[5]:.0f}kg<extra></extra>"
                )
            )
            return fig

    with ui.card(full_screen=True):

        data_locations = set(df_county['Local.Authority.Code'].unique())
        geojson_locations = set([feature['properties']['CTYUA24CD'] for feature in gdf_lad24cd['features']])
        overlapping_locations = list(data_locations.intersection(geojson_locations))
        data = df_county[df_county['Local.Authority.Code'].isin(overlapping_locations)].dropna(subset=['pCarAnnMile'])

        @render.ui
        def county_select():
            plot_var = input.metric1()
            if plot_var == 'reduceCO2pBEVcc':
                fig_trace_lab = "BEV"
            elif plot_var == 'reduceCO2pHyVc':
                fig_trace_lab = "Hybrid"
            return ui.markdown(
                f"Select a county to see the emission reduction potential per car club {fig_trace_lab} based on avg. annual mileage and private car fleet split:"
            )

        ui.input_select(
            "metric1_lad",
            "",
            sorted(data['Local.Authority'].to_list()),
            selected=sorted(data['Local.Authority'].to_list())[0],
        )

        @render.ui
        def loc_auth_pcar_mil():
            loc_auth = input.metric1_lad()
            return ui.markdown(
                f"**Avg. annual car mileage: {int(df_county[df_county['Local.Authority']==loc_auth]['pCarAnnMile'].iloc[0])} miles** in {loc_auth}"
            )

        @render.ui
        def slider_ui():
            # Get the selected local authority value (reactively)
            selected_loc = input.metric1_lad()
            
            # Filter the DataFrame for the selected local authority.
            base_val = df_county[df_county['Local.Authority'] == selected_loc]['pCarAnnMile'].iloc[0]
            min_val = round(base_val*0.5,0)
            init_val = round(base_val,0)
            max_val = round(base_val*1.5,0)
            step_val = round((max_val - min_val) / 100.0,0)
        
            # Return a slider UI element dynamically based on the filtered data.
            return ui.input_slider(
                "metric1_mil", 
                "Select avg. annual mileage:", 
                int(min_val),
                int(max_val),
                int(init_val),
                step=int(step_val))

        @render.ui
        def loc_auth_em_red_pot():
            loc_auth = input.metric1_lad()
            sel_mil = input.metric1_mil()
            plot_var = input.metric1()
            if plot_var == 'reduceCO2pBEVcc':
                fig_trace_lab = "BEV"
            elif plot_var == 'reduceCO2pHyVc':
                fig_trace_lab = "Hybrid"

            mil = int(df_county[df_county['Local.Authority']==loc_auth]['pCarAnnMile'].iloc[0])
            em_red_pot_multiplier = sel_mil/mil
            em_red_pot = df_county[df_county['Local.Authority']==loc_auth][plot_var].iloc[0]*em_red_pot_multiplier
            return ui.markdown(
                f"**Emission reduction potential** per car club {fig_trace_lab} in {loc_auth}: **{int(em_red_pot)}kg CO2e** at **{sel_mil} miles** and existing **private car fleet split** (see pie chart below)"
                )

        @render_plotly
        def panel_1_pie():
            loc_auth = input.metric1_lad()
            data = df_county[df_county['Local.Authority']==loc_auth][['Petrol', 'Diesel', 'Hybrid', 'BEV', 'PHEV']].iloc[0].to_dict()
            colors = {'Petrol':'peru',
                    'Diesel':'darkkhaki',
                    'Hybrid':'forestgreen',
                    'BEV':'steeltblue',
                    'PHEV':'slateblue'}

            # Create a pie chart with color mapping and text inside the slices
            fig = px.pie(
                values=data.values(),
                names=data.keys(),
                labels={'value': 'Percentage', 'index': 'Fuel Type'},
                hole=0.3,
                color=data.keys(),
                color_discrete_map=colors,
                width=350
            )

            # Update the layout to center the pie chart
            fig.update_layout(
                showlegend=False,  # Remove legend
                autosize=False,  # Disable automatic resizing
                width=300,  # Fixed width
                height=300,  # Fixed height
                margin=dict(l=0, r=0, t=0, b=0),  # Remove extra margins
                uniformtext_minsize=12,  # Set uniform text size
                uniformtext_mode='hide',  # Avoid overlapping text
                paper_bgcolor='rgba(0,0,0,0)',  # Transparent background
                plot_bgcolor='rgba(0,0,0,0)'  # Transparent plot background
            )

            # Update the layout to show percentage and fuel type inside the slices
            fig.update_traces(
                textinfo='percent+label',  # Show percentage and label
                insidetextorientation='horizontal'  # Keep text horizontal inside slices
            )

            # Remove the legend
            fig.update_layout(showlegend=False)

            # Show the pie chart
            return fig

with ui.layout_column_wrap(fill=False):
    with ui.card():
        ui.card_header("Car ownership change per car club BEV (by LAD or MSOA)", class_="text-center fs-5")

with ui.layout_columns(col_widths=[8, 4]):

    with ui.card(full_screen=True):

        @render_plotly
        def ev_uptake_map():

            # define variables
            level_var = input.level2()
            if level_var == 'LAD22NM':
                gdf = gdf_lad22nm
                loc_var = level_var
                geojson_loc_var = 'properties.LAD22NM'
                hover_vars = ['LAD22NM', 'CarOwnRates', 'ChangeEVuptake', 'CCredCarOwn', 'EVRate']
                hovertemplate=(
                    "<b>%{customdata[0]}</b><br>" +
                    "Avg. # of cars (per household): %{customdata[1]:.2f}<br>" +
                    "Share of EVs in car fleet: %{customdata[4]:.2f}%<br>" +
                    "Percentage change of EVs/household<br>per CC vehicle introduced (weighted by MSOA): %{customdata[2]:.3f}%<br>" +
                    "Change in avg. # of cars/household<br>per CC vehicle introduced (weighted by MSOA): %{customdata[3]:.3f}<br>"
                )
                data = df_lad.copy()
            
            else:
                gdf = gdf_msoa
                loc_var = "MSOA21CD"
                geojson_loc_var = 'properties.MSOA21CD'
                hover_vars = ['MSOACD_LADNM', 'CarOwnRates', 'ChangeEVuptake', 'CCredCarOwn', 'EVRate']
                hovertemplate=(
                    "<b>%{customdata[0]}</b><br>" +
                    "Avg. # of cars (per household): %{customdata[1]:.2f}<br>" +
                    "Share of EVs in car fleet: %{customdata[4]:.2f}%<br>" +
                    "Percentage change of EVs/household<br>per CC vehicle introduced: %{customdata[2]:.3f}%<br>" +
                    "Change in avg. # of cars/household<br>per CC vehicle introduced: %{customdata[3]:.3f}<br>"
                )
                data = df_msoa.copy()

            plot_var = input.metric2()
            if plot_var == 'ChangeEVuptake':
                label = 'Percentage change of<br>EVs/household<br>per CC vehicle introduced<br>(Deciles)'
            elif plot_var == 'CCredCarOwn':
                label = 'Change in avg. # of<br>cars/household<br>per CC vehicle introduced<br>(Deciles)'

            hover_data = {col: True for col in hover_vars}
            data.replace([np.inf, -np.inf, 0], np.nan, inplace=True)
            data.dropna(subset=['ChangeEVuptake', 'CCredCarOwn', 'EVRate'], inplace=True)
            data['CCredCarOwn'] = data['CCredCarOwn'] * 100
            data['EVRate'] = data['EVRate'] * 100

            # data filtering options
            outlier_filter = False
            color_var = plot_var

            if outlier_filter == True:
                mean = data[plot_var].mean()
                std_dev = data[plot_var].std()
                threshold = 2
                data = data[(data[plot_var] >= mean - threshold * std_dev) & (data[plot_var] <= mean + threshold * std_dev)]
                color_var = plot_var

            # create deciles for the variable and plot colourmap accordingly
            data['deciles'] = pd.qcut(data[color_var], 10, labels=False) + 1
            data['deciles'] = data['deciles'].astype(int)

            if plot_var == 'CCredCarOwn':
                data['deciles'] = 11 - data['deciles']

            # plot map
            fig = px.choropleth_mapbox(
                data,
                geojson=gdf,
                locations=loc_var,
                color='deciles',
                featureidkey=geojson_loc_var,
                color_continuous_scale="Viridis",
                mapbox_style="carto-positron",
                center={"lat": 53.09621, "lon": -2.0286298},
                zoom=5.25,
                hover_data={col: True for col in hover_vars},
                custom_data=hover_vars,
                labels={'deciles': label},
            )

            fig.update_layout(margin={"r":0,"t":0,"l":0,"b":0}, width=750, height=650)

            fig.update_traces(
                marker_line_width=0.1,
                hovertemplate=hovertemplate
            )
            return fig

    with ui.card(full_screen=True):
        @reactive.Calc
        def selected_level():
            return input.level2()

        @reactive.Calc
        def get_data():
            level_var = selected_level()
            plot_var = input.metric2()
            if level_var == 'LAD22NM':
                data_locations = set(df_lad['LAD22NM'].unique())
                geojson_locations = set([feature['properties']['LAD22NM'] for feature in gdf_lad22nm['features']])
                data_ = df_lad.copy()
            else:
                data_locations = set(df_msoa['MSOA21CD'].unique())
                geojson_locations = set([feature['properties']['MSOA21CD'] for feature in gdf_msoa['features']])
                data_ = df_msoa.copy()

            overlapping_locations = list(data_locations.intersection(geojson_locations))
            data = data_[data_[level_var].isin(overlapping_locations)].dropna(subset=['ChangeEVuptake'])

            data.replace([np.inf, -np.inf, 0], np.nan, inplace=True)
            data = data.dropna(subset=plot_var)
            return data, level_var

        @render.ui
        def location_selector():
            data, level_var = get_data()
            if level_var == 'LAD22NM':
                return_str = f"Select {level_dic[level_var]} to see the respective car ownership change per car club BEV:<br>"
                level_var_ = 'LAD22NM'
            else:
                return_str = f"Select {level_dic[level_var]} to see the respective car ownership change per car club BEV:<br>"
                level_var_ = 'MSOACD_LADNM'
            return ui.div(
                ui.markdown(return_str),
                ui.input_select(
                    "level2_loc",
                    "",
                    sorted(data[level_var_].to_list()),
                    selected=sorted(data[level_var_].to_list())[0],
                )
            )

        @render.ui
        def car_red():
            loc_auth = input.level2_loc()
            data, level_var = get_data()

            if level_var == 'MSOA21CD':
                level_loc_auth = data[data['MSOACD_LADNM'] == loc_auth]['MSOA21CD'].iloc[0]
                try:
                    lad_var = data[data[level_var] == level_loc_auth]['LAD22NM'].iloc[0]
                except:
                    lad_var = 'N/A'
            else:
                level_loc_auth = loc_auth

            filtered_data = data[data[level_var] == level_loc_auth]
            if not filtered_data.empty:
                car_own_rate = filtered_data['CarOwnRates'].iloc[0]
                total_cars = filtered_data['VehsReg'].iloc[0]
                ev_rate = filtered_data['EVRate'].iloc[0]*100
                car_red_pot = filtered_data['ChangeEVuptake'].iloc[0]

                if level_var == 'LAD22NM':
                    return ui.markdown(
                        f"**Selected location:** {loc_auth}<br>"
                        f"**Car Ownership Rate:** {round(car_own_rate, 2)} cars per household.<br>"
                        f"**EV Share in overall car fleet without CC:** {round(ev_rate, 2)}% of {int(total_cars)} total registered vehicles.<br>"
                    ), ui.card_footer(f"Note: Variables are weighted averages across all MSOAs (made up of 2,000-6,000 households) encompassed by {loc_auth}. To illustrate, the ''Change of BEV/household per BEV introduced to CC fleet'' is an average change if a shared BEV was introduced in every MSOA or multiple shared BEVs serving more than one adjacent MSOA."),
                else:
                    return ui.markdown(
                        f"**Selected location:** {loc_auth}<br>"
                        f"**Car Ownership Rate:** {round(car_own_rate, 2)} cars per household.<br>"
                        f"**EV Share in overall car fleet without CC:** {round(ev_rate, 2)}% of {int(total_cars)} total registered vehicles.<br>"
                    )
            else:
                return ui.markdown(f"**No data on car reduction potential per BEV added to car club available for {loc_auth}.**")

        @render.ui
        def cc_vehs_ui():
            # Return a slider UI element dynamically based on the filtered data.
            return ui.input_slider(
                "cc_vehs", 
                "Select number of BEVs to be introduced to car club fleet to see how the proportion of regular EV drivers in your area could increase with each additional shared BEV:", 
                1,
                10, 
                1,
                step=1)

        @render.ui
        def car_red_cc_vehs():
            loc_auth = input.level2_loc()
            data, level_var = get_data()

            if level_var == 'MSOA21CD':
                level_loc_auth = data[data['MSOACD_LADNM'] == loc_auth]['MSOA21CD'].iloc[0]
            else:
                level_loc_auth = loc_auth

            filtered_data = data[data[level_var] == level_loc_auth]
            if not filtered_data.empty:
                car_red_pot = filtered_data['ChangeEVuptake'].iloc[0]
                ev_rate = filtered_data['EVRate'].iloc[0]*100
                new_ev_rate = ev_rate + (input.cc_vehs() * car_red_pot)

                if level_var == 'LAD22NM':
                    return ui.markdown(
                        f"**EV Adoption Rate including frequent car club users:** {round(new_ev_rate, 3)}%."
                    )
                else:
                    return ui.markdown(
                        f"**EV Adoption Rate including frequent car club users:** {round(new_ev_rate, 3)}%."
                    )
            else:
                return ui.markdown(f"**No data on car reduction potential per BEV added to car club available for {loc_auth}.**")

ui.include_css(app_dir / "styles.css")

@reactive.calc
def filtered_df():
    filt_df = df_county.loc[(df_county["pCarAnnMile"] > input.AvgMil()[0]) & (df_county["pCarAnnMile"] < input.AvgMil()[1])]
    return filt_df