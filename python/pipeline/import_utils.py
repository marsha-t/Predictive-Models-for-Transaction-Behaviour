from pathlib import Path
import pandas as pd

def load_topup_data(start_year, end_year, clean_dir, raw_dir):
    dfs = []
    for y in range(start_year, end_year + 1):
        csv_path = clean_dir / f"topup_{y}.csv"
        if csv_path.exists():
            df = pd.read_csv(csv_path)
            dfs.append(df)
    df_all = pd.concat(dfs, ignore_index=True)
    df_all.to_pickle(raw_dir / "topup.pkl")
    return df_all

def extract_member_ids(df, output_path):
    acct_cols = ["tppr_acct_num", "tppe_acct_num"]
    mbr_list = []

    for col in acct_cols:
        if col in df.columns:
            mbr_list.append(df[[col]].rename(columns={col: "MBR_NUM"}))

    if mbr_list:
        topup_mbr_num = pd.concat(mbr_list, ignore_index=True).drop_duplicates()
        topup_mbr_num.to_csv(output_path, index=False)

def load_monthly_member_data(start_year, end_year, clean_dir, raw_dir):
    for y in range(start_year, end_year + 1):
        monthly_dfs = []
        for m in range(1, 13):
            m_str = f"{m:02d}"
            csv_path = clean_dir / f"topup_mbr_{y}_{m_str}.csv"
            if csv_path.exists():
                df = pd.read_csv(csv_path)
                for col in ["dth_dte", "adrs_ovrs_tag"]:
                    if col in df.columns:
                        df[col] = df[col].astype(str)
                monthly_dfs.append(df)
        if monthly_dfs:
            annual_df = pd.concat(monthly_dfs, ignore_index=True)
            annual_df.to_pickle(raw_dir / f"topup_mbr_{y}.pkl")
