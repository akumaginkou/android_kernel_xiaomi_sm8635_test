import json, urllib.request, sys

def fetch(repo):
    url = f"https://api.github.com/repos/{repo}/releases?per_page=10"
    req = urllib.request.Request(url, headers={'User-Agent': 'curl/8'})
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)

repo = sys.argv[1] if len(sys.argv) > 1 else 'ZyCromerZ/Clang'
print(f"==== {repo} ====")
try:
    data = fetch(repo)
    for r in data[:8]:
        print(f"tag: {r.get('tag_name')} | prerelease: {r.get('prerelease')} | draft: {r.get('draft')}")
        for a in r.get('assets', []):
            print(f"   {a['name']}  {a['size']/1e6:.1f} MB")
except Exception as e:
    print(f"ERROR: {e}")
