import re
p=r"C:\Program Files (x86)\World of Warcraft\_retail_\WTF\Account\FREYAHEART\SavedVariables\Exploration.lua"
with open(p, encoding="utf-8", errors="replace") as f:
  t=f.read()
for m in re.finditer(r'.{0,40}[Mm]ar.at.{0,120}', t):
  s=m.group(0).replace("\n"," ")
  if "Mar" in s or "mar" in s:
    print(s[:200].encode("ascii","backslashreplace").decode())
    print("---")
