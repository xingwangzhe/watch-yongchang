from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from math import cos, sin, radians

ROOT=Path('/home/xingwangzhe/桌面/2026游戏赛事/pixel-art/model_redraw')
OUT=Path('/tmp/yongchang-asset-qa/mounted_composition')
CELL=128

def grid(name,cols,rows,row,col):
    im=Image.open(ROOT/name).convert('RGBA'); w,h=im.size
    return im.crop((round(col*w/cols),round(row*h/rows),round((col+1)*w/cols),round((row+1)*h/rows)))

def crop_alpha(im,threshold=128):
    im=im.convert('RGBA')
    im.putalpha(im.getchannel('A').point(lambda a:255 if a>=threshold else 0))
    b=im.getchannel('A').getbbox()
    return (im.crop(b),b) if b else (im,(0,0,im.width,im.height))

def fit(im,mw,mh):
    im,_=crop_alpha(im)
    s=min(mw/im.width,mh/im.height)
    size=(max(1,round(im.width*s)),max(1,round(im.height*s)))
    return im.resize(size,Image.Resampling.NEAREST)

def place_center(dst,im,center):
    dst.alpha_composite(im,(round(center[0]-im.width/2),round(center[1]-im.height/2)))

def skin_regions(im):
    p=im.load(); mask=set()
    for y in range(im.height):
      for x in range(im.width):
        r,g,b,a=p[x,y]
        if a>=128 and r>=115 and g>=55 and r>g*1.1 and g>b*1.06: mask.add((x,y))
    comps=[]
    while mask:
      seed=mask.pop(); q=[seed]; xs=[];ys=[]
      while q:
        x,y=q.pop(); xs.append(x);ys.append(y)
        for pt in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
          if pt in mask:mask.remove(pt);q.append(pt)
      if len(xs)>=8:
        b=(min(xs),min(ys),max(xs)+1,max(ys)+1); comps.append((sum(xs)/len(xs),sum(ys)/len(ys),len(xs),b))
    return comps

def hands(im,min_factor=.34):
    comps=[c for c in skin_regions(im) if min_factor*im.height < c[1] < .76*im.height]
    if len(comps)>=2:
      comps.sort(key=lambda c:c[0]); return [(comps[0][0],comps[0][1]),(comps[-1][0],comps[-1][1])],None
    if comps:
      c=max(comps,key=lambda x:x[2]); return [(c[0]-5,c[1]),(c[0]+5,c[1])],'hands merged'
    raise ValueError('no hand skin regions')

def rotate_with_anchor(im,point,angle):
    # Pillow rotate(angle) is counterclockwise; forward map in image coordinates.
    oldw,oldh=im.size
    rot=im.rotate(angle,resample=Image.Resampling.NEAREST,expand=True)
    a=radians(-angle) # visual CCW maps vector using inverse screen y
    co,si=cos(a),sin(a)
    cx,cy=oldw/2,oldh/2
    ncx,ncy=rot.width/2,rot.height/2
    x,y=point
    out=(ncx+co*(x-cx)-si*(y-cy), ncy+si*(x-cx)+co*(y-cy))
    cropped,b=crop_alpha(rot)
    return cropped,(out[0]-b[0],out[1]-b[1])

def held_prop(dst,raw,hand,kind):
    obj,_=crop_alpha(raw)
    if kind=='lance':
      grip=(obj.width*.12,obj.height*.88)
      obj,grip=rotate_with_anchor(obj,grip,-45)
      scale=min(62/obj.width,18/obj.height)
    elif kind=='bow':
      grip=(obj.width*.50,obj.height*.50); scale=min(36/obj.width,56/obj.height)
    else:
      grip=(obj.width*.15,obj.height*.88); scale=min(44/obj.width,56/obj.height)
    size=(max(1,round(obj.width*scale)),max(1,round(obj.height*scale)))
    obj=obj.resize(size,Image.Resampling.NEAREST); grip=(grip[0]*scale,grip[1]*scale)
    dst.alpha_composite(obj,(round(hand[0]-grip[0]),round(hand[1]-grip[1])))

def compose(horse_row,action_row,frame_idx,weapon_kind):
    dst=Image.new('RGBA',(CELL,CELL),(0,0,0,0))
    horse_src=grid('horse_motion_v4.png',8,3,horse_row,frame_idx)
    horse,b=crop_alpha(horse_src)
    # One fixed source scale and source-cell anchor preserve horse body size across all gait frames.
    horse_scale=.44
    horse=horse.resize((round(horse.width*horse_scale),round(horse.height*horse_scale)),Image.Resampling.NEAREST)
    hleft=round(CELL/2 - (horse_src.width/2-b[0])*horse_scale)
    htop=CELL-9-horse.height
    dst.alpha_composite(horse,(hleft,htop))
    # Tack cells: saddle blanket, saddle, bridle, and individual stirrups.
    blanket,_=crop_alpha(grid('cavalry_tack_v2.png',4,2,0,1)); blanket=fit(blanket,50,30)
    saddle,_=crop_alpha(grid('cavalry_tack_v2.png',4,2,0,0)); saddle=fit(saddle,38,25)
    place_center(dst,blanket,(54,70)); place_center(dst,saddle,(60,66))
    bridle,_=crop_alpha(grid('cavalry_tack_v2.png',4,2,0,2)); bridle=fit(bridle,18,21)
    place_center(dst,bridle,(105,61))
    stirrup_src,_=crop_alpha(grid('cavalry_tack_v2.png',4,2,0,3))
    # Split the generated pair into left/right parts by halves, then fit each.
    sw=stirrup_src.width
    stirrups=[]
    for side in (stirrup_src.crop((0,0,sw//2,stirrup_src.height)),stirrup_src.crop((sw//2,0,sw,stirrup_src.height))):
      side,_=crop_alpha(side); stirrups.append(fit(side,13,19))
    place_center(dst,stirrups[0],(52,91)); place_center(dst,stirrups[1],(79,91))
    # Seated rider body: pin pelvis to saddle, keep a fixed source scale and camera-facing layer.
    rider_src=grid('rider_body_motion_v2.png',8,3,action_row,frame_idx)
    rider_src=rider_src.convert('RGBA'); rider_src.putalpha(rider_src.getchannel('A').point(lambda a:255 if a>=128 else 0))
    bbox=rider_src.getchannel('A').getbbox()
    if not bbox: raise ValueError('empty rider cell')
    rider=rider_src.crop(bbox)
    hand_src,_=hands(rider_src,{0:.30,1:.18,2:.25}[action_row])
    scale=.30
    rider=rider.resize((round(rider.width*scale),round(rider.height*scale)),Image.Resampling.NEAREST)
    # Approximate pelvis pivot from source cell; pin it to saddle center for all motion phases.
    pivot_src=(.62*rider_src.width,.55*rider_src.height)
    pivot=(pivot_src[0]-bbox[0],pivot_src[1]-bbox[1])
    rp=(65,70)
    rleft=round(rp[0]-pivot[0]*scale); rtop=round(rp[1]-pivot[1]*scale)
    dst.alpha_composite(rider,(rleft,rtop))
    hand_targets=[]
    for x,y in hand_src:
      hand_targets.append((rleft+(x-bbox[0])*scale,rtop+(y-bbox[1])*scale))
    # Red Ming helmet cell from equipment_modular_v3 row 3, column 1; drawn over head.
    helm,_=crop_alpha(grid('equipment_modular_v3.png',8,4,2,0)); helm=fit(helm,22,17)
    head_point=(rleft+(.63*rider_src.width-bbox[0])*scale,rtop+(.16*rider_src.height-bbox[1])*scale)
    place_center(dst,helm,head_point)
    # Held prop is explicitly drawn above complete rider and helmet.
    weapon_rc={'saber':(0,0),'lance':(0,2),'bow':(2,1)}[weapon_kind]
    weapon=grid('weapons_modular_v4.png',5,4,*weapon_rc)
    hand=hand_targets[0] if weapon_kind=='lance' else hand_targets[-1]
    held_prop(dst,weapon,hand,weapon_kind)
    return dst, {'horse_bbox':b,'rider_bbox':bbox,'hand_targets':hand_targets,'rider_anchor':rp,'weapon_hand':hand}

if __name__=='__main__':
    from PIL import ImageChops
    import json
    OUT.mkdir(parents=True,exist_ok=True)
    actions=[('lance',0),('bow',1),('saber',2)]
    coats=[('chestnut',0),('black',1),('grey',2)]
    sheet=Image.new('RGBA',(CELL*8*3,CELL*3),(24,30,34,255))
    draw=ImageDraw.Draw(sheet)
    try: font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',14)
    except: font=ImageFont.load_default()
    report=[]
    for ar,(action,action_row) in enumerate(actions):
      for hc,(coat,horse_row) in enumerate(coats):
        frames=[]; metadata=[]
        for frame_idx in range(8):
          img,meta=compose(horse_row,action_row,frame_idx,action)
          frames.append(img); metadata.append(meta)
          # 8-frame strip artifacts for separate animation review.
          strip=Image.new('RGBA',(CELL*8,CELL),(0,0,0,0)) if frame_idx==0 else strip
          strip.alpha_composite(img,(frame_idx*CELL,0))
        folder=OUT/coat/action; folder.mkdir(parents=True,exist_ok=True)
        strip.save(folder/'walk_action_8f.png')
        # All 8 phases are displayed for every coat/action combination.
        ox=hc*CELL*8; oy=ar*CELL
        for idx,img in enumerate(frames): sheet.alpha_composite(img,(ox+idx*CELL,oy))
        draw.text((ox+4,oy+4),f'{coat} / {action}',fill=(240,224,192,255),font=font)
        diffs=[]
        for a,b in zip(frames,frames[1:]+frames[:1]):
          diff=ImageChops.difference(a.convert('RGBA'),b.convert('RGBA'))
          changed=sum(1 for px in diff.getdata() if px[0] or px[1] or px[2] or px[3])
          diffs.append(changed)
        bounds=[img.getchannel('A').getbbox() for img in frames]
        report.append({'coat':coat,'action':action,'frames':8,
          'frame_changed_pixels_0_7_loop':diffs,
          'min_frame_changes':min(diffs),'max_frame_changes':max(diffs),
          'combined_alpha_bounds':bounds,
          'horse_anchor_baseline_y':119,
          'rider_pelvis_anchor_px':[65,70],
          'weapons_after_complete_rider':True,
          'tack_layers':['blanket','saddle','bridle','stirrups']})
    sheet.save(OUT/'mounted_all_frames_contact.png')
    sheet.resize((sheet.width*2,sheet.height*2),Image.Resampling.NEAREST).save(OUT/'mounted_all_frames_contact_2x.png')
    (OUT/'mount_manifest.json').write_text(json.dumps({'source_files':['horse_motion_v4.png','rider_body_motion_v2.png','cavalry_tack_v2.png','equipment_modular_v3.png','weapons_modular_v4.png'],'composition_order':['horse','blanket/saddle/bridle/stirrups','rider body','headgear','held weapon'],'outputs':report},ensure_ascii=False,indent=2)+'\n')
    print('wrote',OUT/'mounted_all_frames_contact.png',sheet.size,'combos',len(report),'frames',len(report)*8)
    for r in report:
      print(r['coat'],r['action'],'min_change',r['min_frame_changes'],'loop_change',r['frame_changed_pixels_0_7_loop'][-1],'bounds',r['combined_alpha_bounds'][0],r['combined_alpha_bounds'][-1])
