"""Internal daylight contact sheets. Requires Pillow and the local Isaac GIFs.
Pass --wide and --small the output trees of the two native-window Godot tests.
The game has no dependency on this script, screenshots, GIFs or Pillow.
"""
import argparse, json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parents[2]
BG='#18232a'; INK='#eae6d8'; SOFT='#b7c0b8'; RULE='#425456'; GOLD='#edbc6a'; PANEL='#29383d'
NN=Image.Resampling.NEAREST

def font(n,bold=False):
    for s in (('msyhbd.ttc','NotoSansCJK-Bold.ttc','DejaVuSans-Bold.ttf') if bold else ('msyh.ttc','NotoSansCJK-Regular.ttc','DejaVuSans.ttf')):
        try: return ImageFont.truetype(s,n)
        except OSError: pass
    return ImageFont.load_default()

def text(d,xy,t,n=16,color=INK,bold=False):d.text(xy,t,font=font(n,bold),fill=color,anchor='lt')

def plate(title,kicker,sub,w,h):
    im=Image.new('RGB',(w,h),BG); d=ImageDraw.Draw(im)
    text(d,(28,17),'LAKESIDE CABIN     /     CHARACTER STUDY     /     '+kicker,13,GOLD,True)
    text(d,(27,42),title,31,INK,True); text(d,(29,87),sub,15,SOFT)
    d.line((28,115,w-28,115),fill=RULE,width=1)
    text(d,(28,h-33),'内部造型对照   /   参考帧仅作比较；实拍来自主地图 Pixels 或 RoomPixels。放大只用最近邻。',14,SOFT)
    return im,d

def gif(name,k):
    with Image.open(ROOT/'ref'/('Isaac'+name+'.gif')) as src:
        frames=[]
        for i in range(src.n_frames):src.seek(i);frames.append(src.convert('RGBA'))
    cell=Image.new('RGBA',(36,39));row=max(f.getbbox()[3] for f in frames); f=frames[k]
    cell.paste(f,((36-f.width)//2,35-row));return cell

def image_for(path,info,key,ratio):
    im=Image.open(path/(key+'.png')).convert('RGB');x,y=info[key]['foot']
    # Registered crop in real viewport pixels; keep shoulders, soles, shadow
    # and surrounding ground. Do not stretch/correct poses or colour-match.
    w,h,b=(36,39,35) if ratio==1 else (24,26,23)
    return im.crop((x-w//2,y-b,x-w//2+w,y-b+h))

def paste_tile(sheet,d,cell,x,y,z):
    if cell.mode=='RGBA':
        mat=Image.new('RGB',cell.size,PANEL);mat.paste(cell,mask=cell.getchannel('A'));cell=mat
    cell=cell.resize((cell.width*z,cell.height*z),NN);sheet.paste(cell,(x,y));d.rectangle((x-1,y-1,x+cell.width,y+cell.height),outline=RULE)

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    for k in ('wide','small','out'):ap.add_argument('--'+k,type=Path,required=True)
    args=ap.parse_args();w,s,out=args.wide,args.small,args.out
    M=[json.loads((p/'captures.json').read_text('utf-8-sig')) for p in (w,s)]
    files=('turnaround.png','stride.png','in-play.png')
    out.mkdir(parents=True,exist_ok=True)
    if any((out/f).exists() for f in files):raise SystemExit('Refusing to overwrite a proof image.')
    dirs=('S','SW','W','NW','N','NE','E','SE');suffix=('','_SW','_Left','_NW','_Back','_NE','_Right','_SE')
    sheet,d=plate('同一具模型，八个朝向','01   TURNAROUND','上排为参考 GIF 的首帧。下两排来自实际走、停后的同一时刻；日光和场景遮挡保留。',1388,726)
    gutter=144;col=151
    for i,(key,suf) in enumerate(zip(dirs,suffix)):
        x=gutter+i*col;text(d,(x,132),key,18,GOLD,True)
        paste_tile(sheet,d,gif(suf,0),x,164,4)
        paste_tile(sheet,d,image_for(w,M[0],'idle_'+key,1),x,342,4)
        paste_tile(sheet,d,image_for(s,M[1],'idle_'+key,2),x,522,6)
    for j,(s1,s2) in enumerate([('参考首帧','GIF  ×4'),('3D 实拍','480  ×4'),('3D 实拍','320  ×6')]):
        y=(164,342,522)[j];text(d,(28,y+45),s1,18,INK,True);text(d,(29,y+73),s2,14,SOFT)
    sheet.save(out/files[0],optimize=True)
    sheet,d=plate('斜前方的六个重心位置','02   LOCOMOTION','从左到右为同一循环的六个相位。保留脚下原画布余量；3D 截图按真实走跑位移取样，不按参考逐格换图。',1080,1106)
    for i in range(6):text(d,(151+153*i,132),'0'+str(i+1),16,GOLD,True)
    for ai,act in enumerate(('walk','run')):
        base=162+ai*454
        text(d,(27,base+3),'走' if ai==0 else '跑',32,GOLD,True)
        for ri,(name,zoom) in enumerate([('参考 GIF',3),('480 实拍',3),('320 实拍',5)]):
            y=base+ri*142
            text(d,(30,y+50),name,16,INK,True);text(d,(31,y+76),'正交 SW' if ri else 'SW · 150 ms',12,SOFT)
            for k in range(6):
                key=f'{act}_SW_{k}'; cell=gif('_'+act.capitalize()+'_SW',k) if ri==0 else image_for((w,s)[ri-1],M[ri-1],key,ri)
                paste_tile(sheet,d,cell,151+153*k,y,zoom)
        if ai==0:d.line((27,base+433,1052,base+433),fill=RULE)
    sheet.save(out/files[1],optimize=True)
    sheet,d=plate('原地图、门内，以及真实的转面','03   IN PLAY','上方是未放大的两档游戏缓冲。下方局部是同一角色站定后转动相机，及同一朝向抬头、瞬目。',1120,1054)
    for j,(path,m,lab,x,yy) in enumerate([(w,M[0],'480 × 270',30,158),(s,M[1],'320 × 180',590,158)]):
        text(d,(x,130),lab,18,GOLD,True)
        for i,key in enumerate(('spawn','cabin')):
            im=Image.open(path/(key+'.png')).convert('RGB');y=yy+i*(im.height+27);sheet.paste(im,(x,y)); d.rectangle((x-1,y-1,x+im.width,y+im.height),outline=RULE);text(d,(x+im.width+9,y+4),'外' if i==0 else '内',14,SOFT)
    text(d,(590,568),'斜前待机原 GIF：稳脚、侧摆、瞬目',16,SOFT,True)
    for i,k in enumerate((0,2,3)):paste_tile(sheet,d,gif('_SE',k),591+i*139,598,3)
    d.line((29,738,1090,738),fill=RULE)
    text(d,(30,755),'原地持姿 · 只转相机',19,GOLD,True);text(d,(585,755),'斜前待机 · 关节在动',19,GOLD,True)
    for i,(key,label) in enumerate([('orbit_0','0°  正面'),('orbit_90','90°  侧面'),('orbit_180','180°  背面'),('idle_SE','稳脚'),('idle_shift','抬头'),('idle_blink','瞬目')]):
        x=30+i*178+(21 if i>=3 else 0);cell=image_for(w,M[0],key,1);paste_tile(sheet,d,cell,x,793,4);text(d,(x,960),label,15,SOFT)
    sheet.save(out/files[2],optimize=True)
    for f in files:print(out/f)
if __name__=='__main__':main()
