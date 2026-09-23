import sys,re
exp={'P1-space':'SELECT +["a"] -[]','P0-tap-row-a':'SELECT +["a"] -[]',
'01-down':'','02-space':'SELECT +["a1"] -[]','03-down':'','04-space':'SELECT +["a2"] -[]','05-up':'','06-space':'SELECT +[] -["a1"]',
'07-right':'EXPAND +["a1"] -[]','08-right':'','09-space':'SELECT +["a1x"] -[]','10-right':'','11-space':'SELECT +[] -["a1x"]',
'12-left':'','13-space':'SELECT +["a1"] -[]','14-left':'EXPAND +[] -["a1"]','15-left':'','16-space':'SELECT +[] -["a"]',
'17-left':'EXPAND +[] -["a"]','18-left':'','19-space':'SELECT +["a"] -[]','20-end':'','21-space':'SELECT +["c1"] -[]',
'22-home':'','23-space':'SELECT +[] -["a"]','24-return':'ACTIVATE a','25-shift+down':'SELECT +["b"] -[]',
'26-control+a':'SELECT +["a", "c"] -[]','27-end':'','28-down':'','29-space':'SELECT +[] -["c1"]',
'30-home':'','31-right':'EXPAND +["a"] -[]','32-right':'','33-right':'EXPAND +["a1"] -[]','34-right':'',
'35-click-chevron-a':'EXPAND +[] -["a"]','36-down':'','37-space':'SELECT +[] -["b"]',
'38-home':'','39-hold-down':'','40-space':'SELECT +["b"] -[]','41-char-g':'','42-tab':''}
steps={};cur=None;sent={};rep={}
for line in open(sys.argv[1]):
    f=line.rstrip('\n').split('\t')
    if f[0]=='#': cur=f[2]; steps[cur]=[]; sent[cur]=0; continue
    if cur is None: continue
    if f[1]=='SENTINEL': sent[cur]+=1; continue
    if f[1]=='SENTINEL-REPEAT': rep[cur]=rep.get(cur,0)+1; continue
    d=f[2].split(' set=')[0]
    steps[cur].append(f"{f[1]} {d}")
ok=0;bad=[]
for k,v in steps.items():
    if k.startswith('P0-tab'): continue
    got=' | '.join(v)
    if got==exp.get(k): ok+=1
    else: bad.append((k,exp.get(k),got))
print(f"steps_ok={ok}/{len([k for k in steps if not k.startswith('P0-tab')])} sentinel_per_step_min={min(sent.values())} max={max(sent.values())}")
print("repeat_events_per_step", {k: v for k, v in rep.items()})
for b in bad: print("MISMATCH",b)
