import numpy as np
from PIL import Image, ImageDraw, ImageFilter
S = 2048                      # supersampled canvas
B0, B1 = int(S*100/1024), int(S*924/1024)   # icon body bounds (Apple grid)
BS = B1 - B0

yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
def norm(v): return np.clip(v, 0, 1)

# --- squircle mask
u = (xx - (B0+B1)/2) / (BS/2); v = (yy - (B0+B1)/2) / (BS/2)
sq = np.abs(u)**5 + np.abs(v)**5
body_mask = norm((1 - sq) * 60)

# --- background: graphite gradient with soft top light
t = norm((yy - B0) / BS)
top = np.array([0.20, 0.215, 0.24]); bot = np.array([0.065, 0.07, 0.08])
bg = top[None,None,:]*(1-t[...,None]) + bot[None,None,:]*t[...,None]
glow = np.exp(-(((xx-(B0+BS*0.45))/(BS*0.55))**2 + ((yy-(B0+BS*0.1))/(BS*0.35))**2))
bg += glow[...,None]*0.06
img = bg.copy()

def over(img, color, alpha):
    a = alpha[...,None]
    return img*(1-a) + color*a

# --- platter
cx, cy, R = B0+BS*0.44, B0+BS*0.45, BS*0.34
dx, dy = xx-cx, yy-cy
rr = np.sqrt(dx*dx+dy*dy); th = np.arctan2(dy, dx)
pm = norm((R - rr)*1.0)
# shadow ring under platter
sh = norm((R+BS*0.02 - rr)/(BS*0.03)) * (1-pm)
img = over(img, np.zeros(3), sh*0.45)
rn = rr/R
base = 0.80 - 0.10*rn + 0.10*np.cos(rn*np.pi*2.2)
sheen = 0.20*np.cos(2*(th-0.6))**8 + 0.12*np.cos(2*(th+0.9))**16 - 0.08*np.cos(2*(th-2.1))**6
rings = 0.012*np.sin(rr*0.9) + 0.008*np.sin(rr*2.3+1)
lum = norm(base + sheen*(0.6+0.4*rn) + rings)
platter = np.stack([lum*0.97, lum*0.985, lum*1.0], -1)
img = over(img, platter, pm)
edge = norm(1 - np.abs(rr - R)/3.0)
img = over(img, np.zeros(3), edge*0.5)
# hub
hr = R*0.25
hm = norm((hr-rr)*1.0)
hl = norm(0.95 - 0.35*norm(np.sqrt((dx+hr*0.3)**2+(dy+hr*0.3)**2)/(hr*1.3)))
img = over(img, np.stack([hl,hl,hl*1.01],-1), hm)
img = over(img, np.zeros(3), norm(1-np.abs(rr-hr)/2.5)*0.35)
for i in range(6):
    a = i*np.pi/3 + 0.3
    px, py = cx+np.cos(a)*hr*0.62, cy+np.sin(a)*hr*0.62
    d = np.sqrt((xx-px)**2+(yy-py)**2)
    img = over(img, np.full(3,0.30), norm((hr*0.12-d)*1.0))
img = over(img, np.full(3,0.38), norm((hr*0.2-rr)*1.0))
img = np.clip(img, 0, 1)

pil = Image.fromarray((img*255).astype(np.uint8), 'RGB').convert('RGBA')

# --- actuator arm via polygon mask
def poly_mask(points, blur=0):
    m = Image.new('L', (S,S), 0); ImageDraw.Draw(m).polygon(points, fill=255)
    if blur: m = m.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(m).astype(np.float32)/255

px, py = B0+BS*0.83, B0+BS*0.82
d = np.hypot(cx-px, cy-py); L = BS*0.60
headR = R*0.62
base_ang = np.arctan2(cy-py, cx-px)
alpha = np.arccos(np.clip((d*d+L*L-headR*headR)/(2*d*L), -1, 1))
phi = base_ang + alpha
dirx, diry = np.cos(phi), np.sin(phi); perx, pery = -diry, dirx
tx, ty = px+dirx*L, py+diry*L
wb, wt = BS*0.06, BS*0.017
def armpts(o=(0,0)):
    return [(px+perx*wb+o[0], py+pery*wb+o[1]), (tx+perx*wt+o[0], ty+pery*wt+o[1]), (tx-perx*wt+o[0], ty-pery*wt+o[1]), (px-perx*wb+o[0], py-pery*wb+o[1])]
arr = np.asarray(pil).astype(np.float32)/255
rgb = arr[...,:3]
shadow = poly_mask(armpts((BS*0.012, BS*0.02)), blur=BS*0.012)
rgb = over(rgb, np.zeros(3), shadow*0.45)
am = poly_mask(armpts())
# gradient across arm width
proj = ((xx-px)*perx + (yy-py)*pery)/wb
al = norm(0.75 - 0.25*proj)
rgb = over(rgb, np.stack([al,al,al*1.01],-1), am)
# slider + pivot
for (qx,qy,r,c) in [(tx,ty,BS*0.028,0.18),(tx,ty,BS*0.012,None)]:
    dd = np.hypot(xx-qx, yy-qy)
    col = np.array([0.78,0.56,0.24]) if c is None else np.full(3,c)
    rgb = over(rgb, col, norm(r-dd))
dd = np.hypot(xx-px, yy-py)
pl = norm(0.95 - 0.5*norm(np.hypot(xx-px+BS*0.02, yy-py+BS*0.02)/(BS*0.09)))
rgb = over(rgb, np.stack([pl,pl,pl],-1), norm(BS*0.075-dd))
rgb = over(rgb, np.full(3,0.28), norm(BS*0.025-dd))

# --- LED with glow
lx, ly = B0+BS*0.155, B0+BS*0.855
dl = np.hypot(xx-lx, yy-ly)
green = np.array([0.25, 0.95, 0.45])
rgb = rgb + green[None,None,:]*np.exp(-(dl/(BS*0.07))**2)[...,None]*0.55
rgb = over(rgb, np.full(3,0.02), norm(BS*0.034-dl))
rgb = over(rgb, green, norm(BS*0.026-dl))
rgb = over(rgb, np.ones(3), norm(BS*0.009-np.hypot(xx-lx+BS*0.008, yy-ly+BS*0.008))*0.8)

# --- bezel highlight
inner = np.abs(u*1.0)**5 + np.abs(v*1.0)**5
rim = norm(1-np.abs(sq-0.93)/0.05) * norm((0.5 - v))
rgb = rgb + rim[...,None]*0.08
rgb = np.clip(rgb, 0, 1)

out = np.dstack([rgb, body_mask])
icon = Image.fromarray((out*255).astype(np.uint8), 'RGBA')
# drop shadow
sh = Image.fromarray((body_mask*255).astype(np.uint8), 'L').filter(ImageFilter.GaussianBlur(S*0.012))
canvas = Image.new('RGBA', (S,S), (0,0,0,0))
shadow_layer = Image.new('RGBA', (S,S), (0,0,0,0))
shadow_layer.putalpha(sh.point(lambda p: int(p*0.45)))
canvas.alpha_composite(shadow_layer, (0, int(S*0.012)))
canvas.alpha_composite(icon)
final = canvas.resize((1024,1024), Image.LANCZOS)
final.save('/home/claude/Platter/tools/icon_1024.png')
final.save('/home/claude/Platter/Resources/AppIcon.icns', sizes=[(16,16),(32,32),(64,64),(128,128),(256,256),(512,512),(1024,1024)])
print('ok')
