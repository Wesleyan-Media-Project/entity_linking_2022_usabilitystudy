# Entity Linking 2022

Entity linking for 2022 election data.

First we construct a knowledge base of persons of interest in `facebook/train/01_construct_kb.R`. The people for that are sourced from the 2022 WMP persons file, and are restricted to general election candidates and other non-candidate persons of interest (sitting senators, cabinet members, international leaders, etc.). In the same script, we construct one sentence for each person with a basic description. Districts and party are sourced from the 2022 WMP candidates file.

Then we initialize an entity linker with spaCy in `facebook/train/03_untrained_model.py`.

Finally, on the inference data, we apply this entity linker, including some additional modifications to deal with the multiple Harrises etc. problem.

Todo:
- Include cabinet members and other non-candidates who are currently not-dummified in the persons file
- Include gubernatorial candidates
- Include OCR
- Construct proper training data from 2022 candidate ads and train the entity linker
