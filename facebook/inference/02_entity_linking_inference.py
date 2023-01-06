import csv
from pathlib import Path
import os
import random
import json
import pandas as pd
import spacy #version '3.2'
nlp = spacy.load("../models/untrained_entity_linker_spacy3_v3_500/")
from spacy.kb import KnowledgeBase #vscode pylinter complains about this, but it actually loads fine
from spacy.util import minibatch, compounding
import re
import numpy as np
from tqdm import tqdm

# Input files
path_prepared_ads = "../data/inference_all_fb22_ads.csv.gz"
# Output files
path_el_results = "../data/entity_linking_results_fb22.csv.gz"
path_el_results_notext = "../data/entity_linking_results_fb22_notext.csv.gz"

# Read in prepared ads
df = pd.read_csv(path_prepared_ads)
df = df.replace(np.nan, '', regex=True)
fields = ['text']

def get_sims(sent_emb, ent_id):

    sentence_encoding = sent_emb
    entity_encodings = np.asarray(nlp.get_pipe('entity_linker').kb.get_vector(ent_id))

    sentence_norm = np.linalg.norm(sentence_encoding, axis=0)
    entity_norm = np.linalg.norm(entity_encodings, axis=0)

    sims = np.dot(entity_encodings, sentence_encoding) / (sentence_norm * entity_norm)

    return(sims)

# Give non-candidates like Kamala Harris a boost in comparison to actual cands
# This is necessary because non-cands don't have much training data, so the model 
# almost never picks them
def is_it_kamala(nlpd_doc, possible_cands, likely_cand, boost_size = 0.1):
  
    sent_emb = nlpd_doc.vector
    
    sims = []
    for h in possible_cands:
        
        sim = get_sims(sent_emb, h)
        if h == likely_cand:
            sim += boost_size
            
        sims.append(sim)
        
    picked_cand = np.array(sims).argmax()
    picked_cand_id = possible_cands[picked_cand]
    
    return(picked_cand_id)
  
harrises = ['H8MD01094',
            'H8KY06222',
            'S0SC00289',
            'H0SC06229',
            'H0MI05170',
            'H0LA05112',
            'H0LA03190',
            'WMPID2']

barretts = ['H0GA11036',
            'WMPID17']

for f in fields:
    
    entities_in_field = []
    entities_in_field_start = []
    entities_in_field_end = []
    
    for i in tqdm(range(len(df))):
    
        entities_in_ad = []
        entities_in_ad_start = []
        entities_in_ad_end = []
    
        if pd.isnull(df[f][i])==False:
            test_text = df[f][i]
            test_doc = nlp(test_text)
            for ent in test_doc.ents:
                if ent.kb_id_ != 'NIL':
                    
                    # Make sure we don't misclassify House as Steve House
                    if (ent.kb_id_ == 'H0CO06119') & (ent.label_ == 'ORG'):
                        pass
                    
                    # Make sure we don't misclassify Kamala as one of the other Harrises
                    elif ent.kb_id_ in harrises:
                        # Check if it is actually Kamala
                        harrises_cand = is_it_kamala(test_doc, harrises, 'WMPID2', boost_size = 0.16)
                        entities_in_ad.append(harrises_cand)
                        entities_in_ad_start.append(ent.start_char)
                        entities_in_ad_end.append(ent.end_char)
                        
                    # Make sure we don't misclassify Amy Coney Barrett as Dana Barrett
                    # If the EL detects Dana Barrett
                    elif ent.kb_id_ == 'H0GA11036':
                        # Check if it is actually Amy Coney
                        barretts_cand = is_it_kamala(test_doc, barretts, 'WMPID17', boost_size = 0.17)
                        entities_in_ad.append(barretts_cand)
                        entities_in_ad_start.append(ent.start_char)
                        entities_in_ad_end.append(ent.end_char)
                    
                    # If it is none of these, proceed as normal    
                    else:
                        entities_in_ad.append(ent.kb_id_)
                        entities_in_ad_start.append(ent.start_char)
                        entities_in_ad_end.append(ent.end_char)
    
        entities_in_field.append(entities_in_ad)
        entities_in_field_start.append(entities_in_ad_start)
        entities_in_field_end.append(entities_in_ad_end)


    df[f + '_detected_entities'] = entities_in_field
    df[f + '_start'] = entities_in_field_start
    df[f + '_end'] = entities_in_field_end
    
    print(f, "done!")

df.to_csv(path_el_results, index=False)
df = df.drop(['text'], axis = 1)
df.to_csv(path_el_results_notext, index=False)
