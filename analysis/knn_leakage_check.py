# Leakage check for the kNN model in the original 2022 analysis (Python re-implementation).
# Usage: python analysis/knn_leakage_check.py data/raw/spambase.csv
# "leaky" mirrors the original R call knn(train = <full standardised data>, test = <validation rows>).
from pathlib import Path
from check_requirements import check_requirements
check_requirements(Path(__file__).resolve().parent / "requirements.txt")
import sys, numpy as np, pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.neighbors import KNeighborsClassifier
df = pd.read_csv(sys.argv[1]).drop(columns=["word_freq_415"])
X, y = df.drop(columns="spam").values, df["spam"].values
res = {"clean":[], "leaky":[]}
for seed in range(20):
    Xtr, Xva, ytr, yva = train_test_split(X, y, test_size=0.4, random_state=seed)
    sc = StandardScaler().fit(Xtr)
    Xtr_s, Xva_s, Xall_s = sc.transform(Xtr), sc.transform(Xva), sc.transform(X)
    k = 7
    res["clean"].append(KNeighborsClassifier(k).fit(Xtr_s, ytr).score(Xva_s, yva))
    res["leaky"].append(KNeighborsClassifier(k).fit(Xall_s, y).score(Xva_s, yva))  # mirrors knn(train=spam_stand, test=valid_stand)
for k,v in res.items(): print(k, round(np.mean(v),4), "+/-", round(np.std(v),4))
print("rows", len(df), "spam rate", round(y.mean(),3))
