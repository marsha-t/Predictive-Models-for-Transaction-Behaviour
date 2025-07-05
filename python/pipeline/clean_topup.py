# pipeline/clean_topup.py
import pandas as pd
import numpy as np

def clean_topup_columns(df):
    df = df.copy()

    # Dates
    df['trns_dte'] = pd.to_datetime(df['trns_dte'], dayfirst=True, errors='coerce')
    df['trns_yr'] = df['trns_dte'].dt.year
    df['trns_mth'] = df['trns_dte'].dt.month

    df['perd_dte'] = pd.to_datetime(df['perd_id'], dayfirst=True, errors='coerce')
    df['perd_yr'] = df['perd_dte'].dt.year
    df['perd_mth'] = df['perd_dte'].dt.month
    df.drop(columns=['perd_id'], errors='ignore', inplace=True)

    # Account type
    if 'acct_tp_cde' in df.columns:
        df['acct_tp'] = df['acct_tp_cde'].astype('category').cat.codes
        df.drop(columns=['acct_tp_cde'], inplace=True)

    # Top-up amounts
    for col in ['csh_topup_amt', 'cpf_trnf_amt']:
        df[col] = df[col].fillna(0)
    df['topup_amt'] = df['csh_topup_amt'] + df['cpf_trnf_amt']
    df = df[df['topup_amt'] != 0]

    # Type flags
    df['cash'] = df['csh_topup_amt'] > 0
    df['cpf'] = df['cpf_trnf_amt'] > 0

    # Reinstatement tag
    df.loc[(df['rnst_tag'] != "R") & (df['cpf_trnf_amt'] < 0), 'rnst_tag'] = "R"
    df['r_tag'] = (df['rnst_tag'] == "R").astype(int)
    df['topup_amt2'] = df['topup_amt'].abs()

    return df


def categorize_mode_and_relationships(df):
    df = df.copy()

    # Relationship codes
    df['relationship_code'] = np.nan
    df.loc[(df['topup_by_tag'] == "O") & (df['csh_topup_cde'] == ""), 'relationship_code'] = 1
    df.loc[(df['topup_by_tag'] == "O") & (df['csh_topup_cde'] == "E"), 'relationship_code'] = 2
    df.loc[(df['topup_by_tag'] == "O") & (df['csh_topup_cde'] == "F"), 'relationship_code'] = 3
    df.loc[df['topup_by_tag'] == "S", 'relationship_code'] = 4
    df.loc[df['topup_by_tag'] == "T", 'relationship_code'] = 5
    df.loc[df['topup_by_tag'] == "V", 'relationship_code'] = 6
    df.loc[df['topup_by_tag'] == "W", 'relationship_code'] = 7
    df.loc[df['topup_by_tag'] == "X", 'relationship_code'] = 8

    df['relationship_detailed_code'] = df['relationship_code']
    df.loc[(df['topup_by_tag'] == "T") & (df['in_laws_topup_cde'] == "I"), 'relationship_detailed_code'] = 9
    df.loc[(df['topup_by_tag'] == "T") & (df['in_laws_topup_cde'] == "G"), 'relationship_detailed_code'] = 10

    # Mode detail → hardcopy flag
    df['mode_detail'] = np.nan
    mode_map = {
        1: ["MSSD052", "MSSD053@", "MTPD008", "MTPD009@"],
        2: ["MSSM118", "MSSM119@", "MTPM006", "MTPM007@"],
        3: ["MSSD064", "MSSD065@", "MTPD015", "MTPD016@"],
        4: ["MTPD077@", "PNWRAPMT", "MTPD083@", "PNWSAPMT"],
        5: ["MSSD116", "MSSD117@", "MTPD029", "MTPD030@"],
        6: ["DCMSE002"],
        7: ["MTPD107@", "MTPD106@"],
        8: ["OATOSA"]
    }
    for code, values in mode_map.items():
        df.loc[df["topup_mde_cde"].isin(values), "mode_detail"] = code
    df["mode_detail"].fillna(9, inplace=True)
    df["hardcopy"] = df["mode_detail"].isin([5, 9]).astype(int)

    return df


def handle_reinstatements(df):
    df = df.copy()

    # Within-year reinstatement
    group_cols = ['tppr_acct_num', 'tppe_acct_num', 'topup_amt2', 'trns_yr']
    df['has_r_tag'] = df.groupby(group_cols)['r_tag'].transform('max')
    df['dup'] = df.groupby(group_cols)['r_tag'].transform('size')
    df = df[~((df['dup'] == 2) & (df['has_r_tag'] == 1))]

    df['tag'] = df.groupby(group_cols).cumcount() == 0
    df['tag'] = df['tag'] & (df['has_r_tag'] == 1)
    df['temp'] = df.groupby(group_cols)['tag'].transform('sum')
    df = df[~((df['tag']) & (df['temp'] == 2))]

    # Cross-year reinstatement
    group_cols = ['tppr_acct_num', 'tppe_acct_num', 'topup_amt2']
    df['has_reinstatement'] = df.groupby(group_cols)['r_tag'].transform('max')
    df['reinstatement_year'] = df['trns_yr'].where(df['r_tag'] == 1)
    df['max_reinstatement_year'] = df.groupby(group_cols)['reinstatement_year'].transform('max')
    df['has_reinstatement'] = df['has_reinstatement'].where(df['trns_yr'] <= df['max_reinstatement_year'], 0)

    df['group_size'] = df.groupby(group_cols)['r_tag'].transform('size')
    df = df[~((df['has_reinstatement'] == 1) & (df['group_size'] == 2))]

    df['tag'] = (df.groupby(group_cols + ['r_tag', 'has_reinstatement']).cumcount() == 0).astype(int)
    df['tag'] = df['tag'].where(df['has_reinstatement'] == 1, 0)
    df['tag_count'] = df.groupby(group_cols)['tag'].transform('sum')
    df = df[~((df['tag'] == 1) & (df['tag_count'] == 2))]

    df = df[df['r_tag'] == 0]
    return df.drop(columns=[
        'has_r_tag', 'dup', 'tag', 'temp',
        'has_reinstatement', 'reinstatement_year', 'max_reinstatement_year',
        'group_size', 'tag_count'
    ])
    

def clean_topup_data(df):
    df = clean_topup_columns(df)
    df = categorize_mode_and_relationships(df)
    df = handle_reinstatements(df)
    return df

def remap_mode_detail(df):
    mode_map = {
        1: ["MSSD052", "MSSD053@", "MTPD008", "MTPD009@"],
        2: ["MSSM118", "MSSM119@", "MTPM006", "MTPM007@"],
        3: ["MSSD064", "MSSD065@", "MTPD015", "MTPD016@"],
        4: ["MTPD077@", "PNWRAPMT", "MTPD083@", "PNWSAPMT"],
        5: ["MSSD116", "MSSD117@", "MTPD029", "MTPD030@"],
        6: ["DCMSE002"],
        7: ["MTPD107@", "MTPD106@"],
        8: ["OATOSA"],
        9: [""]
    }

    df = df.copy()
    df.drop(columns=["mode_detail"], errors="ignore", inplace=True)
    df["mode_detail"] = np.nan

    for code, values in mode_map.items():
        df.loc[df["topup_mde_cde"].isin(values), "mode_detail"] = code

    df["mode_detail"] = df["mode_detail"].fillna(10).astype(int)

    if "hardcopy" in df.columns:
        df.rename(columns={"hardcopy": "hardcopy_v1"}, inplace=True)

    df = df[~df["mode_detail"].between(6, 9)]
    df["hardcopy"] = np.nan
    df.loc[df["mode_detail"].isin([2, 5, 10]), "hardcopy"] = 1
    df.loc[df["mode_detail"].isin([1, 3, 4]), "hardcopy"] = 0

    return df

def collapse_topup_data(df, year_range=(2017, 2020)):
    df = df.copy()
    df = df[df["trns_yr"].between(*year_range)]

    df.sort_values(["tppr_acct_num", "hardcopy"], inplace=True)

    # Overall counts and totals
    topup_all = df.groupby("tppr_acct_num").agg(
        topup_all_num=("topup_amt", "count"),
        topup_all_amt_tot=("topup_amt", "sum")
    )

    # Hard / Soft splits
    topup_hard = df[df["hardcopy"] == 1].groupby("tppr_acct_num")["topup_amt"].agg(["count", "sum"])
    topup_soft = df[df["hardcopy"] == 0].groupby("tppr_acct_num")["topup_amt"].agg(["count", "sum"])

    topup_hard.columns = ["topup_hard_num", "topup_hard_amt_tot"]
    topup_soft.columns = ["topup_soft_num", "topup_soft_amt_tot"]

    out = topup_all.join([topup_hard, topup_soft], how="left").fillna(0)

    for kind in ["all", "hard", "soft"]:
        out[f"topup_{kind}_amt_mean"] = out[f"topup_{kind}_amt_tot"] / out[f"topup_{kind}_num"].replace(0, np.nan)

    # GIRO / Non-GIRO logic
    df["hard_giro"] = (df["mode_detail"] == 2).astype(int)
    df["hard_ngiro"] = df["mode_detail"].isin([5, 10]).astype(int)

    for label, flag_col in [("giro", "hard_giro"), ("ngiro", "hard_ngiro")]:
        sub = df[df[flag_col] == 1].groupby("tppr_acct_num")["topup_amt"].agg(["count", "sum"]).fillna(0)
        sub.columns = [f"topup_{label}_num", f"topup_{label}_amt_tot"]
        sub[f"topup_{label}_amt_mean"] = sub[f"topup_{label}_amt_tot"] / sub[f"topup_{label}_num"].replace(0, np.nan)
        out = out.join(sub, how="left").fillna(0)

    # Year-wise stats
    for year in range(year_range[0], year_range[1] + 1):
        df_y = df[df["trns_yr"] == year]
        base = df_y.groupby("tppr_acct_num")["topup_amt"].agg(
            **{f"topup_all_num_{year}": "count", f"topup_all_amt_tot_{year}": "sum"}
        )
        base[f"topup_all_amt_mean_{year}"] = base[f"topup_all_amt_tot_{year}"] / base[f"topup_all_num_{year}"].replace(0, np.nan)

        for kind, cond in [("hard", df_y["hardcopy"] == 1), ("soft", df_y["hardcopy"] == 0)]:
            sub = df_y[cond].groupby("tppr_acct_num")["topup_amt"].agg(
                **{f"topup_{kind}_num_{year}": "count", f"topup_{kind}_amt_tot_{year}": "sum"}
            )
            sub[f"topup_{kind}_amt_mean_{year}"] = sub[f"topup_{kind}_amt_tot_{year}"] / sub[f"topup_{kind}_num_{year}"].replace(0, np.nan)
            base = base.join(sub, how="left").fillna(0)

        for kind, cond in [("giro", df_y["hard_giro"] == 1), ("ngiro", df_y["hard_ngiro"] == 1)]:
            sub = df_y[cond].groupby("tppr_acct_num")["topup_amt"].agg(
                **{f"topup_{kind}_num_{year}": "count", f"topup_{kind}_amt_tot_{year}": "sum"}
            )
            sub[f"topup_{kind}_amt_mean_{year}"] = sub[f"topup_{kind}_amt_tot_{year}"] / sub[f"topup_{kind}_num_{year}"].replace(0, np.nan)
            base = base.join(sub, how="left").fillna(0)

        out = out.join(base, how="left").fillna(0)

    return out.reset_index()
