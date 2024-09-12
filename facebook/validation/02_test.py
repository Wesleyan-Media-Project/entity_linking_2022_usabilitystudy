import csv
from pathlib import Path
import os
import random
import json
import pandas as pd
import spacy
nlp = spacy.load("facebook/models/trained_entity_linker")
from spacy.kb import KnowledgeBase #vscode pylinter complains about this, but it actually loads fine
from spacy.util import minibatch, compounding
import re
import numpy as np

# Input files
path_ner_4k_prepared = "facebook/data/ner_linking_sample_4k_separate.csv"
# Output files
path_ner_4k_el_applied = "facebook/data/detected_entities_sample_separate.csv"


# Read in prepared 4k NER validation dataset
df = pd.read_csv(path_ner_4k_prepared)
df = df.replace(np.nan, '', regex=True)

entities_in_ads = []

for i in range(len(df)):

    entities_in_ad = []

    if pd.isnull(df["text"][i])==False:
        test_text = df["text"][i]
        test_doc = nlp(test_text)
        for ent in test_doc.ents:
            if ent.kb_id_ != 'NIL':
                entities_in_ad.append(ent.kb_id_)

    entities_in_ads.append(entities_in_ad)

    if i % 10 == 0:
        print(i)

df['detected_entities'] = entities_in_ads

df.to_csv(path_ner_4k_el_applied)
