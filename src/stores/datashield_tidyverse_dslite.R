# -----------------------------------------------------------
# DataSHIELD analysis with dsTidyverseClient
# dplyr-like data manipulation on the server side, using an
# in-memory DSLite server
#
# This script is equivalent to the datashield_tidyverse.R one,
# but it uses an in-memory DSLite server instead of connecting to
# remote Opal servers. This is usually used for testing and
# development purposes.
# -----------------------------------------------------------

# -----------------------------------------------------------
# 1. Load packages and connect to DataSHIELD servers
# -----------------------------------------------------------
library(DSLite)
library(dsBaseClient)
library(dsTidyverseClient)
# Server-side functions live in the dsBase and dsTidyverse packages,
# they need to be installed so that they load on the "server"
install.packages(c("dsBase", "dsTidyverse"))

# In-memory DataSHIELD server hosting the CNSIM test datasets
data("CNSIM1", package = "DSLite")
data("CNSIM2", package = "DSLite")
dslite.server <- newDSLiteServer(tables = list(CNSIM1 = CNSIM1, CNSIM2 = CNSIM2),
                                 config = defaultDSConfiguration(include = c("dsBase", "dsTidyverse")))

builder <- DSI::newDSLoginBuilder()
builder$append(server = "server1", url = "dslite.server", driver = "DSLiteDriver")
builder$append(server = "server2", url = "dslite.server", driver = "DSLiteDriver")

logindata <- builder$build()
conns <- datashield.login(logins = logindata)

# -----------------------------------------------------------
# 2. Assign CNSIM tables to symbol 'df'
# -----------------------------------------------------------
datashield.assign.table(conns, symbol = "df",
                        table = list(server1 = "CNSIM1",
                                     server2 = "CNSIM2"))

# -----------------------------------------------------------
# 3. Select columns (tidyselect helpers are allowed)
# -----------------------------------------------------------
ds.select(df.name = "df",
          tidy_expr = list(GENDER, DIS_DIAB, starts_with("PM_BMI"), LAB_HDL),
          newobj = "df_sel")
ds.colnames(x = "df_sel")

# -----------------------------------------------------------
# 4. Rename columns
# -----------------------------------------------------------
ds.rename(df.name = "df_sel",
          tidy_expr = list(bmi = PM_BMI_CONTINUOUS, bmi_cat = PM_BMI_CATEGORICAL),
          newobj = "df_sel")
ds.colnames(x = "df_sel")

# -----------------------------------------------------------
# 5. Derive a new variable
# -----------------------------------------------------------
ds.mutate(df.name = "df_sel",
          tidy_expr = list(hdl_mg = LAB_HDL * 38.67),
          newobj = "df_sel")
ds.summary(x = "df_sel$hdl_mg")

# -----------------------------------------------------------
# 6. Filter rows: obese participants only
# -----------------------------------------------------------
ds.filter(df.name = "df_sel",
          tidy_expr = list(bmi >= 30),
          newobj = "df_obese")
ds.dim(x = "df_obese")
ds.table(rvar = "df_obese$DIS_DIAB", cvar = "df_obese$GENDER")

# -----------------------------------------------------------
# 7. Logout / close session
# -----------------------------------------------------------
datashield.logout(conns)
