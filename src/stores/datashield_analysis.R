# -----------------------------------------------------------
# DataSHIELD analysis: Diabetes, Gender, and BMI
# Equivalent R / dsBaseClient code for the interactive session
# -----------------------------------------------------------

# -----------------------------------------------------------
# 1. Load packages and connect to DataSHIELD servers
# -----------------------------------------------------------
library(DSOpal)
library(dsBaseClient)

builder <- DSI::newDSLoginBuilder()
builder$append(server = "server1", url = "https://opal-demo.obiba.org",
               user = "dsuser1", password = "P@ssw0rd", driver = "OpalDriver")
builder$append(server = "server2", url = "https://opal-demo.obiba.org",
               user = "dsuser2", password = "P@ssw0rd", driver = "OpalDriver")

logindata <- builder$build()
conns <- datashield.login(logins = logindata)

# -----------------------------------------------------------
# 2. List available tables
# -----------------------------------------------------------
datashield.tables(conns)

# -----------------------------------------------------------
# 3. Assign CNSIM tables to symbol 'df'
# -----------------------------------------------------------
datashield.assign.table(conns, symbol = "df",
                        table = list(server1 = "CNSIM.CNSIM1",
                                     server2 = "CNSIM.CNSIM2"))

# -----------------------------------------------------------
# 4. List column names
# -----------------------------------------------------------
ds.colnames(x = "df")

# -----------------------------------------------------------
# 5. Get dimensions
# -----------------------------------------------------------
ds.dim(x = "df")

# -----------------------------------------------------------
# 6. Summary of GENDER
# -----------------------------------------------------------
ds.summary(x = "df$GENDER")

# -----------------------------------------------------------
# 7. Histogram of PM_BMI_CONTINUOUS
# -----------------------------------------------------------
ds.histogram(x = "df$PM_BMI_CONTINUOUS")

# -----------------------------------------------------------
# 8. Crosstabs
# -----------------------------------------------------------
ds.table(rvar = "df$DIS_DIAB", cvar = "df$GENDER")
ds.table(rvar = "df$DIS_DIAB", cvar = "df$PM_BMI_CATEGORICAL")
ds.table(rvar = "df$GENDER", cvar = "df$PM_BMI_CATEGORICAL")

# -----------------------------------------------------------
# 9. Logistic regression: main effects
# -----------------------------------------------------------
ds.glm(formula = "df$DIS_DIAB ~ df$GENDER + df$PM_BMI_CATEGORICAL",
       data = "df",
       family = "binomial")

# -----------------------------------------------------------
# 10. Logout / close session
# -----------------------------------------------------------
datashield.logout(conns)
