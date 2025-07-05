import pandas as pd
import numpy as np
from pathlib import Path

###########################################################################
# Set up directories
###########################################################################
DATA_DIR = Path("project_folder/data")
RAW = DATA_DIR / "raw"
TEMP = DATA_DIR / "temp"

###########################################################################
# Clean top-up variables
###########################################################################
# Load raw top-up data
df = pd.read_pickle(RAW / "topup.pkl")

# Date variables: Convert to datetime and extract parts
df['trns_dte'] = pd.to_datetime(df['trns_dte'], dayfirst=True, errors='coerce')
df['trns_yr'] = df['trns_dte'].dt.year
df['trns_mth'] = df['trns_dte'].dt.month

df['perd_dte'] = pd.to_datetime(df['perd_id'], dayfirst=True, errors='coerce')
df['perd_yr'] = df['perd_dte'].dt.year
df['perd_mth'] = df['perd_dte'].dt.month

df = df.drop(columns=['perd_id'], errors='ignore')
desired_first = ['perd_dte', 'trns_dte']
existing = [col for col in desired_first if col in df.columns]
remaining = [col for col in df.columns if col not in existing]
df = df[existing + remaining]

# Encode account type
if 'acct_tp_cde' in df.columns:
    df['acct_tp'] = df['acct_tp_cde'].astype('category').cat.codes
    df = df.drop(columns=['acct_tp_cde'])

# Relationship categories
df['relationship_code'] = np.nan
df.loc[(df['topup_by_tag'] == "O") & (df['csh_topup_cde'] == ""), 'relationship_code'] = 1
df.loc[(df['topup_by_tag'] == "O") & (df['csh_topup_cde'] == "E"), 'relationship_code'] = 2
df.loc[(df['topup_by_tag'] == "O") & (df['csh_topup_cde'] == "F"), 'relationship_code'] = 3
df.loc[df['topup_by_tag'] == "S", 'relationship_code'] = 4
df.loc[df['topup_by_tag'] == "T", 'relationship_code'] = 5
df.loc[df['topup_by_tag'] == "V", 'relationship_code'] = 6
df.loc[df['topup_by_tag'] == "W", 'relatrelationship_codeionship'] = 7
df.loc[df['topup_by_tag'] == "X", 'relationship_code'] = 8

relationship_labels = {
    1: "Self", 2: "Employer", 3: "Foreigner", 4: "Spouse",
    5: "Parent", 6: "Grandparent", 7: "Sibling", 8: "Others"
}
df['relationship_label'] = df['relationship_code'].map(relationship_labels)

# Detailed relationship categories (including in-laws)
df['relationship_detailed_code'] = df['relationship_code']
df.loc[(df['topup_by_tag'] == "T") & (df['in_laws_topup_cde'] == "I"), 'relationship_detailed_code'] = 9
df.loc[(df['topup_by_tag'] == "T") & (df['in_laws_topup_cde'] == "G"), 'relationship_detailed_code'] = 10

relationship_detailed_labels = {
    1: "Self", 2: "Employer", 3: "Foreigner", 4: "Spouse",
    5: "Parent", 6: "Grandparent", 7: "Sibling", 8: "Others",
    9: "Parents in law", 10: "Grandparents in law"
}
df['relationship_detailed_label'] = df['relationship_detailed_code'].map(relationship_detailed_labels)


# Top-Up Amount: Handle missing or negative values and create summary totals
for col in ['csh_topup_amt', 'cpf_trnf_amt']:
    df[col] = df[col].fillna(0)

# Reinstatement check
neg_cash_count = df[(df['csh_topup_amt'] < 0) & (df['rnst_tag'] != "R")].shape[0]
neg_cpf_count = df[(df['cpf_trnf_amt'] < 0) & (df['rnst_tag'] != "R")].shape[0]
print("Negative csh_topup_amt not marked as R:", neg_cash_count)
print("Negative cpf_trnf_amt not marked as R:", neg_cpf_count)
df.loc[(df['rnst_tag'] != "R") & (df['cpf_trnf_amt'] < 0), 'rnst_tag'] = "R"

# Combine cash and CPF top-up amounts into a single variable
df['topup_amt'] = df['csh_topup_amt'] + df['cpf_trnf_amt']
df = df[df['topup_amt'] != 0]

# Define top-up type based on the available data
df['cash'] = (df['csh_topup_amt'] > 0)
df['cpf'] = (df['cpf_trnf_amt'] > 0)

# Mode of Transaction: Categorize based on transaction mode codes
mode_code_map = {
    1: ["MSSD052", "MSSD053@", "MTPD008", "MTPD009@"],
    2: ["MSSM118", "MSSM119@", "MTPM006", "MTPM007@"],
    3: ["MSSD064", "MSSD065@", "MTPD015", "MTPD016@"],
    4: ["MTPD077@", "PNWRAPMT", "MTPD083@", "PNWSAPMT"],
    5: ["MSSD116", "MSSD117@", "MTPD029", "MTPD030@"],
    6: ["DCMSE002"],
    7: ["MTPD107@", "MTPD106@"],
    8: ["OATOSA"]
}

df["mode_code"] = np.nan
for code, codes_list in mode_code_map.items():
    df.loc[df["topup_mde_cde"].isin(codes_list), "mode_code"] = code
df.loc[df["mode_code"].isna() & df["mode"].isna(), "mode_code"] = 9

mode_labels = {
    1: "AXS/E-Cashier",
    2: "GIRO",
    3: "OCBC PIB",
    4: "PayNow Straight-Through",
    5: "OMR cash top-up",
    6: "CPF transfer Straight-Through",
    7: "CPF transfer batch or straight-through",
    8: "Self OA to SA transfer",
    9: "Other Manual"
}

df["mode_label"] = df["mode_code"].map(mode_labels)

# Assign a flag for hardcopy transactions
df["hardcopy"] = 0
df.loc[df["mode_detail"].isin([5, 9]), "hardcopy"] = 1

# Reinstatement Handling: Adjust amounts and remove duplicate records
df["topup_amt2"] = df["topup_amt"].abs()
df["r_tag"] = (df["rnst_tag"] == "R").astype(int)

# Handle reinstatements within the same year 
# - drop reinstatement pairs if both original and reversal are found in same year
# - first drop: if there are exactly 2 transactions and one is a reinstatement
# - second drop: catch cases with more than 2 transactions - drop one pair

group_cols = ['tppr_acct_num', 'tppe_acct_num', 'topup_amt2', 'trns_yr']
df['has_r_tag'] = df.groupby(group_cols)['r_tag'].transform('max')
df['dup'] = df.groupby(group_cols)['r_tag'].transform('size')
df = df[~((df['dup'] == 2) & (df['max'] == 1))] # first drop

df['tag'] = df.groupby(group_cols).cumcount() == 0
df['tag'] = df['tag'] & (df['has_r_tag'] == 1)
df['temp'] = df.groupby(group_cols)['tag'].transform('sum')
df = df[~((df['tag']) & (df['temp'] == 2))] # second drop

df.drop(columns=['has_r_tag', 'dup', 'tag', 'temp'], inplace=True)

# Handle reinstatements in the following year
# - drop reinstatement pairs where the original and reversal appear in different years
# - first drop & second drop as above

group_cols = ['tppr_acct_num', 'tppe_acct_num', 'topup_amt2']
df['has_reinstatement'] = df.groupby(group_cols)['r_tag'].transform('max')
df['reinstatement_year'] = df['trns_yr'].where(df['r_tag'] == 1)
df['max_reinstatement_year'] = df.groupby(group_cols)['reinstatement_year'].transform('max')
df['has_reinstatement'] = df['has_reinstatement'].where(
    df['trns_yr'] <= df['max_reinstatement_year'], 0
) # Only keep reinstatements up to and including reinstatement year

df['group_size'] = df.groupby(group_cols)['r_tag'].transform('size')
df = df[~((df['has_reinstatement'] == 1) & (df['group_size'] == 2))] # first drop

df['tag'] = (df.groupby(group_cols + ['r_tag', 'has_reinstatement']).cumcount() == 0).astype(int)
df['tag'] = df['tag'].where(df['has_reinstatement'] == 1, 0)
df['tag_count'] = df.groupby(group_cols)['tag'].transform('sum')
df = df[~((df['tag2'] == 1) & (df['temp2'] == 2))] # second drop

df.drop(columns=[
    'has_reinstatement', 'reinstatement_year', 'max_reinstatement_year',
    'group_size', 'tag', 'tag_count'
], inplace=True)


# Final cleanup
df = df[df['r_tag'] == 0]

# Check Duplicates 
duplicate_rows = df[df.duplicated()]
print(f"{len(duplicate_rows)} duplicate rows found")

df.to_pickle(TEMP / "topup_trns.pkl")
