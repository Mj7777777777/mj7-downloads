# Empeche l'installateur Mac d'installer les plugins "a cote", la ou il trouve une ancienne copie
# (par exemple dans Telechargements) : tout va toujours dans /Library/Audio/Plug-Ins.
import plistlib, sys
path = sys.argv[1]
with open(path, "rb") as f:
    items = plistlib.load(f)
def fix(entries):
    for e in entries:
        e["BundleIsRelocatable"] = False
        e["BundleOverwriteAction"] = "upgrade"
        fix(e.get("ChildBundles", []))
fix(items)
with open(path, "wb") as f:
    plistlib.dump(items, f)
