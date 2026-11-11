p = "mace2_poll_cron.py"
s = open(p).read()


def sub(old, new):
    global s
    assert s.count(old) == 1, old[:70]
    s = s.replace(old, new)


# constants
sub('''DONE_KEEP = 3 * 24 * 3600
''', '''DONE_KEEP = 3 * 24 * 3600
# A folder whose own mtime is older than the window by more than this can't
# hold a series written inside the window (a series folder appears when the
# series starts and is finished within this long), so it isn't walked.
SERIES_SLACK = 6 * 3600
# Top-level folders whose layout isn't <study>/<session>/..., so their own
# mtime says nothing about new sessions (their children are patient folders):
# always look inside.
ALWAYS_WALK = {"homeless"}
''')

# rules: optional "session" key + homeless phantom rule
sub('''# once_per:  "session" = only the first series (lowest number) of each session
''', '''# once_per:  "session" = only the first series (lowest number) of each session
# session:   optional regex for the 2nd path part (homeless/<patient>/... layout)
''')
sub('''     "pipelines": ["qa"]},
    # Every study except''', '''     "pipelines": ["qa"]},
    # Prisma1/2/3 daily phantoms land in homeless/Brain^PrismaNQC/<session>/PRISMANQA<date>/<series>
    {"name": "phantom-qa-homeless",
     "study": r"^homeless$",
     "session": r"^Brain\\^Prisma\\dQC$",
     "series": r"^ep2d_bold_p2_s2_5min",
     "pipelines": ["qa"]},
    # Every study except''')

# match_rule honours "session"
sub('''    study, series = parts[0], parts[-1]
    for rule in RULES:
        if re.search(rule["study"], study, re.I) and re.search(rule["series"], series, re.I):
            return rule
    return None''', '''    study, session, series = parts[0], parts[1], parts[-1]
    for rule in RULES:
        if not (re.search(rule["study"], study, re.I) and re.search(rule["series"], series, re.I)):
            continue
        if "session" in rule and not re.search(rule["session"], session, re.I):
            continue
        return rule
    return None''')

# prune subtrees while walking
sub('''    for dirpath, _dirnames, filenames in os.walk(session_path):
        matches =''', '''    for dirpath, dirnames, filenames in os.walk(session_path):
        # don't descend into folders that stopped changing long before the window
        dirnames[:] = [d for d in dirnames
                       if newer_than(os.path.join(dirpath, d), last_cutoff - SERIES_SLACK)]
        matches =''')

# study loop honours ALWAYS_WALK
sub('''        if not newer_than(study, last_cutoff - STUDY_SLACK):
            continue
        counts["studies"] += 1''', '''        if study.name not in ALWAYS_WALK and not newer_than(study, last_cutoff - STUDY_SLACK):
            continue
        counts["studies"] += 1''')
import shutil
shutil.copy(p, p + ".bak")
open(p, "w").write(s)
print("patched; backup saved as", p + ".bak")
