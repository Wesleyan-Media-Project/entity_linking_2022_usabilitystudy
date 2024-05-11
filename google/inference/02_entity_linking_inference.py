import csv
from pathlib import Path
import os
import random
import json
import pandas as pd
import spacy # Use version '3.2.4'
# trained_entity_linker is output from 02_train_entity_linking.py
nlp = spacy.load("../../facebook/models/trained_entity_linker/")
from spacy.kb import KnowledgeBase #vscode pylinter complains about this, but it actually loads fine
from spacy.util import minibatch, compounding
import re
import numpy as np
from tqdm import tqdm

# Input files
path_prepared_ads = "../data/inference_all_google22_ads.csv.gz"
# Output files
path_el_results = "../data/entity_linking_results_google_2022.csv.gz"
path_el_results_notext = "../data/entity_linking_results_google_2022_notext_new.csv.gz"

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


## Prepare data for additional dictionary search for Trump and Biden only on advertiser name field
# Split ids
df['id'] = df['id'].str.split('|')
# "Un-deduplicate", or "Re-hydrate", in WMP lingo
df = df.explode('id')
# Split into ad id and field
df_ids = df['id'].str.split('__', expand = True)
df_ids.columns = ['ad_id', 'field']
df = pd.concat([df, df_ids], axis = 1)
df = df.drop(labels = ['id'], axis = 1)

# Split the data frame into advertiser_name, and other
df_1 = df[df['field'].isin(['advertiser_name'])]
df_2 = df[df['field'].isin(['advertiser_name']) == False]


# Make a copy of df_1
df1 = df_1.copy()
df1.reset_index(drop=True, inplace=True)

# This function does a simple dictionary search on advertiser name field. 
# It only does this search for Biden and Trump. 
# If this dictionary search finds any entity that was not detected by the model, it adds the corresponding WMPID to the detected entities list.

def update_detected_entities(df):
    # Mapping of names to their corresponding ids
    name_to_id = {'biden': 'WMPID1289', 'trump': 'WMPID1290'}

    # Iterate over each row in the DataFrame with tqdm
    for index, row in tqdm(df.iterrows(), total=len(df), desc="Processing rows"):
        # Split the text_detected_entities column to a list
        detected_entities = row['text_detected_entities']
        
        # Initialize lists to store start and end indices
        start_indices = row['text_start']
        end_indices = row['text_end']

        # Convert the text to lowercase
        text = row['text'].lower()

        # Iterate over each name to be detected
        for name in name_to_id.keys():
            # Find all occurrences of the name in the text
            name_occurrences = [i for i in range(len(text)) if text.startswith(name, i)]

            # Check each occurrence of the name
            for start_index in name_occurrences:
                # Check if the name is already detected by the entity linking model
                already_detected = False
                for start, end in zip(start_indices, end_indices):
                    if start <= start_index < end:
                        already_detected = True
                        break

                # If the name is not already detected, add its ID
                if not already_detected:
                    end_index = start_index + len(name)
                    detected_entities.append(name_to_id[name])
                    start_indices.append(start_index)
                    end_indices.append(end_index)

        # Update the DataFrame with the modified lists
        df.at[index, 'text_detected_entities'] = detected_entities
        df.at[index, 'text_start'] = start_indices
        df.at[index, 'text_end'] = end_indices

    return df


df2 = update_detected_entities(df1)

# Recombine the dataframes
df = pd.concat([df2, df_2], axis = 0)

# Save results
df.to_csv(path_el_results, index=False)
df = df.drop(['text'], axis = 1)
df.to_csv(path_el_results_notext, index=False)
