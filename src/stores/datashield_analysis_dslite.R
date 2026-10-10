# -----------------------------------------------------------
# DataSHIELD analysis: Diabetes, Gender, and BMI
# Equivalent R / dsBaseClient code, using an in-memory DSLite server
#
# This script is equivalent to the datashield_analysis.R one,
# but it uses an in-memory DSLite server instead of connecting to
# remote Opal servers. This is usually used for testing and
# development purposes.
# -----------------------------------------------------------

# -----------------------------------------------------------
# 1. Load packages and connect to DataSHIELD servers
# -----------------------------------------------------------
library(DSLite)
library(dsBaseClient)
# For server-side functions (e.g. ds.glm), we need to install
# the dsBase package so that it loads on the "server"
install.packages("dsBase")

# In-memory DataSHIELD server hosting the CNSIM test datasets
data("CNSIM1", package = "DSLite")
data("CNSIM2", package = "DSLite")
dslite.server <- newDSLiteServer(tables = list(CNSIM1 = CNSIM1, CNSIM2 = CNSIM2),
                                 config = defaultDSConfiguration(include = c("dsBase")))
#dslite.server$config()

builder <- DSI::newDSLoginBuilder()
builder$append(server = "server1", url = "dslite.server", driver = "DSLiteDriver")
builder$append(server = "server2", url = "dslite.server", driver = "DSLiteDriver")

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
                        table = list(server1 = "CNSIM1",
                                     server2 = "CNSIM2"))

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
