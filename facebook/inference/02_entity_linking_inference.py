import csv
from pathlib import Path
import os
import random
import json
import pandas as pd
import spacy #version '3.2'
# trained_entity_linker is output from 02_train_entity_linking.py
nlp = spacy.load("../models/trained_entity_linker/")
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
  
harrises = ['WMPID1144',
            'WMPID3207',
            'WMPID2']

barretts = ['WMPID3995',
            'WMPID17']

# This loop can take anywhere from 6-8 hours.

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
                    # Steve House didn't run in 2022 \o/ yay!
                    # if (ent.kb_id_ == 'H0CO06119') & (ent.label_ == 'ORG'):
                    #     pass
                    
                    # Make sure we don't misclassify Kamala as one of the other Harrises
                    if ent.kb_id_ in harrises:
                        # Check if it is actually Kamala
                        harrises_cand = is_it_kamala(test_doc, harrises, 'WMPID2', boost_size = 0.16)
                        entities_in_ad.append(harrises_cand)
                        entities_in_ad_start.append(ent.start_char)
                        entities_in_ad_end.append(ent.end_char)
                        
                    # Make sure we don't misclassify Amy Coney Barrett as Thomas More Barrett
                    # If the EL detects Thomas More Barrett
                    elif ent.kb_id_ == 'WMPID3995':
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

# Split ids
df['id'] = df['id'].str.split('|')
# "Un-deduplicate", or "Re-hydrate", in WMP lingo
df = df.explode('id')
# Split into ad id and field
df_ids = df['id'].str.split('__', expand = True)
df_ids.columns = ['ad_id', 'field']
df = pd.concat([df, df_ids], 1)
df = df.drop(labels = ['id'], axis = 1)

# Split the data frame into disclaimer/page_name, and other
#df_1 = df[df['field'].isin(['disclaimer', 'page_name'])]
#df_2 = df[df['field'].isin(['disclaimer', 'page_name']) == False]

#def search_cand(sent, ents_start, ents_end, ents, searchterm, searchterm_id):

#  new_ents_start = ents_start.copy()
#  new_ents_end = ents_end.copy()
#  new_ents = ents.copy()
  
#  search_start = np.array([m.start() for m in re.finditer(searchterm, sent, re.IGNORECASE)])
#  search_end = search_start + (len(searchterm)-1)
  
  # Loop over all results returned by the regex search
#  for i in range(len(search_start)):
    # Loop over all entities already detected by the entity linker
    # And check whether any given result returned by the regex search was already found
#    already_found = []
#    for j in range(len(ents_start)):
      # Only do this for the entities that are actually Trump/Biden
#      if ents[j] == searchterm_id:
        # If the character indices of the regex search are within the character indexes of the entity linker, it's already been detected
#        already_found.append((search_start[i] >= ents_start[j]) and (search_end[i] <= ents_end[j]))
    
    # If, for the current regex search result, there are no matches with any of the entity linker's results
    # Then append to the entity linker's results
#    if any(already_found) == False:
#      new_ents_start.append(search_start[i])
#      new_ents_end.append(search_end[i])
#      new_ents.append(searchterm_id)
  
  # Sort the new lists of entities and their indices
#  new_ents = [new_ents[i] for i in np.argsort(new_ents_end)]
#  new_ents_start = sorted(new_ents_start)
#  new_ents_end = sorted(new_ents_end)
  
#  return([new_ents_start, new_ents_end, new_ents])


#for i in tqdm(range(len(df_1))):
#  df_1['text_start'].iloc[i], df_1['text_end'].iloc[i], df_1['text_detected_entities'].iloc[i] = search_cand(df_1['text'].iloc[i], df_1['text_start'].iloc[i], df_1['text_end'].iloc[i], df_1['text_detected_entities'].iloc[i], 'Trump', 'P80001571')
#  df_1['text_start'].iloc[i], df_1['text_end'].iloc[i], df_1['text_detected_entities'].iloc[i] = search_cand(df_1['text'].iloc[i], df_1['text_start'].iloc[i], df_1['text_end'].iloc[i], df_1['text_detected_entities'].iloc[i], 'Biden', 'P80000722')

# Recombine the dataframes
#df = pd.concat([df_1, df_2], axis = 0)

df.to_csv(path_el_results, index=False)
df = df.drop(['text'], axis = 1)
df.to_csv(path_el_results_notext, index=False)
