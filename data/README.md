# Data sources

The project combines the following sources described in the thesis:

- European Quality of Government Index (EQI), Quality of Government Institute;
- EDGAR regional greenhouse gas emissions;
- Eurostat regional population, area, GDP, GDP per capita, gross value added,
  and geographical classifications.

The public repository should not contain the original raw workbooks unless
their redistribution terms have been checked. The analysis uses `region_code`
(NUTS identifier) and `year` as the principal merge keys.

The thesis analysis covers 240 NUTS-2 regions in the 27 EU member states from
2010 through 2023, producing 3,360 region-year observations in Table 6.

The descriptive figures in the repository were generated from the final
`three_var_df` panel saved in the thesis R workspace. The workspace itself is
not included in the public repository. To regenerate the figures locally, set
`TFM_RDATA_PATH` to the relevant `.RData` file and run:

```bash
Rscript R/generate-descriptive-figures.R
```
