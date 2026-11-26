#!/usr/bin/env python3
"""Temporary Pillow composition preview for v4 body sheets and modular atlases."""
import json
import sys
from collections import deque
from pathlib import Path
from PIL import Image
import compose_wanglu_preview as common

ROOT=Path(__file__).resolve().parent
PROJECT=ROOT.parents[1]
BASE_OUT=Path('/tmp/yongchang-asset-qa/v4_composition')
OUT=BASE_OUT/'v3'
ARMOR_MODE='v3'
CELL=128

# Outfit cells follow the ordered 16-item outfit family in the equipment atlas.
OUTFIT_IDS=[
 'ming_lamellar_red','ming_brigandine_blue','ming_robe_ochre','ming_guard_iron',
 'ming_navy_green','ming_qijia_armor','wokou_ragged_brown','wokou_dark_navy',
 'wokou_domaru','wokou_haramaki','pirate_teal','monk_grey','general_purple',
 'oni_red','villager_linen','common_leather_vest']
OUTFIT_CELL={
 'ming_lamellar_red':(0,0),'ming_brigandine_blue':(0,1),'ming_robe_ochre':(0,2),
 'ming_guard_iron':(0,3),'ming_navy_green':(0,4),'ming_qijia_armor':(0,5),
 'wokou_ragged_brown':(0,6),'wokou_dark_navy':(0,7),'wokou_haramaki':(0,7),
}
ARMOR16_CELL={
 'ming_lamellar_red':(0,0),'ming_brigandine_blue':(0,4),'ming_robe_ochre':(0,2),
 'ming_guard_iron':(1,4),'ming_navy_green':(0,1),'ming_qijia_armor':(0,5),
 'wokou_ragged_brown':(0,6),'wokou_dark_navy':(1,2),'wokou_domaru':(1,0),
 'wokou_haramaki':(0,7),'pirate_teal':(1,1),'monk_grey':(1,3),
 'general_purple':(0,3),'oni_red':(1,5),'villager_linen':(1,6),
 'common_leather_vest':(1,7),
}
# v3 rows 2-3 contain isolated headwear; coordinates are row/column in 8x4 atlas.
HEAD_CELL={
 'ming_helmet_red':(2,0),'ming_helmet_iron':(2,1),'ming_hat':(2,3),
 'ming_officer':(2,2),'ming_scout_cap':(3,5),'ming_dragon_band':(2,5),
 'common_headwrap':(2,6),'wokou_headband':(2,7),'wokou_kasa':(3,0),
 'wokou_helmet':(3,1),'monk_hood':(3,2),'oni_mask':(3,3),
 'pirate_bandana':(3,4),'none':None}
BACK_CELL={'ming_cape_red':(1,0),'wokou_cloak_dark':(1,1),
           'ming_quiver':(1,2),'ming_banner':(1,3),'none':None}


def grid_cell(img,cols,rows,row,col):
    w,h=img.size
    return img.crop((round(col*w/cols),round(row*h/rows),round((col+1)*w/cols),round((row+1)*h/rows)))


def white_flood_alpha(img, threshold=240, spread=20):
    """Remove only near-white pixels connected to crop boundary; preserve enclosed white cloth."""
    im=img.convert('RGBA'); w,h=im.size; px=im.load(); seen=set(); q=deque()
    def white(x,y):
        r,g,b,a=px[x,y]
        return a>0 and min(r,g,b)>=threshold and max(r,g,b)-min(r,g,b)<=spread
    for x in range(w):
        if white(x,0): seen.add((x,0)); q.append((x,0))
        if white(x,h-1): seen.add((x,h-1)); q.append((x,h-1))
    for y in range(h):
        if white(0,y): seen.add((0,y)); q.append((0,y))
        if white(w-1,y): seen.add((w-1,y)); q.append((w-1,y))
    while q:
        x,y=q.popleft(); r,g,b,a=px[x,y]; px[x,y]=(r,g,b,0)
        for nx,ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            if 0<=nx<w and 0<=ny<h and (nx,ny) not in seen and white(nx,ny):
                seen.add((nx,ny)); q.append((nx,ny))
    return im


def source_body(faction,row,col):
    name='ground_body_actions_v4.png' if faction=='ming' else 'ground_body_actions_wokou_v1.png'
    raw=grid_cell(Image.open(ROOT/name).convert('RGBA'),8,6,row,col)
    raw=white_flood_alpha(raw) if faction=='ming' else common.hard_alpha(raw)
    return common.fit(common.hard_alpha(raw),82,112)


def cell_by_id(atlas_path, mapping, item_id, cols=8, rows=4):
    rc=mapping.get(item_id,'missing')
    if rc=='missing': return None,f'{item_id}: no explicit cell mapping'
    if rc is None: return None,None
    img=Image.open(atlas_path).convert('RGBA')
    return common.hard_alpha(grid_cell(img,cols,rows,*rc)),None


def equipment_atlas_cell(row,col):
    return common.hard_alpha(grid_cell(Image.open(ROOT/'equipment_modular_v2.png').convert('RGBA'),8,4,row,col))


def weapon_cell(weapon_ids,item_id):
    if item_id not in weapon_ids: return None,f'{item_id}: ID absent in character_templates weapons'
    idx=weapon_ids.index(item_id)
    if idx>=20: return None,f'{item_id}: exceeds 5x4 weapons_modular_v4'
    return common.hard_alpha(grid_cell(Image.open(ROOT/'weapons_modular_v4.png').convert('RGBA'),5,4,idx//5,idx%5)),None


def grip_point(weapon_id,im):
    # Fractional grip points based on visible hilt/shaft ends in the v4 weapon cells.
    fractions={'dao':(.15,.88),'jian':(.14,.88),'wokou_dao':(.15,.88),'qiang':(.12,.88),
      'ji':(.12,.88),'fu':(.12,.88),'yue':(.12,.88),'gou':(.12,.88),'cha':(.12,.88),
      'qijia_dao':(.14,.88),'langxian':(.12,.88),'gong':(.18,.78),'nu':(.15,.88),
      'niaochong':(.12,.88),'longdeng':(.12,.88),'lingqi':(.10,.90),'dun':(.5,.5),'tengpai':(.5,.5),'tangpa':(.5,.5)}
    x,y=fractions.get(weapon_id,(.5,.5)); return round(im.width*x),round(im.height*y)


def fit_overlay(src,maxw,maxh): return common.fit(common.hard_alpha(src),max(1,round(maxw)),max(1,round(maxh)))


def hand_points(body):
    try:
        return common.hand_anchors(body),None
    except ValueError:
        # Some Wokou walk poses merge both forward fists into one skin region.
        regions=[(x,y,n) for x,y,n in common.skin_components(body)
                 if body.height*.39 <= y <= body.height*.78]
        if not regions: raise
        x,y,_=max(regions,key=lambda v:v[2])
        return ((max(0,x-3),y),(min(body.width-1,x+3),y)), 'hands merged; split shared skin cluster by 6px'


def compose(recipe, templates, pose, frame_idx):
    body=source_body(recipe['faction'],pose,frame_idx); left=(CELL-body.width)//2; top=CELL-9-body.height
    (lh,rh),anchor_note=hand_points(body); canvas=Image.new('RGBA',(CELL,CELL),(0,0,0,0)); issues=[]
    if anchor_note: issues.append(anchor_note)
    equipment=ROOT/'equipment_modular_v3.png'
    back,err=cell_by_id(equipment,BACK_CELL,recipe.get('backgear','none')); issues += [err] if err else []
    if ARMOR_MODE=='armor16':
        outfit_path=ROOT/'armor_chestplates_atlas.png'; outfit_map=ARMOR16_CELL; outfit_rows=2
    else:
        outfit_path=equipment; outfit_map=OUTFIT_CELL; outfit_rows=4
    outfit,err=cell_by_id(outfit_path,outfit_map,recipe['outfit'],cols=8,rows=outfit_rows); issues += [err] if err else []
    head,err=cell_by_id(equipment,HEAD_CELL,recipe['headgear']); issues += [err] if err else []
    main,err=weapon_cell([x['id'] for x in templates['weapons']],recipe['weapon']); issues += [err] if err else []
    offid=recipe.get('offhand','none')
    off,err=(None,None) if offid=='none' else weapon_cell([x['id'] for x in templates['weapons']],offid); issues += [err] if err else []
    # layer order: backgear, body, outfit, headwear, offhand, main weapon.
    if back is not None:
        back=fit_overlay(back,body.width*.58,body.height*.58)
        canvas.alpha_composite(back,(left+round(body.width*.01),top+round(body.height*.25)))
    canvas.alpha_composite(body,(left,top))
    if outfit is not None:
        outfit=fit_overlay(outfit,body.width*.54,body.height*.45)
        canvas.alpha_composite(outfit,(left+(body.width-outfit.width)//2,top+round(body.height*.27)))
    if head is not None:
        head=fit_overlay(head,body.width*.58,body.height*.27)
        canvas.alpha_composite(head,(left+(body.width-head.width)//2,top-round(head.height*.08)))
    if off is not None:
        off=fit_overlay(off,body.width*.30,body.height*.32)
        common.place_at_point(canvas,off,(off.width//2,off.height//2),(left+lh[0],top+lh[1]))
    if main is not None:
        limit=(body.width*.70,body.height*.80) if recipe['weapon'] in ('dao','jian','wokou_dao') else (body.width*.96,body.height*.92)
        main=fit_overlay(main,*limit)
        common.place_at_point(canvas,main,grip_point(recipe['weapon'],main),(left+rh[0],top+rh[1]))
    return canvas,issues,(lh,rh)


def main():
    global OUT,ARMOR_MODE
    ARMOR_MODE=sys.argv[1] if len(sys.argv)>1 else 'v3'
    if ARMOR_MODE not in ('v3','armor16'): raise SystemExit('usage: compose_v4_preview.py [v3|armor16]')
    OUT=BASE_OUT/ARMOR_MODE
    templates=json.loads((PROJECT/'game/data/character_templates.json').read_text())
    chars=json.loads((PROJECT/'game/data/characters.json').read_text())['characters']
    enemies=json.loads((PROJECT/'game/data/enemies.json').read_text())['enemies']
    allies=json.loads((PROJECT/'game/data/mercenaries.json').read_text())['mercenaries']
    targets=[(k,chars[k]['character_recipe']) for k in ('wanglu','amei','ashi','achong')]
    targets += [(f'wokou_{k}',enemies[k]['character_recipe']) for k in ('scout','ronin','archer')]
    targets += [(f'ally_{k}',allies[k]['character_recipe']) for k in ('yishi_spear','yishi_archer')]
    OUT.mkdir(parents=True,exist_ok=True); contact=Image.new('RGBA',(CELL*12,CELL*6),(27,33,38,255)); manifest=[]; issues=[]
    for index,(name,recipe) in enumerate(targets):
        idle=[compose(recipe,templates,0,i) for i in range(4)]
        walk=[compose(recipe,templates,1,i) for i in range(8)]
        folder=OUT/name; folder.mkdir(exist_ok=True)
        for key,frames,count in (('idle',idle,4),('walk',walk,8)):
            strip=Image.new('RGBA',(CELL*count,CELL),(0,0,0,0))
            for n,(im,errs,_) in enumerate(frames):
                strip.alpha_composite(im,(CELL*n,0)); issues.extend(f'{name} {key} frame {n}: {e}' for e in errs)
            assert all(strip.crop((i*CELL,0,(i+1)*CELL,CELL)).getchannel('A').getbbox() for i in range(count))
            strip.save(folder/f'{key}.png')
        x=(index%3)*CELL*4; y=(index//3)*CELL*2
        for i in range(4):
            contact.alpha_composite(idle[i][0],(x+i*CELL,y))
            contact.alpha_composite(walk[i*2][0],(x+i*CELL,y+CELL))
        manifest.append({'name':name,'recipe':recipe,'idle_frames':4,'walk_frames':8,
          'idle_size':[512,128],'walk_size':[1024,128],
          'idle_hand_points':[idle[i][2] for i in range(4)]})
    contact.save(OUT/'contact.png')
    contact.resize((contact.width*2,contact.height*2),Image.Resampling.NEAREST).save(OUT/'contact_2x.png')
    report={'source_files':['ground_body_actions_v4.png','ground_body_actions_wokou_v1.png','equipment_modular_v2.png','weapons_modular_v4.png'],
      'targets':manifest,'mapping_issues':sorted(set(issues))}
    (OUT/'manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(f'{len(targets)} targets, {len(targets)*2} strips, {len(targets)*12} frames; mapping issues={len(report["mapping_issues"])}')
    for e in report['mapping_issues']: print('MAPPING ISSUE:',e)

if __name__=='__main__': main()
