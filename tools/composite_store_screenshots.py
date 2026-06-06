#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# Config
CANVAS_WIDTH = 1290
CANVAS_HEIGHT = 2796

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROCESSED_DIR = os.path.join(BASE_DIR, 'screenshots', 'processed')
DOCS_SS_DIR = os.path.join(BASE_DIR, 'docs', 'screenshots')

# Text definition
SCREENSHOT_TEXTS = {
    1: {
        "title": "AIが健康ニュースを要約",
        "subtitle": "欲しい情報を瞬時にキャッチ"
    },
    2: {
        "title": "健康ラジオで「ながら聴き」",
        "subtitle": "プロの音声読み上げで情報吸収"
    },
    3: {
        "title": "関心ワードでパーソナライズ",
        "subtitle": "「睡眠」「サウナ」など気になるワードで自動抽出"
    },
    4: {
        "title": "重要な記事をブックマーク",
        "subtitle": "気になったニュースはいつでもサクッと保存"
    },
    5: {
        "title": "プレミアムプランで制限解除",
        "subtitle": "広告なしの快適なニュース体験へ"
    }
}

# Web filename mapping
WEB_FILENAMES = {
    1: "1_news_feed.png",
    2: "2_health_radio.png",
    3: "3_keywords.png",
    4: "4_bookmarks.png",
    5: "5_premium.png"
}

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

def process_screenshot(index):
    input_name = f"store_screenshot_{index}.png"
    input_path = os.path.join(PROCESSED_DIR, input_name)
    
    if not os.path.exists(input_path):
        print(f"❌ Error: {input_path} does not exist. Please make sure the 1024x1024 premium screenshot is placed there.")
        return False
        
    # Open original 1024x1024 image
    img = Image.open(input_path).convert("RGBA")
    
    # 1. Sample gradient colors dynamically from the original image corners
    color_top = img.getpixel((10, 10))
    color_bottom = img.getpixel((1014, 1014))
    
    # Create the high-res 1290x2796 canvas
    canvas = Image.new("RGBA", (CANVAS_WIDTH, CANVAS_HEIGHT), (0, 0, 0, 255))
    draw = ImageDraw.Draw(canvas)
    
    # Draw background gradient
    for y in range(CANVAS_HEIGHT):
        ratio = y / (CANVAS_HEIGHT - 1)
        r = int(color_top[0] + (color_bottom[0] - color_top[0]) * ratio)
        g = int(color_top[1] + (color_bottom[1] - color_top[1]) * ratio)
        b = int(color_top[2] + (color_bottom[2] - color_top[2]) * ratio)
        draw.line([(0, y), (CANVAS_WIDTH, y)], fill=(r, g, b, 255))
        
    # Add ambient glow layers to match the premium dark UI style
    glow_layer = Image.new("RGBA", (CANVAS_WIDTH, CANVAS_HEIGHT), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)
    glow_draw.ellipse([-300, -300, 1000, 1000], fill=(16, 185, 129, 35))
    glow_draw.ellipse([CANVAS_WIDTH - 1000, CANVAS_HEIGHT - 1500, CANVAS_WIDTH + 400, CANVAS_HEIGHT + 200], fill=(52, 211, 153, 25))
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(150))
    canvas = Image.alpha_composite(canvas, glow_layer)
    
    # 2. Crop the phone mockup part (bottom of 1024x1024 image)
    # The text is in the top 300px, so we crop below y=300
    phone_box = (0, 300, 1024, 1024)
    phone_crop = img.crop(phone_box)
    
    # Resize the phone crop to width 1600 (scale factor approx 1.56x)
    scaled_w = 1600
    scaled_h = int(phone_crop.height * (scaled_w / phone_crop.width))
    phone_resized = phone_crop.resize((scaled_w, scaled_h), Image.Resampling.LANCZOS)
    
    # Crop horizontally to canvas width (1290) to center the phone
    crop_x = (scaled_w - CANVAS_WIDTH) // 2
    phone_final = phone_resized.crop((crop_x, 0, crop_x + CANVAS_WIDTH, scaled_h))
    
    # 3. Create a vertical gradient transparency mask for the top transition
    # Blends the top 200 pixels of the cropped phone background smoothly into the canvas background
    mask = Image.new("L", (CANVAS_WIDTH, scaled_h), 255)
    mask_draw = ImageDraw.Draw(mask)
    for y in range(200):
        alpha = int(255 * (y / 200.0))
        mask_draw.line([(0, y), (CANVAS_WIDTH, y)], fill=alpha)
        
    # Paste the processed mockup onto the canvas
    paste_y = CANVAS_HEIGHT - scaled_h
    canvas.paste(phone_final, (0, paste_y), mask)
    
    # 4. Draw texts at the top
    draw = ImageDraw.Draw(canvas)
    text_info = SCREENSHOT_TEXTS.get(index)
    title = text_info["title"]
    subtitle = text_info["subtitle"]
    
    title_font = get_font(90, is_bold=True)
    subtitle_font = get_font(46, is_bold=False)
    
    # Calculate title positioning
    title_bbox = draw.textbbox((0, 0), title, font=title_font)
    title_w = title_bbox[2] - title_bbox[0]
    title_x = (CANVAS_WIDTH - title_w) // 2
    title_y = 360
    
    # Calculate subtitle positioning
    subtitle_bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
    subtitle_w = subtitle_bbox[2] - subtitle_bbox[0]
    subtitle_x = (CANVAS_WIDTH - subtitle_w) // 2
    subtitle_y = 500
    
    # Draw texts
    draw.text((title_x, title_y), title, fill=(255, 255, 255, 255), font=title_font)
    draw.text((subtitle_x, subtitle_y), subtitle, fill=(209, 250, 229, 255), font=subtitle_font)
    
    # Save processed image (overwrite existing store_screenshot_X.png)
    canvas.save(input_path, "PNG")
    print(f"✅ Generated App Store screenshot: {input_path}")
    
    # Copy to web site screenshots folder
    os.makedirs(DOCS_SS_DIR, exist_ok=True)
    web_filename = WEB_FILENAMES.get(index)
    web_path = os.path.join(DOCS_SS_DIR, web_filename)
    canvas.save(web_path, "PNG")
    print(f"➡️  Web site copy generated: {web_path}")
    return True

def main():
    print("🎨 Compositing premium 3D screenshots into 1290x2796px format...")
    
    success_count = 0
    for i in range(1, 6):
        print(f"Processing screenshot {i}/5...")
        if process_screenshot(i):
            success_count += 1
            
    print(f"\n🎉 Finished processing! Successfully completed {success_count}/5 screenshots.")

if __name__ == "__main__":
    main()
