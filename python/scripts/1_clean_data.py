from pathlib import Path
import pandas as pd
from pipeline.clean_topup import clean_topup_data, collapse_topup_data, remap_mode_detail

DATA_DIR = Path("project_folder/data")
RAW = DATA_DIR / "raw"
TEMP = DATA_DIR / "temp"

# Load and clean
df = pd.read_pickle(RAW / "topup.pkl")
df_cleaned = clean_topup_data(df)
df_cleaned.to_pickle(TEMP / "topup_trns.pkl")

# Collapse to individual-level (original mapping)
df_indiv = collapse_topup_data(df_cleaned)
df_indiv.to_pickle(TEMP / "topup_indiv.pkl")

# Collapse with remapped mode detail
df_remapped = remap_mode_detail(df_cleaned)
df_indiv_v2 = collapse_topup_data(df_remapped)
df_indiv_v2.to_pickle(TEMP / "topup_indivv2.pkl")