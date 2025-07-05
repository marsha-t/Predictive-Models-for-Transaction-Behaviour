import pandas as pd
import numpy as np
from pathlib import Path

###########################################################################
# Set up directories
###########################################################################
DATA_DIR = Path("project_folder/data")
TEMP = DATA_DIR / "temp"

###########################################################################
# Set up functions
###########################################################################
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

    topup_all = df.groupby("tppr_acct_num").agg(
        topup_all_num=("topup_amt", "count"),
        topup_all_amt_tot=("topup_amt", "sum")
    )

    topup_hard = df[df["hardcopy"] == 1].groupby("tppr_acct_num")["topup_amt"].agg(["count", "sum"])
    topup_soft = df[df["hardcopy"] == 0].groupby("tppr_acct_num")["topup_amt"].agg(["count", "sum"])

    topup_hard.columns = ["topup_hard_num", "topup_hard_amt_tot"]
    topup_soft.columns = ["topup_soft_num", "topup_soft_amt_tot"]

    out = topup_all.join([topup_hard, topup_soft], how="left").fillna(0)

    for kind in ["all", "hard", "soft"]:
        out[f"topup_{kind}_amt_mean"] = out[f"topup_{kind}_amt_tot"] / out[f"topup_{kind}_num"].replace(0, np.nan)

    df["hard_giro"] = (df["mode_detail"] == 2).astype(int)
    df["hard_ngiro"] = df["mode_detail"].isin([5, 10]).astype(int)

    giro_stats = {}
    for label, flag in [("giro", "hard_giro"), ("ngiro", "hard_ngiro")]:
        subset = df[df[flag] == 1]
        count = subset.groupby("tppr_acct_num")["topup_amt"].count()
        total = subset.groupby("tppr_acct_num")["topup_amt"].sum()
        giro_stats[f"topup_{label}_num"] = count
        giro_stats[f"topup_{label}_amt_tot"] = total

    giro_df = pd.DataFrame(giro_stats).fillna(0)
    for label in ["giro", "ngiro"]:
        giro_df[f"topup_{label}_amt_mean"] = giro_df[f"topup_{label}_amt_tot"] / giro_df[f"topup_{label}_num"].replace(0, np.nan)

    out = out.join(giro_df, how="left").fillna(0)

    for year in range(year_range[0], year_range[1] + 1):
        df_y = df[df["trns_yr"] == year]
        base = df_y.groupby("tppr_acct_num")["topup_amt"].agg(
            **{f"topup_all_num_{year}": "count", f"topup_all_amt_tot_{year}": "sum"}
        )
        base[f"topup_all_amt_mean_{year}"] = (
            base[f"topup_all_amt_tot_{year}"] / base[f"topup_all_num_{year}"].replace(0, np.nan)
        )

        for kind, cond in [("hard", df_y["hardcopy"] == 1), ("soft", df_y["hardcopy"] == 0)]:
            sub = df_y[cond].groupby("tppr_acct_num")["topup_amt"].agg(
                **{f"topup_{kind}_num_{year}": "count", f"topup_{kind}_amt_tot_{year}": "sum"}
            )
            sub[f"topup_{kind}_amt_mean_{year}"] = (
                sub[f"topup_{kind}_amt_tot_{year}"] / sub[f"topup_{kind}_num_{year}"].replace(0, np.nan)
            )
            base = base.join(sub, how="left").fillna(0)

        for kind, cond in [("giro", df_y["hard_giro"] == 1), ("ngiro", df_y["hard_ngiro"] == 1)]:
            sub = df_y[cond].groupby("tppr_acct_num")["topup_amt"].agg(
                **{f"topup_{kind}_num_{year}": "count", f"topup_{kind}_amt_tot_{year}": "sum"}
            )
            sub[f"topup_{kind}_amt_mean_{year}"] = (
                sub[f"topup_{kind}_amt_tot_{year}"] / sub[f"topup_{kind}_num_{year}"].replace(0, np.nan)
            )
            base = base.join(sub, how="left").fillna(0)

        out = out.join(base, how="left").fillna(0)

    return out.reset_index()

###########################################################################
# Collapse to individual-level data
###########################################################################
# Version 1 (original hardcopy mapping)
df_v1 = pd.read_pickle(TEMP / "topup_trns.pkl")
df_indiv_v1 = collapse_topup_data(df_v1)
df_indiv_v1.to_pickle(TEMP / "topup_indiv.pkl")

# Version 2 (updated hardcopy mapping)
df_v2 = pd.read_pickle(TEMP / "topup_trns.pkl")
df_v2 = remap_mode_detail(df_v2)
df_indiv_v2 = collapse_topup_data(df_v2)
df_indiv_v2.to_pickle(TEMP / "topup_indivv2.pkl")
