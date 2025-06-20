from pathlib import Path
import pandas as pd

###########################################################################
# Set up directories
###########################################################################
BASE_DIR = Path("project_folder/data")
RAW = BASE_DIR / "raw"
TEMP = BASE_DIR / "temp"
CLEAN = BASE_DIR / "clean"
for d in [RAW, TEMP, CLEAN]:
    d.mkdir(parents=True, exist_ok=True)

###########################################################################
# Import and save top-up data for each year (2013-2020)
###########################################################################
dfs = []
for y in range(2013, 2021):
    csv_path = CLEAN / f"topup_{y}.csv"
    df = pd.read_csv(csv_path)
    dfs.append(df)

topup_all = pd.concat(dfs, ignore_index=True)
topup_all.to_pickle(RAW / "topup.pkl")

###########################################################################
# Extract and combine account numbers from tppr_acct_num and tppe_acct_num columns
###########################################################################
acct_cols = ["tppr_acct_num", "tppe_acct_num"]
mbr_list = []

for col in acct_cols:
    if col in topup_all.columns:
        mbr_list.append(topup_all[[col]].rename(columns={col: "MBR_NUM"}))

# Concatenate and deduplicate
if mbr_list:
    topup_mbr_num = pd.concat(mbr_list, ignore_index=True).drop_duplicates()
    topup_mbr_num.to_csv(TEMP / "topup_mbr_num.csv", index=False)

###########################################################################
# Import member-level data for each year and month (2013-2020)
###########################################################################
# Member data extracted based on unique member numbers found above
for y in range(2013, 2021):
    monthly_dfs = []

    for m in range(1, 13):
        m_str = f"{m:02d}"
        csv_path = CLEAN / f"topup_mbr_{y}_{m_str}.csv"

        if csv_path.exists():
            df = pd.read_csv(csv_path)
            for col in ["dth_dte", "adrs_ovrs_tag"]:
                if col in df.columns:
                    df[col] = df[col].astype(str)
            monthly_dfs.append(df)

    if monthly_dfs:
        annual_df = pd.concat(monthly_dfs, ignore_index=True)
        annual_df.to_pickle(RAW / f"topup_mbr_{y}.pkl")
