# Rosafe

**Track:** Climate

**Team:** AYA

## The problem

When it rains in Dallas-Fort Worth, every driver gets the same warning to drive carefully. But rain doesn't hit every road the same way. Some roads get a lot more dangerous in the rain and some barely change, and nothing tells you which ones. We put this in the Climate track because the problem is weather, and weather is the part of climate people actually deal with every day.

## What we built

A model that gives 855 DFW roads (state highways, toll roads and the busiest city streets) a danger score every day: how many crashes to expect compared with that road's normal day, so 1.0 is normal and 1.4 means 40% more crashes than usual. An iPhone app runs in the background, and on days with rain or ice it alerts you when you're driving toward a road that's riskier than normal that day. It doesn't navigate. It just tells you, and you decide if you want to slow down, leave earlier or take another road. For now it replays past days, since a live version needs a forecast.

## What we added

This was our own idea, not one of the suggested projects. We wanted to know if the same rain is worse on some roads and some days than others, like after a dry spell, after a heat wave or on a certain road surface. We wrote down three claims from earlier research before we looked at any results. Then we joined TxDOT crash records, NOAA weather and how each road is built, and tested everything on a year the model never saw.

## How it works

We used 679,621 TxDOT crashes from the 12 DFW counties (2020 to 2024) and NOAA's daily weather at DFW Airport. Each road's score is its crashes divided by its normal for that weekday. Linear models on four road-surface groups test what each kind of weather input adds, and gradient boosting scores every road one by one. We made every choice on 2023, then retrained on 2021 to 2023 and tested once on 2024. We left 2020 out because COVID changed traffic. A result only counts as real if it holds in at least 950 of 1,000 random redraws of whole weeks.

## Results

On 2024, the year the model never saw:

- Today's weather beat the simple guess "every day is normal" by 4.3%, and that's real (2023: 3.8%). When we shuffled the weather across days the gain went away, so it really comes from the weather. In 2024 the weather beyond just whether it rained also added a real 3.5% over a rain-only rule.
  - Road by road, the model beat the simple guess on the 38 busiest roads by 1%, which is real, and on 8 of the 10 busiest.
  - The roads the alert flagged ran 31% above their normal on those days. Warning every road whenever it rains only gets 8.2% (2023: 43.1% and 16.8%). The alert is right more often than that, but it catches fewer of the bad days, so the alert test we set before seeing results didn't pass.
  - One of our three claims held: on the six highways with both surfaces, asphalt over concrete gets worse than plain concrete on a first rain. The first-rain and heat claims didn't hold.
  - Some things didn't help. Weather history and road surface didn't add anything real day to day, road build fell just short (948 of 1,000), and the model ranks the busy roads in rain about as well as their own past record, not better.

**Where it fails.** Jan 17, 2024 was a dry day two days after a hard freeze with ice on the roads. The model expected the busy roads to run below normal, but they ran 22% above. It was probably leftover ice, which daily weather data can't show, so the app stayed quiet on a bad day.

## What we'd do next

The scores are per day and come from one rain gauge for all 12 counties, so next is hourly rain and more gauges across DFW. Then a live mode that scores today from the forecast. It needs a good forecast, because with only yesterday's weather the edge almost goes away.

## Sources

[TxDOT crash records](https://services.arcgis.com/KTcxiTD9dsQw4r7Z/arcgis/rest/services/TXDOT_Statewide_Bicyclist_Involved_Crashes/FeatureServer/0), [NOAA daily weather for DFW Airport](https://www.ncei.noaa.gov/data/global-historical-climatology-network-daily/access/USW00003927.csv), the [City of Lewisville's crash layer](https://services2.arcgis.com/kXGqZY4GIOcEYxoF/arcgis/rest/services/Traffic_Crashes_AASHTO_Ware_View/FeatureServer/0) for surface codes, [UC Berkeley on rain after a dry spell](https://newsarchive.berkeley.edu/news/media/releases/2003/10/31_rain.shtml) and the [Texas A&M Transportation Institute on asphalt](https://pavements.tti.tamu.edu/2013/08/06/get-a-grip-new-fine-pfc-offsets-bleeding-flushing-on-roadways/). We checked our data against [National Weather Service records](https://data.rcc-acis.org) and OpenStreetMap. Claude and Claude Code (Anthropic) wrote most of the code and drafts and ran those checks.
