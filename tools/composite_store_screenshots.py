#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# Setup paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROCESSED_DIR = os.path.join(BASE_DIR, 'screenshots', 'processed')

# Text definition
SCREENSHOT_TEXTS = {
    1: {
        "title": "AIが健康ニュースを\n要約",
        "subtitle": "欲しい情報を瞬時にキャッチ"
    },
    2: {
        "title": "健康ラジオで\n「ながら聴き」",
        "subtitle": "プロの音声読み上げで情報吸収"
    },
    3: {
        "title": "関心ワードで\nパーソナライズ",
        "subtitle": "気になるワードで自動抽出"
    },
    4: {
        "title": "重要な記事を\nブックマーク",
        "subtitle": "いつでもサクッと保存"
    },
    5: {
        "title": "プレミアムで\nすべての制限解除",
        "subtitle": "広告なしの快適なニュース体験へ"
    }
}

# Device configurations for App Store Connect landscape submissions
DEVICE_CONFIGS = [
    {
        "name": "6.7_inch",
        "width": 2796,
        "height": 1290,
        "title_size": 110,
        "subtitle_size": 52,
        "title_x": 180,
        "title_y": 350
    },
    {
        "name": "6.5_inch",
        "width": 2778,
        "height": 1284,
        "title_size": 110,
        "subtitle_size": 52,
        "title_x": 180,
        "title_y": 350
    },
    {
        "name": "5.5_inch",
        "width": 2208,
        "height": 1242,
        "title_size": 80,
        "subtitle_size": 38,
        "title_x": 120,
        "title_y": 350
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

def process_screenshot(index, config):
    input_name = f"store_screenshot_{index}.png"
    input_path = os.path.join(PROCESSED_DIR, input_name)
    
    if not os.path.exists(input_path):
        print(f"❌ Error: {input_path} does not exist. Please make sure the 1024x1024 source image is located there.")
        return False
        
    # Open original 1024x1024 image
    img = Image.open(input_path).convert("RGBA")
    
    canvas_w = config["width"]
    canvas_h = config["height"]
    folder_name = config["name"]
    title_size = config["title_size"]
    subtitle_size = config["subtitle_size"]
    title_x = config["title_x"]
    title_y = config["title_y"]
    
    # 1. Sample gradient colors dynamically from the original image corners
    color_top = img.getpixel((10, 10))
    color_bottom = img.getpixel((1014, 1014))
    
    # Create the landscape canvas
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 255))
    draw = ImageDraw.Draw(canvas)
    
    # Draw horizontal gradient (left to right)
    for x in range(canvas_w):
        ratio = x / (canvas_w - 1)
        r = int(color_top[0] + (color_bottom[0] - color_top[0]) * ratio)
        g = int(color_top[1] + (color_bottom[1] - color_top[1]) * ratio)
        b = int(color_top[2] + (color_bottom[2] - color_top[2]) * ratio)
        draw.line([(x, 0), (x, canvas_h)], fill=(r, g, b, 255))
        
    # Add ambient glow layers to match the premium dark UI style
    glow_layer = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)
    glow_draw.ellipse([-200, -200, 1000, 1000], fill=(16, 185, 129, 35))
    glow_draw.ellipse([canvas_w - 1200, canvas_h - 1200, canvas_w + 200, canvas_h + 200], fill=(52, 211, 153, 25))
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(150))
    canvas = Image.alpha_composite(canvas, glow_layer)
    
    # 2. Crop the phone mockup part (bottom of 1024x1024 image)
    # The text is in the top 300px, so we crop below y=300
    phone_box = (0, 300, 1024, 1024)
    phone_crop = img.crop(phone_box)
    
    # Scale crop to match canvas height
    scaled_h = canvas_h
    scaled_w = int(phone_crop.width * (scaled_h / phone_crop.height))
    phone_resized = phone_crop.resize((scaled_w, scaled_h), Image.Resampling.LANCZOS)
    
    # Paste on the right side of the canvas
    # Using 78% of the scaled width for the phone frame crop
    crop_w = int(scaled_w * 0.78)
    crop_x = scaled_w - crop_w
    phone_final = phone_resized.crop((crop_x, 0, scaled_w, scaled_h))
    
    # Create horizontal gradient mask to blend left edge of phone crop
    mask = Image.new("L", (crop_w, scaled_h), 255)
    mask_draw = ImageDraw.Draw(mask)
    blend_x = int(crop_w * 0.2)
    for x in range(blend_x):
        alpha = int(255 * (x / float(blend_x)))
        mask_draw.line([(x, 0), (x, scaled_h)], fill=alpha)
        
    paste_x = canvas_w - crop_w
    canvas.paste(phone_final, (paste_x, 0), mask)
    
    # 3. Draw text on the left side
    draw = ImageDraw.Draw(canvas)
    text_info = SCREENSHOT_TEXTS.get(index)
    title = text_info["title"]
    subtitle = text_info["subtitle"]
    
    title_font = get_font(title_size, is_bold=True)
    subtitle_font = get_font(subtitle_size, is_bold=False)
    
    # Draw two-line title
    title_lines = title.split("\n")
    line_spacing = 15
    current_y = title_y
    for line in title_lines:
        draw.text((title_x, current_y), line, fill=(255, 255, 255, 255), font=title_font)
        bbox = draw.textbbox((0, 0), line, font=title_font)
        line_h = bbox[3] - bbox[1]
        current_y += line_h + line_spacing
        
    # Draw subtitle below title
    subtitle_y = current_y + 40
    draw.text((title_x, subtitle_y), subtitle, fill=(209, 250, 229, 255), font=subtitle_font)
    
    # 4. Save to device specific folder
    out_dir = os.path.join(PROCESSED_DIR, folder_name)
    os.makedirs(out_dir, exist_ok=True)
    output_path = os.path.join(out_dir, f"store_screenshot_{index}.png")
    
    canvas.save(output_path, "PNG")
    print(f"✅ Generated [{folder_name}] screenshot: {output_path}")
    return True

def main():
    print("🎨 Compositing premium 3D screenshots into App Store Landscape formats...")
    
    for config in DEVICE_CONFIGS:
        print(f"\n--- Generating for {config['name']} ({config['width']}x{config['height']}) ---")
        success_count = 0
        for i in range(1, 6):
            if process_screenshot(i, config):
                success_count += 1
        print(f"🎉 Successfully completed {success_count}/5 screenshots for {config['name']}.")

if __name__ == "__main__":
    main()
