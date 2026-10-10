# -----------------------------------------------------------
# DataSHIELD analysis with dsTidyverseClient
# dplyr-like data manipulation on the server side
# -----------------------------------------------------------

# -----------------------------------------------------------
# 1. Load packages and connect to DataSHIELD servers
# -----------------------------------------------------------
library(DSOpal)
library(dsBaseClient)
library(dsTidyverseClient)

builder <- DSI::newDSLoginBuilder()
builder$append(server = "server1", url = "https://opal-demo.obiba.org",
               user = "dsuser1", password = "P@ssw0rd", driver = "OpalDriver")
builder$append(server = "server2", url = "https://opal-demo.obiba.org",
               user = "dsuser2", password = "P@ssw0rd", driver = "OpalDriver")

logindata <- builder$build()
conns <- datashield.login(logins = logindata)

# -----------------------------------------------------------
# 2. Assign CNSIM tables to symbol 'df'
# -----------------------------------------------------------
datashield.assign.table(conns, symbol = "df",
                        table = list(server1 = "CNSIM.CNSIM1",
                                     server2 = "CNSIM.CNSIM2"))

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
