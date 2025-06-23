from pathlib import Path
from pipeline.import_utils import load_topup_data, extract_member_ids, load_monthly_member_data

# Set up directories
BASE_DIR = Path("project_folder/data")
RAW = BASE_DIR / "raw"
TEMP = BASE_DIR / "temp"
CLEAN = BASE_DIR / "clean"

for d in [RAW, TEMP, CLEAN]:
    d.mkdir(parents=True, exist_ok=True)

# Step 1: Load and combine top-up data
topup_all = load_topup_data(2013, 2020, CLEAN, RAW)

# Step 2: Extract member IDs from top-up records
extract_member_ids(topup_all, TEMP / "topup_mbr_num.csv")

# Step 3: Load and combine monthly member-level data
load_monthly_member_data(2013, 2020, CLEAN, RAW)
