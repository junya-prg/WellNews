#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# Setup paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR = os.path.join(BASE_DIR, "screenshots", "raw")
PROCESSED_DIR = os.path.join(BASE_DIR, "screenshots", "processed")
MOCKUP_SRC_PATH = os.path.join(BASE_DIR, "screenshots", "1_news_feed.png")

# Text definitions for the screenshots
SCREENSHOT_TEXTS = {
    1: {
        "title": "AIが健康ニュースを要約",
        "subtitle": "信頼できる情報から、欲しいトピックを瞬時にキャッチ"
    },
    2: {
        "title": "健康ラジオで「ながら聴き」",
        "subtitle": "プロの音声読み上げ機能で、移動中も快適にインプット"
    },
    3: {
        "title": "関心ワードでパーソナライズ",
        "subtitle": "気になるキーワードを登録して、自動でニュースを収集"
    },
    4: {
        "title": "重要な記事をブックマーク",
        "subtitle": "後から読み返したいニュースを、ワンタップで保存"
    },
    5: {
        "title": "プレミアムですべての制限解除",
        "subtitle": "広告非表示＆すべての機能が使い放題の快適な体験へ"
    }
}

# Device configurations for portrait 3D App Store screenshots
DEVICE_CONFIGS = [
    {
        "name": "6.7_inch",
        "width": 1290,
        "height": 2796,
        "title_size": 96,
        "subtitle_size": 46,
        "title_y": 320,
        "subtitle_y": 470,
        "phone_w": 1180,
        "phone_y": 920
    },
    {
        "name": "6.5_inch",
        "width": 1284,
        "height": 2778,
        "title_size": 96,
        "subtitle_size": 46,
        "title_y": 320,
        "subtitle_y": 470,
        "phone_w": 1180,
        "phone_y": 920
    },
    {
        "name": "5.5_inch",
        "width": 1242,
        "height": 2208,
        "title_size": 80,
        "subtitle_size": 40,
        "title_y": 240,
        "subtitle_y": 370,
        "phone_w": 1100,
        "phone_y": 750
    }
]

# Coefficients from background polynomial fit for high-quality shadow extraction
coeffs_r = [16.561640210623427, -0.0031961672887706573, -0.0027011696967839415, 1.5925720791101347e-06, 2.221755058085407e-06, 2.392314722297261e-06]
coeffs_g = [119.22787044285693, -0.07242491542927847, -0.06866445143463455, -1.8027885071090818e-06, -2.85491729762468e-06, 5.554126695007043e-05]
coeffs_b = [87.16610679949211, -0.022844661141029753, -0.023376705006573944, 2.9716130150385967e-06, 2.885689064975419e-06, 1.823511564248549e-05]

# Screen warping points
dst_pts = [(472, 274), (749, 290), (572, 943), (254, 878)]

def solve_perspective(src_pts, dst_pts):
    A = []
    B = []
    for (xs, ys), (xd, yd) in zip(src_pts, dst_pts):
        A.append([xd, yd, 1, 0, 0, 0, -xs * xd, -xs * yd])
        B.append(xs)
        A.append([0, 0, 0, xd, yd, 1, -ys * xd, -ys * yd])
        B.append(ys)
        
    n = len(B)
    for i in range(n):
        pivot_row = i
        for r in range(i + 1, n):
            if abs(A[r][i]) > abs(A[pivot_row][i]):
                pivot_row = r
        A[i], A[pivot_row] = A[pivot_row], A[i]
        B[i], B[pivot_row] = B[pivot_row], B[i]
        
        pivot = A[i][i]
        for r in range(i + 1, n):
            factor = A[r][i] / pivot
            for c in range(i, n):
                A[r][c] -= factor * A[i][c]
            B[r] -= factor * B[i]
            
    X = [0] * n
    for i in range(n - 1, -1, -1):
        sum_ax = sum(A[i][j] * X[j] for j in range(i + 1, n))
        X[i] = (B[i] - sum_ax) / A[i][i]
        
    return tuple(X)

def get_font(size, is_bold=False):
    if is_bold:
        font_path = "/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc"
    else:
        font_path = "/System/Library/Fonts/Hiragino Sans GB.ttc"
        
    if os.path.exists(font_path):
        try:
            return ImageFont.truetype(font_path, size, index=0)
        except IOError:
            pass
            
    # Fallback paths
    fallback_paths = [
        "/System/Library/Fonts/AppleSDGothicNeo.ttc",
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    ]
    for path in fallback_paths:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except IOError:
                continue
    return ImageFont.load_default()

def create_fresh_background(width, height):
    base = Image.new("RGBA", (width, height), (240, 253, 244, 255))
    blob_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    blob_draw = ImageDraw.Draw(blob_layer)
    
    # Draw overlapping large soft color circles to make a fresh mesh gradient
    blob_draw.ellipse([width - 800, -200, width + 400, 1000], fill=(187, 247, 208, 120)) # #bbf7d0 mint green
    blob_draw.ellipse([-400, height // 2 - 600, 600, height // 2 + 400], fill=(186, 230, 253, 100)) # #bae6fd sky blue
    blob_draw.ellipse([width - 700, height - 900, width + 300, height + 100], fill=(153, 246, 228, 110)) # #99f6e4 teal
    blob_draw.ellipse([-300, -300, 500, 500], fill=(254, 240, 138, 70)) # #fef08a yellow
    
    # Apply Gaussian Blur to blend the blobs into a modern mesh gradient
    blob_blurred = blob_layer.filter(ImageFilter.GaussianBlur(180))
    background = Image.alpha_composite(base, blob_blurred).convert('RGB')
    return background

# Load mockup template resources
mockup = Image.open(MOCKUP_SRC_PATH).convert("RGBA")
raw_mockup_rgb = mockup.convert("RGB")

# Generate phone body mask with rounded corners using 4x supersampling
outer_pts = [
    (424, 238),   # Top-Left outer
    (786, 256),   # Top-Right outer
    (591, 962),   # Bottom-Right outer
    (219, 886)    # Bottom-Left outer
]
mask_large = Image.new("L", (1024 * 4, 1024 * 4), 0)
mask_draw_large = ImageDraw.Draw(mask_large)
outer_pts_large = [(x * 4, y * 4) for (x, y) in outer_pts]
mask_draw_large.polygon(outer_pts_large, fill=255)
mask_large = mask_large.filter(ImageFilter.GaussianBlur(48))
mask_large = mask_large.point(lambda p: 255 if p > 120 else 0)
phone_body_mask = mask_large.resize((1024, 1024), Image.Resampling.LANCZOS)

# Generate screen corner mask
mask_large_screen = Image.new("L", (1024 * 4, 1024 * 4), 0)
mask_draw_large_screen = ImageDraw.Draw(mask_large_screen)
dst_pts_large = [(x * 4, y * 4) for (x, y) in dst_pts]
mask_draw_large_screen.polygon(dst_pts_large, fill=255)
mask_large_screen = mask_large_screen.filter(ImageFilter.GaussianBlur(24))
mask_large_screen = mask_large_screen.point(lambda p: 255 if p > 135 else 0)
screen_mask = mask_large_screen.resize((1024, 1024), Image.Resampling.LANCZOS)

def build_phone_card(raw_screen_path):
    raw_img = Image.open(raw_screen_path).convert("RGBA")
    sw, sh = raw_img.size
    src_pts = [(0, 0), (sw, 0), (sw, sh), (0, sh)]
    coeffs = solve_perspective(src_pts, dst_pts)
    warped = raw_img.transform((1024, 1024), Image.PERSPECTIVE, coeffs, Image.Resampling.BICUBIC)
    
    # Overlay screen onto template phone
    overlay_img = mockup.copy()
    overlay_img.paste(warped, (0, 0), screen_mask)
    
    # Crop the phone bounding box (including shadow margin)
    # Box is (150, 150, 900, 980) -> width 750, height 830
    phone_box = (150, 150, 900, 980)
    card_rgb = overlay_img.crop(phone_box).convert("RGB")
    card_mask = phone_body_mask.crop(phone_box)
    
    final_card = Image.new("RGBA", (750, 830), (0, 0, 0, 0))
    
    # Draw alpha shadow using background difference factor
    shadow_img = Image.new("RGBA", (750, 830), (0, 0, 0, 0))
    for y in range(830):
        orig_y = y + 150
        for x in range(750):
            orig_x = x + 150
            is_body = card_mask.getpixel((x, y)) > 0
            if not is_body:
                t = [1.0, orig_x, orig_y, orig_x*orig_x, orig_y*orig_y, orig_x*orig_y]
                pr = sum(c*term for c, term in zip(coeffs_r, t))
                pg = sum(c*term for c, term in zip(coeffs_g, t))
                pb = sum(c*term for c, term in zip(coeffs_b, t))
                
                r, g, b = raw_mockup_rgb.getpixel((orig_x, orig_y))
                
                den_r = max(1.0, pr)
                den_g = max(1.0, pg)
                den_b = max(1.0, pb)
                
                factor = ((r / den_r) + (g / den_g) + (b / den_b)) / 3.0
                factor = max(0.4, min(1.0, factor))
                
                if factor < 0.98:
                    alpha = int(255 * (1.0 - factor) * 1.5) # Amplify shadow contrast
                    alpha = max(0, min(255, alpha))
                    shadow_img.putpixel((x, y), (15, 23, 42, alpha))
                    
    # Combine shadow and phone body
    final_card.paste(shadow_img, (0, 0), shadow_img)
    final_card.paste(card_rgb, (0, 0), card_mask)
    return final_card

def process_screenshot(index, config):
    width = config["width"]
    height = config["height"]
    device_name = config["name"]
    title_size = config["title_size"]
    subtitle_size = config["subtitle_size"]
    title_y = config["title_y"]
    subtitle_y = config["subtitle_y"]
    phone_w = config["phone_w"]
    phone_y = config["phone_y"]
    
    # Check if raw screenshot exists
    raw_img_path = os.path.join(RAW_DIR, f"raw_{index}.png")
    if not os.path.exists(raw_img_path):
        print(f"❌ Error: {raw_img_path} does not exist.")
        return False
        
    # 1. Generate fresh background canvas
    canvas = create_fresh_background(width, height)
    draw = ImageDraw.Draw(canvas)
    
    # 2. Draw text titles and subtitles in premium Slate colors
    text_info = SCREENSHOT_TEXTS.get(index)
    title = text_info["title"]
    subtitle = text_info["subtitle"]
    
    title_font = get_font(title_size, is_bold=True)
    subtitle_font = get_font(subtitle_size, is_bold=False)
    
    # Center and draw title (Slate 900)
    title_bbox = draw.textbbox((0, 0), title, font=title_font)
    title_w = title_bbox[2] - title_bbox[0]
    draw.text(((width - title_w) // 2, title_y), title, fill=(15, 23, 42, 255), font=title_font)
    
    # Center and draw subtitle (Slate 600)
    subtitle_bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
    subtitle_w = subtitle_bbox[2] - subtitle_bbox[0]
    draw.text(((width - subtitle_w) // 2, subtitle_y), subtitle, fill=(71, 85, 105, 255), font=subtitle_font)
    
    # 3. Build the photorealistic iPhone card (phone body + new warped screen + shadow)
    phone_card = build_phone_card(raw_img_path)
    
    # Resize and place onto canvas
    phone_h = int(830 * (phone_w / 750.0))
    phone_resized = phone_card.resize((phone_w, phone_h), Image.Resampling.LANCZOS)
    
    paste_x = (width - phone_w) // 2
    canvas.paste(phone_resized, (paste_x, phone_y), phone_resized)
    
    # 4. Save to device specific folder
    out_dir = os.path.join(PROCESSED_DIR, device_name)
    os.makedirs(out_dir, exist_ok=True)
    output_path = os.path.join(out_dir, f"store_screenshot_{index}.png")
    
    canvas.save(output_path, "PNG")
    print(f"✅ Generated [{device_name}] screenshot: {output_path}")
    return True

def main():
    print("🎨 Compositing premium 3D photorealistic portrait screenshots...")
    
    # Ensure raw mockup resource exists
    if not os.path.exists(MOCKUP_SRC_PATH):
        print(f"❌ Error: Mockup source file not found at {MOCKUP_SRC_PATH}.")
        sys.exit(1)
        
    for config in DEVICE_CONFIGS:
        print(f"\n--- Generating for {config['name']} ({config['width']}x{config['height']}) ---")
        success_count = 0
        for i in range(1, 6):
            if process_screenshot(i, config):
                success_count += 1
        print(f"🎉 Successfully completed {success_count}/5 screenshots for {config['name']}.")

if __name__ == "__main__":
    main()
