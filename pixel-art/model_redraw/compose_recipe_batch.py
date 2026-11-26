#!/usr/bin/env python3
"""Temporary recipe-driven Pillow art composition QA; no pixels are painted."""
import json
import sys
from pathlib import Path
from PIL import Image
import compose_wanglu_preview as common

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[1]
OUT = Path('/tmp/yongchang-asset-qa/recipe_batch')
CELL = 128


def load_json(path):
    return json.loads(path.read_text())


def fit_clip(src, max_w, max_h):
    return common.fit(src, max(1, int(max_w)), max(1, int(max_h)))


def attach(canvas, image, source_point, target_point):
    common.place_at_point(canvas, image, source_point, target_point)


def atlas_id_cell(path, cols, rows, entries, item_id, offset=0):
    ids = [x['id'] for x in entries]
    if item_id not in ids:
        return None, f'{item_id}: ID absent from template list'
    index = ids.index(item_id) + offset
    if index >= cols * rows:
        return None, f'{item_id}: index {index} exceeds {cols}x{rows} atlas'
    return common.grid_cell(path, cols, rows, index // cols, index % cols), None


# Explicit visual ID maps; atlas ordering differs from CharacterForge array order.
OUTFIT_CELL = {
 'ming_lamellar_red':(0,0),'ming_brigandine_blue':(0,4),'ming_robe_ochre':(0,2),
 'ming_guard_iron':(1,4),'ming_navy_green':(0,1),'ming_qijia_armor':(1,0),
 'wokou_ragged_brown':(0,6),'wokou_dark_navy':(0,7),'wokou_domaru':(1,3),
 'wokou_haramaki':(1,2),'pirate_teal':(1,1),'monk_grey':(1,3),
 'general_purple':(0,0),'oni_red':(1,5),'villager_linen':(1,3),'common_leather_vest':(0,5),
}
HEAD_CELL = {
 'ming_helmet_red':(0,0),'ming_helmet_iron':(0,1),'ming_hat':(0,4),
 'ming_officer':None,'ming_scout_cap':(0,2),'ming_dragon_band':(1,0),
 'common_headwrap':(1,2),'wokou_headband':(0,7),'wokou_kasa':(1,1),
 'wokou_helmet':(0,5),'monk_hood':(0,3),'oni_mask':None,'pirate_bandana':(1,0),
 'none':None,
}
BACK_CELL = {'ming_cape_red':(2,0),'wokou_cloak_dark':(2,1),
             'ming_banner':(2,2),'ming_quiver':(2,4)}


def mapped_cell(path, cols, rows, mapping, item_id):
    if item_id in (None,'none'):
        return None,None
    if item_id not in mapping:
        return None,f'{item_id}: no explicit model-art mapping'
    rc=mapping[item_id]
    if rc is None:
        return None,f'{item_id}: no matching isolated model-art cell'
    return common.grid_cell(path,cols,rows,*rc),None


def weapon_cell(path, weapons, item_id):
    return atlas_id_cell(path, 5, 4, weapons, item_id)


def weapon_grip(item_id, image):
    # Approximate grip pixels by visible source orientation in weapons_implements_v2.
    points = {
        'dao': (.84, .12), 'jian': (.86, .10), 'qiang': (.10, .90), 'ji': (.10, .90),
        'fu': (.12, .88), 'yue': (.12, .88), 'gou': (.12, .88), 'cha': (.12, .88),
        'qijia_dao': (.12, .88), 'langxian': (.12, .88), 'tangpa': (.50, .50),
        'gong': (.13, .88), 'nu': (.12, .88), 'niaochong': (.12, .88),
        'longdeng': (.12, .88), 'lingqi': (.08, .90), 'wokou_dao': (.86, .10),
        'dun': (.50, .50), 'tengpai': (.50, .50),
    }
    fx, fy = points.get(item_id, (.5, .5))
    return round(image.width*fx), round(image.height*fy)


def compose(recipe, templates, pose, frame_index):
    body = common.fit(common.hard_alpha(common.body_cell(pose, frame_index)), 82, 112)
    left_hand, right_hand = common.hand_anchors(body)
    left = (CELL-body.width)//2
    top = CELL-9-body.height
    canvas = Image.new('RGBA',(CELL,CELL),(0,0,0,0))

    # Resolve all source cells from canonical CharacterForge array order.
    back, back_err = mapped_cell(ROOT/'headgear_backgear_atlas.png',8,4,BACK_CELL,recipe['backgear'])
    outfit, outfit_err = mapped_cell(ROOT/'armor_chestplates_atlas.png',8,2,OUTFIT_CELL,recipe['outfit'])
    head, head_err = mapped_cell(ROOT/'headwear_atlas_v2.png',8,2,HEAD_CELL,recipe['headgear'])
    weapon, weapon_err = weapon_cell(ROOT/'weapons_implements_v2.png',templates['weapons'],recipe['weapon'])
    off_id=recipe.get('offhand','none')
    shield, shield_err = (None,None) if off_id=='none' else weapon_cell(ROOT/'weapons_implements_v2.png',templates['weapons'],off_id)
    errors=[x for x in (back_err,outfit_err,head_err,weapon_err,shield_err) if x]

    # Canonical layer order: rear gear, body, outfit, headgear, offhand, main weapon.
    if back is not None and recipe['backgear']!='none':
        back=fit_clip(back,body.width*.40,body.height*.42)
        canvas.alpha_composite(back,(left+round(body.width*.02),top+round(body.height*.28)))
    canvas.alpha_composite(body,(left,top))
    if outfit is not None:
        outfit=fit_clip(outfit,body.width*.56,body.height*.46)
        canvas.alpha_composite(outfit,(left+(body.width-outfit.width)//2,top+round(body.height*.31)))
    if head is not None and recipe['headgear']!='none':
        head=fit_clip(head,body.width*.52,body.height*.24)
        canvas.alpha_composite(head,(left+(body.width-head.width)//2,top-round(head.height*.10)))
    if shield is not None:
        shield=common.hard_alpha(shield)
        shield=fit_clip(shield,body.width*.40,body.height*.42)
        attach(canvas,shield,(shield.width//2,shield.height//2),(left+left_hand[0],top+left_hand[1]))
    if weapon is not None:
        weapon=common.hard_alpha(weapon)
        max_dims = (body.width*.68,body.height*.78) if recipe['weapon'] in ('dao','jian','wokou_dao') else (body.width*.92,body.height*.85)
        weapon=fit_clip(weapon,*max_dims)
        grip=weapon_grip(recipe['weapon'],weapon)
        # Face right hand for right-handed melee; for row-based action body, detector tracks pose.
        attach(canvas,weapon,grip,(left+right_hand[0],top+right_hand[1]))
    return canvas,errors,(left_hand,right_hand)


def main():
    templates=load_json(PROJECT/'game/data/character_templates.json')
    chars=load_json(PROJECT/'game/data/characters.json')['characters']
    enemies=load_json(PROJECT/'game/data/enemies.json')['enemies']
    allies=load_json(PROJECT/'game/data/mercenaries.json')['mercenaries']
    targets=[]
    for key in ('wanglu','amei','ashi','achong'):
        targets.append((key,chars[key]['character_recipe']))
    for key,weapon in (('scout','dao'),('banner','qiang'),('archer','gong')):
        rec=dict(enemies[key]['character_recipe']); rec['weapon']=weapon; rec['offhand']='none'
        targets.append((f'enemy_{key}_{weapon}',rec))
    for key in ('yishi_spear','yishi_archer'):
        targets.append((f'ally_{key}',allies[key]['character_recipe']))

    OUT.mkdir(parents=True,exist_ok=True)
    all_errors=[]
    contact=Image.new('RGBA',(CELL*4*3, CELL*2*3),(27,33,38,255))
    # 9 targets, one 4-frame idle strip and one 8-frame walk strip each.
    summary=[]
    for idx,(name,recipe) in enumerate(targets):
        idle=[compose(recipe,templates,0,i) for i in range(4)]
        walk=[compose(recipe,templates,1,i) for i in range(8)]
        idle_strip=Image.new('RGBA',(CELL*4,CELL),(0,0,0,0))
        walk_strip=Image.new('RGBA',(CELL*8,CELL),(0,0,0,0))
        for i,(im,errs,anchors) in enumerate(idle):
            idle_strip.alpha_composite(im,(CELL*i,0)); all_errors += [f'{name} idle frame {i}: {e}' for e in errs]
        for i,(im,errs,anchors) in enumerate(walk):
            walk_strip.alpha_composite(im,(CELL*i,0)); all_errors += [f'{name} walk frame {i}: {e}' for e in errs]
        assert idle_strip.size == (512,128) and walk_strip.size == (1024,128)
        assert all(idle_strip.crop((i*CELL,0,(i+1)*CELL,CELL)).getchannel('A').getbbox() for i in range(4))
        assert all(walk_strip.crop((i*CELL,0,(i+1)*CELL,CELL)).getchannel('A').getbbox() for i in range(8))
        d=OUT/name; d.mkdir(exist_ok=True)
        idle_strip.save(d/'idle.png'); walk_strip.save(d/'walk.png')
        # First 4 idle frames then representative first 4 walk frames on contact sheet.
        x=(idx%3)*CELL*4; y=(idx//3)*CELL*2
        for i in range(4):
            contact.alpha_composite(idle[i][0],(x+i*CELL,y))
            contact.alpha_composite(walk[i*2][0],(x+i*CELL,y+CELL))
        summary.append({'name':name,'recipe':recipe,'idle_size':idle_strip.size,'walk_size':walk_strip.size,
                        'weapon_hand_coords_idle':[idle[i][2][1] for i in range(4)],
                        'offhand_coords_idle':[idle[i][2][0] for i in range(4)]})
    contact.save(OUT/'contact.png')
    unique_issues=sorted(set(e.split(': ',1)[1] for e in all_errors))
    (OUT/'manifest.json').write_text(json.dumps({'outputs':summary,'mapping_errors':unique_issues},ensure_ascii=False,indent=2)+'\n')
    print(f'{len(targets)} characters; {len(targets)*2} strips / {len(targets)*12} frames; sizes checked; contact={OUT}/contact.png')
    for e in unique_issues: print('MAPPING ISSUE:',e)

if __name__=='__main__': main()
