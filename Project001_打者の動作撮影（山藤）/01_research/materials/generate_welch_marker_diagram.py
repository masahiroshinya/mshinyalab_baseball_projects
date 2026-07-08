from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


OUT = Path(__file__).with_name("Welch_marker_placement_diagram.png")
W, H = 2000, 1200
BG = (255, 255, 255)
INK = (35, 35, 35)
BLUE = (31, 78, 121)
RED = (190, 45, 45)
ORANGE = (230, 120, 35)
LIGHT = (235, 242, 248)
GRAY = (110, 110, 110)


def font(size, bold=False):
    candidates = [
        r"C:\Windows\Fonts\YuGothB.ttc" if bold else r"C:\Windows\Fonts\YuGothM.ttc",
        r"C:\Windows\Fonts\meiryo.ttc",
        r"C:\Windows\Fonts\arial.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            pass
    return ImageFont.load_default()


F_TITLE = font(42, True)
F_HEAD = font(28, True)
F_BODY = font(23)
F_SMALL = font(19)


def line(draw, a, b, fill=INK, width=6):
    draw.line([a, b], fill=fill, width=width)


def marker(draw, xy, r=9, fill=RED):
    x, y = xy
    draw.ellipse((x - r, y - r, x + r, y + r), fill=fill, outline=(120, 0, 0), width=2)


def label(draw, xy, text, anchor="la", fill=INK, fnt=F_BODY):
    draw.text(xy, text, fill=fill, font=fnt, anchor=anchor)


def callout(draw, point, text, end, align="left"):
    line(draw, point, end, fill=GRAY, width=2)
    x, y = end
    if align == "right":
        label(draw, (x - 10, y - 12), text, anchor="ra", fnt=F_SMALL)
    else:
        label(draw, (x + 10, y - 12), text, fnt=F_SMALL)


def main():
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)

    draw.rectangle((0, 0, W, 96), fill=LIGHT)
    label(draw, (40, 26), "Welch et al. (1995) 反射マーカー装着位置（23点）", fnt=F_TITLE)
    label(
        draw,
        (40, 80),
        "Hitting a Baseball: A Biomechanical Description の Figure 1 と本文記述をもとにした模式図",
        fnt=F_SMALL,
        fill=GRAY,
    )

    cx = 720
    head = (cx, 170)
    neck = (cx, 235)
    c7 = (cx, 258)
    r_sho, l_sho = (cx - 150, 280), (cx + 150, 280)
    r_elb, l_elb = (cx - 250, 435), (cx + 250, 435)
    r_wri, l_wri = (cx - 210, 590), (cx + 210, 590)
    r_asis, l_asis = (cx - 105, 560), (cx + 105, 560)
    sacrum = (cx, 600)
    r_thigh, l_thigh = (cx - 105, 675), (cx + 105, 675)
    r_knee, l_knee = (cx - 95, 775), (cx + 95, 775)
    r_shank, l_shank = (cx - 85, 865), (cx + 85, 865)
    r_ank, l_ank = (cx - 75, 960), (cx + 75, 960)
    r_foot, l_foot = (cx - 120, 1005), (cx + 120, 1005)

    draw.ellipse((head[0] - 45, head[1] - 45, head[0] + 45, head[1] + 45), outline=INK, width=5)
    for a, b in [
        (neck, sacrum),
        (r_sho, l_sho),
        (neck, r_sho),
        (neck, l_sho),
        (r_sho, r_elb),
        (r_elb, r_wri),
        (l_sho, l_elb),
        (l_elb, l_wri),
        (r_asis, l_asis),
        (r_asis, r_knee),
        (l_asis, l_knee),
        (r_knee, r_ank),
        (l_knee, l_ank),
        (r_ank, r_foot),
        (l_ank, l_foot),
    ]:
        line(draw, a, b)

    body_markers = [
        r_sho,
        l_sho,
        c7,
        r_elb,
        l_elb,
        r_wri,
        l_wri,
        sacrum,
        r_asis,
        l_asis,
        r_knee,
        l_knee,
        r_ank,
        l_ank,
        r_foot,
        l_foot,
    ]
    for point in body_markers:
        marker(draw, point)
    for point in [r_thigh, l_thigh, r_shank, l_shank]:
        marker(draw, point, fill=ORANGE)

    callout(draw, r_sho, "肩: AC joint（左右）", (390, 260), "right")
    callout(draw, c7, "頸部: C7", (390, 320), "right")
    callout(draw, r_elb, "肘: lateral epicondyle（左右）", (390, 435), "right")
    callout(draw, r_wri, "手首: 尺骨/橈骨茎状突起間の背側（左右）", (390, 575), "right")
    callout(draw, r_asis, "骨盤前面: ASIS（左右）", (390, 660), "right")
    callout(draw, sacrum, "仙骨: L5", (390, 720), "right")
    callout(draw, r_thigh, "大腿 stick marker: 前額面定義（左右）", (390, 785), "right")
    callout(draw, r_knee, "膝: joint line（左右）", (390, 850), "right")
    callout(draw, r_shank, "下腿 stick marker: 前額面定義（左右）", (390, 915), "right")
    callout(draw, r_ank, "足関節: lateral malleolus（左右）", (390, 980), "right")
    callout(draw, r_foot, "前足部: 靴の上（左右）", (390, 1040), "right")

    bx1, by1 = 1240, 405
    bx2, by2 = 1605, 235
    draw.line((bx1, by1, bx2, by2), fill=(120, 80, 30), width=30)
    draw.line((bx1, by1, bx2, by2), fill=(170, 120, 55), width=18)
    bat_handle = (bx1 + 42, by1 - 20)
    bat_barrel = (bx2 - 8, by2 + 4)
    ball = (1530, 520)
    draw.ellipse((ball[0] - 34, ball[1] - 34, ball[0] + 34, ball[1] + 34), fill=(245, 245, 245), outline=INK, width=3)
    for point in [bat_handle, bat_barrel, ball]:
        marker(draw, point, r=8)

    label(draw, (1220, 150), "道具・ボールのマーカー", fnt=F_HEAD, fill=BLUE)
    callout(draw, bat_handle, "バット: 手のすぐ上のグリップ部", (1220, 470))
    callout(draw, bat_barrel, "バット: barrel end 上部", (1240, 245))
    callout(draw, ball, "ボール: 反射テープ", (1235, 540))

    draw.rounded_rectangle((1160, 705, 1900, 1040), radius=16, fill=LIGHT, outline=(180, 200, 215), width=2)
    label(draw, (1190, 735), "点数の内訳", fnt=F_HEAD, fill=BLUE)
    items = [
        ("身体: 20点", F_BODY, INK),
        ("  肩2, C7 1, 肘2, 手首2", F_BODY, INK),
        ("  L5 1, ASIS2, 大腿stick2", F_BODY, INK),
        ("  膝2, 下腿stick2, 足関節2, 前足部2", F_BODY, INK),
        ("ボール: 1点", F_BODY, INK),
        ("バット: 2点", F_BODY, INK),
        ("合計: 23点", F_HEAD, RED),
    ]
    y = 785
    for text, fnt, color in items:
        label(draw, (1195, y), text, fnt=fnt, fill=color)
        y += 36

    label(
        draw,
        (40, 1148),
        "注: stick marker は大腿・下腿セグメントの前額面を定義するためのマーカー。図は模式図であり、厳密な貼付角度・距離は元論文の写真/本文を確認。",
        fnt=F_SMALL,
        fill=GRAY,
    )
    img.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
