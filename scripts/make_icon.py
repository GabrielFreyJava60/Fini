from PIL import Image, ImageDraw, ImageFilter
S=1024
img=Image.new("RGB",(S,S))
top,bot=(18,32,74),(12,150,140)
d=ImageDraw.Draw(img)
for y in range(S):
    t=y/(S-1); d.line([(0,y),(S,y)],fill=tuple(int(a+(b-a)*t) for a,b in zip(top,bot)))
# glass card
glow=Image.new("L",(S,S),0); g=ImageDraw.Draw(glow)
g.rounded_rectangle([200,250,824,774],radius=110,fill=90)
glow=glow.filter(ImageFilter.GaussianBlur(6))
img=Image.composite(Image.new("RGB",(S,S),(255,255,255)),img,glow)
d=ImageDraw.Draw(img)
d.rounded_rectangle([200,250,824,774],radius=110,outline=(230,250,255),width=10)
# rising runway line
pts=[(270,640),(400,580),(500,610),(620,470),(750,380)]
d.line(pts,fill=(255,255,255),width=34,joint="curve")
for x,y in (pts[0],pts[-1]): d.ellipse([x-26,y-26,x+26,y+26],fill=(255,255,255))
d.ellipse([750-60,380-60,750+60,380+60],outline=(120,255,220),width=12)
img.save("src/finance/resources/icons/fini-1024.png")
for s in (20,29,40,58,60,76,80,87,120,152,167,180):
    img.resize((s,s),Image.LANCZOS).save(f"src/finance/resources/icons/fini-{s}.png")
