#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# Setup paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR = os.path.join(BASE_DIR, "screenshots", "raw")
PROCESSED_DIR = os.path.join(BASE_DIR, "screenshots", "processed")

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

# Device configurations for portrait App Store screenshots
DEVICE_CONFIGS = [
    {
        "name": "6.7_inch",
        "width": 1290,
        "height": 2796,
        "title_size": 72,
        "subtitle_size": 30,
        "title_y": 220,
        "subtitle_y": 330,
        "phone_w": 940,
        "phone_y": 460
    },
    {
        "name": "6.5_inch",
        "width": 1284,
        "height": 2778,
        "title_size": 72,
        "subtitle_size": 30,
        "title_y": 220,
        "subtitle_y": 330,
        "phone_w": 940,
        "phone_y": 460
    },
    {
        "name": "5.5_inch",
        "width": 1242,
        "height": 2208,
        "title_size": 64,
        "subtitle_size": 28,
        "title_y": 160,
        "subtitle_y": 250,
        "phone_w": 800,
        "phone_y": 360
    }
]

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
    # Base gradient background (light mint #F0FDF4)
    base = Image.new("RGBA", (width, height), (240, 253, 244, 255))
    blob_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    blob_draw = ImageDraw.Draw(blob_layer)
    
    # Draw overlapping large soft color circles
    blob_draw.ellipse([width - 800, -200, width + 400, 1000], fill=(187, 247, 208, 120)) # #bbf7d0 mint green
    blob_draw.ellipse([-400, height // 2 - 600, 600, height // 2 + 400], fill=(186, 230, 253, 100)) # #bae6fd sky blue
    blob_draw.ellipse([width - 700, height - 900, width + 300, height + 100], fill=(153, 246, 228, 110)) # #99f6e4 teal
    blob_draw.ellipse([-300, -300, 500, 500], fill=(254, 240, 138, 70)) # #fef08a yellow
    
    # Apply Gaussian Blur to blend the blobs into a modern mesh gradient
    blob_blurred = blob_layer.filter(ImageFilter.GaussianBlur(180))
    background = Image.alpha_composite(base, blob_blurred)
    return background

def make_device_mockup(screen_image_path, bezel_width=24, corner_radius=76):
    screen_img = Image.open(screen_image_path).convert("RGBA")
    sw, sh = screen_img.size
    
    mw = sw + bezel_width * 2
    mh = sh + bezel_width * 2
    
    mockup = Image.new("RGBA", (mw, mh), (0, 0, 0, 0))
    draw = ImageDraw.Draw(mockup)
    
    # Outer device bezel (Slate 900)
    bezel_color = (15, 23, 42, 255)
    draw.rounded_rectangle([0, 0, mw, mh], radius=corner_radius + bezel_width, fill=bezel_color)
    
    # Inner highlighting border (Slate 600)
    inner_border_color = (71, 85, 105, 255)
    draw.rounded_rectangle([2, 2, mw - 2, mh - 2], radius=corner_radius + bezel_width - 2, fill=None, outline=inner_border_color, width=2)
    
    # Screen mask for rounded corners
    screen_mask = Image.new("L", (sw, sh), 0)
    mask_draw = ImageDraw.Draw(screen_mask)
    mask_draw.rounded_rectangle([0, 0, sw, sh], radius=corner_radius, fill=255)
    
    # Paste screen inside the mockup frame
    mockup.paste(screen_img, (bezel_width, bezel_width), screen_mask)
    return mockup

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
        print(f"❌ Error: {raw_img_path} does not exist. Please make sure simulator screenshots are in the raw folder.")
        return False
        
    # 1. Generate mesh gradient background
    canvas = create_fresh_background(width, height)
    draw = ImageDraw.Draw(canvas)
    
    # 2. Draw text
    text_info = SCREENSHOT_TEXTS.get(index)
    title = text_info["title"]
    subtitle = text_info["subtitle"]
    
    title_font = get_font(title_size, is_bold=True)
    subtitle_font = get_font(subtitle_size, is_bold=False)
    
    # Center title
    title_bbox = draw.textbbox((0, 0), title, font=title_font)
    title_w = title_bbox[2] - title_bbox[0]
    title_x = (width - title_w) // 2
    draw.text((title_x, title_y), title, fill=(15, 23, 42, 255), font=title_font)
    
    # Center subtitle
    subtitle_bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
    subtitle_w = subtitle_bbox[2] - subtitle_bbox[0]
    subtitle_x = (width - subtitle_w) // 2
    draw.text((subtitle_x, subtitle_y), subtitle, fill=(71, 85, 105, 255), font=subtitle_font)
    
    # 3. Compositing iPhone frame
    phone = make_device_mockup(raw_img_path, bezel_width=24, corner_radius=76)
    
    # Scale phone mockup to fit device config
    phone_h = int(phone.height * (phone_w / phone.width))
    phone_resized = phone.resize((phone_w, phone_h), Image.Resampling.LANCZOS)
    
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
    print("🎨 Compositing premium portrait screenshots from raw simulator assets...")
    
    for config in DEVICE_CONFIGS:
        print(f"\n--- Generating for {config['name']} ({config['width']}x{config['height']}) ---")
        success_count = 0
        for i in range(1, 6):
            if process_screenshot(i, config):
                success_count += 1
        print(f"🎉 Successfully completed {success_count}/5 screenshots for {config['name']}.")

if __name__ == "__main__":
    main()
